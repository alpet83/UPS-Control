unit MessageDialog;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Forms,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls;

type
  TInfoMsgDlg = class(TForm)
    OKBtn: TButton;
    lbInfo: TLabel;
    lbCountback: TLabel;
    tmrCountback: TTimer;
    procedure tmrCountbackTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    ticks: Integer;
  public
    { Public declarations }
  end;

var
  InfoMsgDlg: TInfoMsgDlg;

implementation

{$R *.dfm}

procedure TInfoMsgDlg.FormShow(Sender: TObject);
begin
 ticks := 30;
 tmrCountback.Enabled := TRUE;
end;

procedure TInfoMsgDlg.tmrCountbackTimer(Sender: TObject);
begin
 Dec (ticks);
 if (ticks <= 0) then
   begin
    tmrCountback.Enabled := FALSE;
    ModalResult := mrCancel;
   end;
 lbCountback.Caption := Format('Notify closed after %d sec...', [ticks]);
end;

end.
