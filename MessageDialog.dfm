object InfoMsgDlg: TInfoMsgDlg
  Left = 227
  Top = 108
  BorderStyle = bsDialog
  Caption = 'UPS Control Notify'
  ClientHeight = 119
  ClientWidth = 384
  Color = clBtnFace
  ParentFont = True
  FormStyle = fsStayOnTop
  OldCreateOrder = True
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object lbInfo: TLabel
    Left = 16
    Top = 8
    Width = 77
    Height = 13
    Caption = 'Message text...'
  end
  object lbCountback: TLabel
    Left = 16
    Top = 40
    Width = 135
    Height = 13
    Caption = 'Notify closed after 30 sec...'
  end
  object OKBtn: TButton
    Left = 140
    Top = 88
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object tmrCountback: TTimer
    OnTimer = tmrCountbackTimer
    Left = 248
    Top = 80
  end
end
