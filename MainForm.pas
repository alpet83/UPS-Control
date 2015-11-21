unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, IniFiles, Vcl.Graphics, Math,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Misc, StrClasses, Lua5, LuaTypes, LuaTools, LuaEngine, Vcl.StdCtrls, Vcl.Samples.Spin, CPort,
  Vcl.ExtCtrls, SyncObjs, VCLTee.TeEngine, VCLTee.Series, VCLTee.TeeProcs, VCLTee.Chart, VclTee.TeeGDIPlus, StrUtils, ShellApi;

type
  TfrmMain = class(TForm)
    spePortNumber: TSpinEdit;
    Label1: TLabel;
    btnOpenPort: TButton;

    updTimer: TTimer;
    StatChart: TChart;
    Series1: TLineSeries;
    Series2: TLineSeries;
    Series3: TLineSeries;
    btnSendCommand: TButton;
    Series4: TLineSeries;
    cpMain: TComPort;
    cbxCommand: TComboBox;
    procedure btnOpenPortClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSendCommandClick(Sender: TObject);
    procedure updTimerTimer(Sender: TObject);
  private
    { Private declarations }

      rxbuff: String;
      txbuff: TStrMap;
         lqs: Integer;
         evt: TEvent;
          le: TLuaEngine;
    vst_file: String;
   vst_cache: TStrMap;
   last_dump: WORD;
    volt_max: Double;
   batt_vmin: Single;
   batt_vmax: Single;




    procedure TX(const s: String);
    procedure ProcessRX;
    procedure QueryStatus;
    procedure ClearStat;
    procedure LoadConfig;
    procedure TestEvents;
    procedure AddVoltageStats(v: Double);
  public
    { Public declarations }
    procedure ProcessValue (var vn: String; pt, vv: Double);
    procedure UPS_StatusChanged (const status: String; warn_lvl: Integer);
  end;

var
  frmMain: TfrmMain;


implementation
uses DateTimeTools;

resourcestring
     script_name = 'upsc.lua';

var
   gpt: TProfileTimer;

{$R *.dfm}

function tx_str (L: lua_State): Integer; cdecl;
var
   s: String;
begin
 result := 1;
 s := LuaStrArg (L);
 frmMain.txbuff.Add (s);
 lua_pushinteger ( L, frmMain.txbuff.Count );

end;

function local_time (L: lua_State): Integer; cdecl;
begin
  result := 2;
  lua_pushnumber (L, Trunc(Now) );
  lua_pushnumber (L, Frac(Now) );
end;

function format_time (L: lua_State): Integer; cdecl;
var
   s, fmt: String;
begin
 fmt := LuaStrArg (L, 1);
 s := FormatDateTime (fmt, lua_tonumber(L, 2));
 lua_pushwstr (L, s);
 result := 1;
end;

function handle_value (L: lua_State): Integer; cdecl;
var
   vn: String;
   vv: Double;
   pt: Double;


begin
 result := 0;
 vn := LuaStrArg (L);
 pt := lua_tonumber (L, 2);
 vv := lua_tonumber (L, 3);
 frmMain.ProcessValue (vn, pt, vv);
end;


function shell_exec (L: lua_State): Integer; cdecl;

    function PChar(const s: String): PWideChar; inline;
    begin
     if s = '' then
        result := nil
     else
        result := PWideChar(s);
    end;

var
   params: String;
    fname: String;
      cmd: String;
      dir: String;
       sc: Integer;


begin
 cmd    := LuaStrArg (L);
 fname  := LuaStrArg (L, 2);
 params := LuaStrArg (L, 3);
 dir    := LuaStrArg (L, 4, ExePath);
 sc := SW_SHOWNORMAL;
 if lua_gettop(L) > 4 then sc := lua_tointeger (L, 5);

 sc := ShellExecute ( frmMain.Handle, PChar(cmd), PChar(fname), PChar(params), PChar(dir), sc );

 result := 1;
 lua_pushinteger (L, sc);

 // ;
end;


function lua_fputs (L: lua_State): Integer; cdecl;
var
     ftxt: Text;
    fname: String;
      msg: String;
      err: Integer;
