object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'UPS Control'
  ClientHeight = 473
  ClientWidth = 860
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    860
    473)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 11
    Width = 50
    Height = 13
    Caption = 'COM port:'
  end
  object spePortNumber: TSpinEdit
    Left = 80
    Top = 8
    Width = 57
    Height = 22
    MaxValue = 99
    MinValue = 1
    TabOrder = 0
    Value = 1
  end
  object btnOpenPort: TButton
    Left = 152
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Start '
    TabOrder = 1
    OnClick = btnOpenPortClick
  end
  object StatChart: TChart
    Left = 8
    Top = 104
    Width = 844
    Height = 361
    Title.Text.Strings = (
      'UPS condition')
    BottomAxis.LabelsAngle = 45
    LeftAxis.MaximumOffset = 10
    LeftAxis.MinimumOffset = 5
    RightAxis.MaximumOffset = 5
    RightAxis.MinimumOffset = -5
    View3D = False
    TabOrder = 2
    Anchors = [akLeft, akTop, akRight, akBottom]
    DefaultCanvas = 'TGDIPlusCanvas'
    ColorPaletteIndex = 13
    object Series1: TLineSeries
      Title = 'Voltage_In'
      Brush.BackColor = clDefault
      Pointer.InflateMargins = True
      Pointer.Style = psRectangle
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
      Data = {00010000000000000000C06C40}
    end
    object Series2: TLineSeries
      Title = 'Temperature'
      Brush.BackColor = clDefault
      Pointer.InflateMargins = True
      Pointer.Style = psRectangle
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
      Data = {00010000000000000000004940}
    end
    object Series3: TLineSeries
      Title = 'Charge_Level'
      Brush.BackColor = clDefault
      Pointer.InflateMargins = True
      Pointer.Style = psRectangle
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
      Data = {00010000000000000000005940}
    end
    object Series4: TLineSeries
      Title = 'Load_Level'
      Brush.BackColor = clDefault
      Pointer.Brush.Gradient.EndColor = 11048782
      Pointer.Gradient.EndColor = 11048782
      Pointer.InflateMargins = True
      Pointer.Style = psRectangle
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
      Data = {00010000000000000000002E40}
    end
  end
  object btnSendCommand: TButton
    Left = 152
    Top = 37
    Width = 75
    Height = 25
    Caption = 'Send'
    TabOrder = 3
    OnClick = btnSendCommandClick
  end
  object cbxCommand: TComboBox
    Left = 8
    Top = 39
    Width = 138
    Height = 21
    TabOrder = 4
    Text = 'Q'
    Items.Strings = (
      'T  - test for 5 seconds'
      'T5 - test battery for 5 minutes'
      'TL - test until battery low'
      'CT - cancel test'
      'Q  - toggle beeper'
      'F  - UPS rating information'
      'S5 - shutdown after 5 minutes'
      'S5R0007 - shutdown after 5 minutes, when turn on after 7 minutes'
      'C - cancel shutdown')
  end
  object updTimer: TTimer
    Interval = 100
    OnTimer = updTimerTimer
    Left = 264
    Top = 56
  end
  object cpMain: TComPort
    BaudRate = br2400
    Port = 'COM2'
    Parity.Bits = prNone
    StopBits = sbOneStopBit
    DataBits = dbEight
    Events = [evRxChar, evTxEmpty, evRxFlag, evRing, evBreak, evCTS, evDSR, evError, evRLSD, evRx80Full]
    FlowControl.OutCTSFlow = False
    FlowControl.OutDSRFlow = False
    FlowControl.ControlDTR = dtrDisable
    FlowControl.ControlRTS = rtsDisable
    FlowControl.XonXoffOut = False
    FlowControl.XonXoffIn = False
    StoredProps = [spBasic]
    TriggersOnRxChar = True
    SyncMethod = smNone
    Left = 464
    Top = 32
  end
end
