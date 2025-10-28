unit optionsform;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, EditBtn,
  LCLType, ExtCtrls, Buttons;

type

  TScanOptions = record
    ScanApp: String;
    LidarPort: String;
    ServoPort: String;
    RangeStart, RangeEnd, RangeStep, Rotations: Double;
    DatFile: String;
    JSONFile: String;
  end;

  { TOptionsDialog }

  TOptionsDialog = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    BottomPanel: TPanel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    ServoCOMFileEdit: TFileNameEdit;
    RangeStartEdit: TEdit;
    EnableJSONCheckbox: TCheckBox;
    JSONFilenameEdit: TFileNameEdit;
    DatFileEdit: TFileNameEdit;
    Label3: TLabel;
    Label4: TLabel;
    RangeEndEdit: TEdit;
    RotationsEdit: TEdit;
    RangeStepEdit: TEdit;
    ScanappFileEdit: TFileNameEdit;
    Label1: TLabel;
    Label2: TLabel;
    LidarCOMFileEdit: TFileNameEdit;
    ScanOptionsBox: TGroupBox;
    procedure EnableJSONCheckboxChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure LoadOptionsBoxResize(Sender: TObject);
    procedure RangeStartEditChange(Sender: TObject);
  private
    FScanOptions: TScanOptions;

  public
    function DefaultScanOptions: TScanOptions;

    procedure UpdateSettings;

    property ScanOptions: TScanOptions read FScanOptions;
  end;

var
  OptionsDialog: TOptionsDialog;

implementation

{$R *.lfm}

{ TOptionsDialog }

procedure TOptionsDialog.LoadOptionsBoxResize(Sender: TObject);
begin
  ScanOptionsBox.Width:=ClientWidth div 2;
end;

procedure TOptionsDialog.RangeStartEditChange(Sender: TObject);
var
  dummy: Double;
begin
  if not TryStrToFloat(TEdit(Sender).Text, dummy) then
    TEdit(Sender).Color:=clRed
  else
    TEdit(Sender).Color:=clDefault;
end;

function TOptionsDialog.DefaultScanOptions: TScanOptions;
begin
  Result := Default(TScanOptions);
  Result.ScanApp:='scanapp';
  Result.LidarPort:='/dev/ttyUSB0';
  Result.ServoPort:='/dev/ttyUSB1';
  Result.RangeStart:=0;
  Result.RangeEnd:=180;
  Result.RangeStep:=1;
  Result.Rotations:=1;
  Result.DatFile:='LidarScan.dat';
  Result.JSONFile:='';
end;

procedure TOptionsDialog.UpdateSettings;
var
  range: Array[0..1] of Double;
begin
  ScanappFileEdit.FileName:=FScanOptions.ScanApp;
  LidarCOMFileEdit.FileName:=FScanOptions.LidarPort;
  ServoCOMFileEdit.FileName:=FScanOptions.ServoPort;
  RangeStartEdit.Text:=FScanOptions.RangeStart.ToString;
  RangeEndEdit.Text:=FScanOptions.RangeEnd.ToString;
  RangeStepEdit.Text:=FScanOptions.RangeStep.ToString;
  RotationsEdit.Text:=FScanOptions.Rotations.ToString;
  DatFileEdit.FileName:=FScanOptions.DatFile;
  EnableJSONCheckbox.Checked:=not FScanOptions.JSONFile.IsEmpty;
  if EnableJSONCheckbox.Checked then
    JSONFilenameEdit.FileName:=FScanOptions.JSONFile
  else
    JSONFilenameEdit.FileName:='LidarScan.json';
end;

procedure TOptionsDialog.EnableJSONCheckboxChange(Sender: TObject);
begin
  JSONFilenameEdit.Enabled:=EnableJSONCheckbox.Checked;
end;

procedure TOptionsDialog.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  RStart, REnd, RStep,
  Rotations: Double;
  parts: TStringArray;
  i: Integer;
begin
  CanClose:=True;
  if ModalResult=mrCancel then
    Exit;

  if not TryStrToFloat(RangeStartEdit.Text, RStart) or
     not TryStrToFloat(RangeEndEdit.Text, REnd) or
     not TryStrToFloat(RangeStepEdit.Text, RStep) or
     (RStart<0) or (REnd>180) or (RStep<0) or (REnd<RStart) then
  begin
    MessageDlg('Invalid Scanrange', 'The scanrange must be between 0..180 in positive steps', mtWarning, [mbOK], 'Rangeerror');
    CanClose:=False;
  end;

  if not TryStrToFloat(RotationsEdit.Text, Rotations) or
     (Rotations < 0) then
  begin
    MessageDlg('Invalid Rotations', 'The rotation count must be a positive number', mtWarning, [mbOK], 'Rotationserror');
    CanClose:=False;
  end;

  if not CanClose then
    Exit;

  FScanOptions:=DefaultScanOptions;
  FScanOptions.ScanApp:=ScanappFileEdit.FileName;
  FScanOptions.LidarPort:=LidarCOMFileEdit.FileName;
  FScanOptions.ServoPort:=ServoCOMFileEdit.FileName;
  FScanOptions.RangeStart:=RStart;
  FScanOptions.RangeEnd:=REnd;
  FScanOptions.RangeStep:=RStep;
  FScanOptions.Rotations:=Rotations;
  FScanOptions.DatFile:=DatFileEdit.FileName;
  if EnableJSONCheckbox.Checked then
    FScanOptions.JSONFile:=JSONFilenameEdit.FileName;
end;

procedure TOptionsDialog.FormCreate(Sender: TObject);
begin
  FScanOptions:=DefaultScanOptions;
end;

procedure TOptionsDialog.FormShow(Sender: TObject);
begin
  UpdateSettings;
end;

end.