begin
 fname := LuaStrArg (L);
 fname := CorrectFilePath (fname);
 CheckMakeDir ( ExtractFilePath (fname) );

 AssignFile(ftxt, fname);
 try

   {$I-}

   if FileExists(fname) then
      Append (ftxt)
   else
      Rewrite (ftxt);

   result := 2;

   err := IOResult;
   if err <> 0 then
    begin
     lua_pushboolean (L, false);
     lua_pushinteger (L, err);
    end;

   msg := LuaStrArg (L, 2);

   Write (ftxt, msg);
   lua_pushboolean (L, true);
   lua_pushinteger (L, Length(msg));
   CloseFile (ftxt);
 except
  on E: Exception do
    OnExceptLog ('lua_fputs', E, TRUE);
 end;
end;

function start_timer(L: lua_State): Integer; cdecl;
begin
 gpt.StartOne( lua_tointeger(L, 1) );
 result := 0;
end;

function elapsed_time(L: lua_State): Integer; cdecl;
var
   e: Double;
begin
 e := gpt.Elapsed( lua_tointeger(L, 1) );
 lua_pushnumber (L, e);
 result := 1;
end;


function status_changed (L: lua_State): Integer; cdecl;
var
   s: String;
begin
 s := LuaStrArg (L);
 frmMain.UPS_StatusChanged (s, lua_tointeger (L, 2) );
 result := 0;
end;

procedure TfrmMain.TX(const s: String);
begin
 txbuff.Add (s);
end;


var
   entire: Boolean = FALSE;

procedure TfrmMain.updTimerTimer(Sender: TObject);
begin
 if entire then exit;
 entire := TRUE;
 try
  TestEvents;
 finally
  entire := FALSE;
 end;


end;

procedure TfrmMain.TestEvents;
var
   evts: TComEvents;
     cb: Integer;
     st: TSystemTime;

