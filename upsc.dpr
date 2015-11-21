program upsc;
{$APPTYPE CONSOLE}
uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  Vcl.Forms,
  Misc,
  MainForm in 'MainForm.pas' {frmMain},
  PsUtils in '..\lib\PsUtils.pas';

{$R *.res}

begin
  StartLogging('');
  ShowConsole();
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
