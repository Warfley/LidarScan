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

  TFilterRanges = Array of Array[0..1] of Double;

  TRenderingOptions = record
    FilterRanges: TFilterRanges;
    Normalize: Boolean;
    NormalizationRadius: Double;
    BackgroundColor: TColor;
    PointColor: TColor;
    AlphaQuality: Boolean;
  end;

  { TOptionsDialog }

  TOptionsDialog = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    NormalizeCheckbox: TCheckBox;
    DeleteFilterButton: TButton;
    BottomPanel: TPanel;
    AlphaCheckbox: TCheckBox;
    BackgroundColorButton: TColorButton;
    PointColorButton: TColorButton;
    AddFilterButton: TButton;
    GroupBox1: TGroupBox;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    FilterListbox: TListBox;
    FilterRangeEndEdit: TEdit;
    FilterRangeStartEdit: TEdit;
    NormalizationEdit: TEdit;
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
    LoadOptionsBox: TGroupBox;
    procedure AddFilterButtonClick(Sender: TObject);
    procedure DeleteFilterButtonClick(Sender: TObject);
    procedure EnableJSONCheckboxChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure LoadOptionsBoxResize(Sender: TObject);
    procedure NormalizeCheckboxChange(Sender: TObject);
    procedure RangeStartEditChange(Sender: TObject);
  private
    FScanOptions: TScanOptions;
    FRenderingOptions: TRenderingOptions;

  public
    function DefaultScanOptions: TScanOptions;
    function DefaultRenderingOptions: TRenderingOptions;

    procedure UpdateSettings;

    property ScanOptions: TScanOptions read FScanOptions;
    property RenderingOptions: TRenderingOptions read FRenderingOptions;
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

procedure TOptionsDialog.NormalizeCheckboxChange(Sender: TObject);
begin
  NormalizationEdit.Enabled:=NormalizeCheckbox.Checked;
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

function TOptionsDialog.DefaultRenderingOptions: TRenderingOptions;
begin
  Result:=Default(TRenderingOptions);
  Result.BackgroundColor:=$FFAAAA;
  Result.PointColor:=clWhite;
  Result.AlphaQuality:=True;
  Result.NormalizationRadius:=16;
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

  FilterListbox.Clear;
  for range in FRenderingOptions.FilterRanges do
    FilterListbox.Items.Add('%s..%s',[range[0].ToString,range[1].ToString]);
  NormalizeCheckbox.Checked:=FRenderingOptions.Normalize;
  if FRenderingOptions.Normalize then
    NormalizationEdit.Text:=FRenderingOptions.NormalizationRadius.ToString
  else
    NormalizationEdit.Text:='16';
  AlphaCheckbox.Checked:=FRenderingOptions.AlphaQuality;
  PointColorButton.ButtonColor:=FRenderingOptions.PointColor;
  BackgroundColorButton.ButtonColor:=FRenderingOptions.BackgroundColor;
end;

procedure TOptionsDialog.EnableJSONCheckboxChange(Sender: TObject);
begin
  JSONFilenameEdit.Enabled:=EnableJSONCheckbox.Checked;
end;

procedure TOptionsDialog.AddFilterButtonClick(Sender: TObject);
var
  Start, Stop: Double;
begin
  if not TryStrToFloat(FilterRangeStartEdit.Text, Start) or
     not TryStrToFloat(FilterRangeEndEdit.Text, Stop) or
     (Start<0) or (Start>360) or (Stop<0) or (Stop>360) then
    MessageDlg('Invalid angle Ranges', 'The ranges entered must be floating point numbers in the range of 0..360',mtWarning,[mbOK],'RangeError')
  else
    FilterListbox.Items.Add('%s..%s', [FilterRangeStartEdit.Text,FilterRangeEndEdit.Text]);
end;

procedure TOptionsDialog.DeleteFilterButtonClick(Sender: TObject);
begin
  FilterListbox.DeleteSelected;
end;

procedure TOptionsDialog.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  RStart, REnd, RStep, Rotations, NormalizationRadius: Double;
  ranges: TFilterRanges;
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

  if NormalizeCheckbox.Checked and (
       not TryStrToFloat(NormalizationEdit.Text, NormalizationRadius) or
       (NormalizationRadius < 0)
     ) then
  begin
    MessageDlg('Invalid Normalization', 'The normalization radius must be a positive number', mtWarning, [mbOK], 'Normalizationserror');
    CanClose:=False;
  end; 

  ranges:=[];
  SetLength(ranges, FilterListbox.Items.Count);
  for i:=0 to FilterListbox.Items.Count-1 do
  begin
    parts := FilterListbox.Items[i].Split(['..']);
    if (Length(parts)<>2) or
       not TryStrToFloat(parts[0],ranges[i,0]) or
       not TryStrToFloat(parts[1],ranges[i,1]) or
       (ranges[i,0]<0) or (ranges[i,0]>360) or (ranges[i,1]<0) or (ranges[i,1]>360)then
    begin
      MessageDlg('Invalid angle Ranges', 'The ranges entered must be floating point numbers in the range of 0..360',mtWarning,[mbOK],'RangeError');
      CanClose:=False;
      Break;
    end;
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

  FRenderingOptions:=DefaultRenderingOptions;
  FRenderingOptions.FilterRanges:=ranges;
  FRenderingOptions.Normalize:=NormalizeCheckbox.Checked;
  if FRenderingOptions.Normalize then
    FRenderingOptions.NormalizationRadius:=NormalizationRadius;
  FRenderingOptions.AlphaQuality:=AlphaCheckbox.Checked;
  FRenderingOptions.PointColor:=PointColorButton.ButtonColor;
  FRenderingOptions.BackgroundColor:=BackgroundColorButton.ButtonColor;
end;

procedure TOptionsDialog.FormCreate(Sender: TObject);
begin
  FRenderingOptions:=DefaultRenderingOptions;
  FScanOptions:=DefaultScanOptions;
end;

procedure TOptionsDialog.FormShow(Sender: TObject);
begin
  UpdateSettings;
end;

end.