begin
 if cpMain.Connected then
  begin
   btnOpenPort.Enabled := FALSE;

   if txbuff.Count > 0 then
      begin
       cpMain.WriteStr( txbuff [0] + #13 ); // TODO: crlf in config
       ODS('[~T].~C0B #TX:~C0A ' + txbuff[0] + '~C07');
       txbuff.Delete(0);
      end;


   evts := [evRxChar];
   try
    cpMain.WaitForEvent (evts, evt.Handle, 500);  // wait for charachters
   except
    on E: Exception do
       wprintf('[~T].~C0C #EXCEPT:~C07 WaitForEvent failed with error %s ', [E.Message]);
   end;
   // if evRxChar in evts then
     begin
      cb := cpMain.InputCount;
      if cb > 0 then
         ProcessRX;
     end;

   GetLocalTime (st);

   if st.wSecond <> lqs then
     begin
      QueryStatus;
      lqs := st.wSecond;
     end;

  end
 else
  begin
   btnOpenPort.Enabled := TRUE;
   btnSendCommand.Enabled := FALSE;
  end;


 if Series1.ValuesList.Count = 300 then
    StatChart.BottomAxis.DateTimeFormat := 'hh:nn:ss';

 if Series1.ValuesList.Count = 3600 then
    StatChart.BottomAxis.DateTimeFormat := 'hh:nn';

end;

procedure TfrmMain.UPS_StatusChanged (const status: String; warn_lvl: Integer);
begin
 // if status = 'IM' then exit;
 if warn_lvl >= 5 then
   begin
    FormStyle := fsStayOnTop;
    Activate;
    BringToFront;
    ShowWindow (Handle, SW_SHOW);
    Application.ProcessMessages;
    ShowMessage('UPS status changed to ' + status);
    FormStyle := fsNormal;
   end
 else
   wprintf('[~T]. #DBG: UPS status changed to %s ', [status] );

end;

procedure TfrmMain.btnOpenPortClick(Sender: TObject);
begin
 cpMain.Port := 'COM' + IntToStr ( spePortNumber.Value );
 cpMain.Events := [];

 if not cpMain.Connected then
   try
    cpMain.Open;

    ClearStat;

   except
    on E: EComPort do
       PrintError ('Exception catched : ' + E.Message + '. LastError: ' + err2str);
   end;

 if cpMain.Connected then
    begin
     ODS('[~T]. #DBG: Connected');
     QueryStatus;
     btnOpenPort.Enabled := FALSE;
     btnSendCommand.Enabled := TRUE;

     lua_pushnumber (le.State, batt_vmin);
     lua_setglobal  (le.State, 'BATT_VOLTAGE_MIN');
     lua_pushnumber (le.State, batt_vmax);
     lua_setglobal  (le.State, 'BATT_VOLTAGE_MAX');

     le.CallFunc('init');
    end;
end;

procedure TfrmMain.btnSendCommandClick(Sender: TObject);
var
   s: String;
   p: Integer;
begin
 s := cbxCommand.Text;
 p := Pos(' - ', s);
 if p > 1 then
    SetLength (s, p - 1);

 txbuff.Add ( Trim(s) )
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
   pp: TProgramParams;
    s: String;
begin
 evt := TEvent.Create ( nil, TRUE, FALSE, '' );
 le := TLuaEngine.Create;
 txbuff := TStrMap.Create(self);
 vst_cache := TStrmap.Create(self);



 if FileExists(script_name) and le.LoadScript(script_name) then
   begin

    le.RegFunc('handle_value',   @handle_value);
    le.RegFunc('format_time',    @format_time);
    le.RegFunc('local_time',     @local_time);
    le.RegFunc('tx_str',         @tx_str);
    le.RegFunc('shell_exec',     @shell_exec);
    le.RegFunc('status_changed', @status_changed);
    le.RegFunc('fputs',          @lua_fputs);
    le.RegFunc('start_timer',    @start_timer);
    le.RegFunc('elapsed_time',   @elapsed_time);
    le.Execute;
   end
 else
    Assert(FALSE, 'Cannot load ' + script_name);

 LoadConfig();

 StatChart.BottomAxis.DateTimeFormat := 'hh:nn:ss.zzz';



 pp := TProgramParams.Create;
 s := pp['port_number'];
 if s <> '' then
    spePortNumber.Value := atoi (s);
 s := pp['auto_start'];
 if s = '1' then
    self.btnOpenPortClick(self);


 pp.Free;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
 cpMain.Close;
 FreeAndNil (evt);
 FreeAndNil (txbuff);
 FreeAndNil (vst_cache);
 le.Free;
end;

procedure TfrmMain.LoadConfig;
const
   BR_BODS: array [0..13] of Integer = (   300,     600,      1200,     2400,   4800,
                                           9600,    14400,    19200,    38400,  56000,
                                           57600,   115200,   128000,   256000 );

   BR_VALS: array [0..13] of TBaudRate = ( br300,   br600,    br1200,   br2400,  br4800,
                                           br9600,  br14400,  br19200,  br38400, br56000,
                                           br57600, br115200, br128000, br256000 );


var
   fini: TIniFile;
   fcfg: String;
      s: String;
      v: Integer;
      n: Integer;


begin
 fcfg := FindConfigFile ('upsc.conf');
 if ( fcfg = '' ) or ( not FileExists (fcfg) ) then exit;

 fini := TIniFile.Create(fcfg);
 try
  vst_file := fini.ReadString('config', 'voltage_stats_file', '');

  batt_vmin := fini.ReadFloat( 'config', 'batt_voltage_min', 84.0);
  batt_vmax := fini.ReadFloat( 'config', 'batt_voltage_max', 110.0);


  v := fini.ReadInteger ( 'config', 'baud_rate', 0 );

  // unmap value
  if v > 0 then
     for n := 0 to High (BR_BODS) do
         if v = BR_BODS[n] then
            cpMain.BaudRate := BR_VALS[n];

  v := fini.ReadInteger ( 'config' ,'port_number', 0 );
  if v > 0 then
     spePortNumber.Value := v;


  if fini.ReadBool ( 'config', 'auto_start', FALSE ) then
     btnOpenPortClick(self);

  v := fini.ReadInteger( 'config', 'DTR', -1 );
  if v >= 0 then
     cpMain.SetDTR( v > 0 );

  v := fini.ReadInteger( 'config', 'RTS', -1 );
  if v >= 0 then
     cpMain.SetRTS( v > 0 );

  v := fini.ReadInteger( 'config', 'XonXoff', -1 );
  if v >= 0 then
     cpMain.SetXonXoff( v > 0 );

  v := fini.ReadInteger( 'config', 'break', -1 );
  if v >= 0 then
     cpMain.SetBreak ( v > 0 );



  v := fini.ReadInteger( 'config', 'flow_ctrl_dtr', -1);
  if v > 0 then
     cpMain.FlowControl.ControlDTR := TDTRFlowControl (v);

  v := fini.ReadInteger( 'config', 'flow_ctrl_rts', -1);
  if v > 0 then
     cpMain.FlowControl.ControlRTS := TRTSFlowControl (v);


  v := fini.ReadInteger( 'config', 'event_char', -1 );
  if v >= 0 then
     cpMain.EventChar := Char (v);

  v := fini.ReadInteger( 'config', 'parity_bits', -1 );
  if v >= 0 then
     cpMain.Parity.Bits := TParityBits (v);


  v := fini.ReadInteger( 'config', 'data_bits', 0 );
  case v of
    5: cpMain.DataBits := dbFive;
    6: cpMain.DataBits := dbSix;
    7: cpMain.DataBits := dbSeven;
    8: cpMain.DataBits := dbEight;
  end;

  v := fini.ReadInteger( 'config', 'stop_bits', 0 );
  case v of
    1: cpMain.StopBits := sbOneStopBit;
    2: cpMain.StopBits := sbTwoStopBits;
    5: cpMain.StopBits := sbOne5StopBits;
  end;


  v := fini.ReadInteger( 'config', 'input_buffer', 0 );
  if v > 0 then cpMain.Buffer.InputSize := v;
  v := fini.ReadInteger( 'config', 'output_buffer', 0 );
  if v > 0 then cpMain.Buffer.OutputSize := v;

  // default config for 96v battery

  fini.Free;
 finally;
 end;
end;

procedure TfrmMain.ProcessRX;
var
   s: String;
   i: Integer;
begin
 cpMain.ReadStr(s, cpMain.InputCount);
 cpMain.ClearBuffer(TRUE, TRUE);

 rxbuff := rxbuff + s;
 repeat
  i := Pos(#13, rxbuff);
  if i = 0 then break;
  s := Copy (rxbuff, 1, i - 1);
  Delete (rxbuff, 1, i);
  //  ODS ('[~T]. #RX:~C0E ' + Trim(s) + '  ~C07 .');
  le.VarSet('last_rx', s);
  le.CallFuncEx ('parse_rx', 'last_rx', '');
 until FALSE;
end;

procedure TfrmMain.AddVoltageStats (v: Double);
var
   err: Integer;
    fd: TextFile;
    fn: String;
begin
 //
 if vst_file = '' then exit;
 vst_cache.Add(FormatDateTime('hh:nn:ss,', Now) + Format('%.3f', [v]));
 {$I-}
 if not DirectoryExists(ExtractFilePath(vst_file)) then exit;

 fn := AnsiReplaceStr (vst_file, '$date', FormatDateTime ('yymmdd', Now));
 AssignFile (fd, fn);
 if FileExists (fn) then
    Append (fd)
 else
    ReWrite (fd);
 err := IOResult;
 if err <> 0 then
   begin
    wprintf ('[~T].~COC #ERROR:~C07 cannot open file %s, error code = %d ', [vst_file, err]);
    exit;
   end;
 Write (fd,  vst_cache.Text);
 if vst_cache.Count > 1 then
    wprintf('[~T]. #DBG: from vst_cache stored %d lines', [vst_cache.Count]);
 vst_cache.Clear;
 Flush (fd);
 CloseFile (fd);
end;

procedure TfrmMain.ProcessValue(var vn: String; pt, vv: Double);
var
   ls: TLineSeries;
    i: Integer;
   st: TSystemTime;

begin
 with StatChart do
   for i := 0 to SeriesList.Count - 1 do
    begin
     ls := TLineSeries ( SeriesList [i] );
     if ls.Title <> vn then continue;
     ls.XValues.DateTime := TRUE;
     ls.AddXY(pt, vv);
    end; // for

 if vn = 'Voltage_In' then
  begin
   GetLocalTime (st);
   volt_max := Max (volt_max, vv);

   if st.wMinute = last_dump then exit;
   last_dump := st.wMinute;
   AddVoltageStats (volt_max);
   volt_max := 0;
  end;

end;

procedure TfrmMain.ClearStat;
var
   ls: TLineSeries;
    i: Integer;

begin
 with StatChart do
   for i := 0 to SeriesList.Count - 1 do
    begin
     ls := TLineSeries ( SeriesList [i] );
     ls.Clear;
    end;
end;


procedure TfrmMain.QueryStatus;
begin
 le.CallFunc('query_status');
end;


initialization
 gpt := TProfileTimer.Create;
finalization
 gpt.Free;
end.
