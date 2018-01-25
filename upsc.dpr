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
  PsUtils in '..\lib\PsUtils.pas',
  MessageDialog in 'MessageDialog.pas' {InfoMsgDlg};

{$R *.res}

begin
  StartLogging('');
  ShowConsole();
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TInfoMsgDlg, InfoMsgDlg);
  Application.Run;
end.
