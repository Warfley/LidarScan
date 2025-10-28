unit RenderingForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Buttons, process, openglcontext, gl, Math, Types, optionsform;

type
  TPointRecord = packed record
    Yaw, Pitch, Distance: Double;
    Quality: Byte;
  end;

  TPointRecordArray = Array of TPointRecord;

  TScanData = record
    Start, Stop, Step,
    Rotations: Double;
    PointsPerScan: LongWord;
    Points: TPointRecordArray;
  end;

  { TRendererForm }

  TRendererForm = class(TForm)
    BitBtn1: TBitBtn;
    NormalizeCheckbox: TCheckBox;
    BackgroundColorButton: TColorButton;
    MaxDistanceLabel: TLabel;
    MaxPitchLabel: TLabel;
    MaxPitchTrackbar: TTrackBar;
    MinPitchLabel: TLabel;
    MinDistanceTrackbar: TTrackBar;
    MinDistanceLabel: TLabel;
    MaxDistanceTrackbar: TTrackBar;
    MinPitchTrackbar: TTrackBar;
    Panel3: TPanel;
    Panel4: TPanel;
    PointColorButton: TColorButton;
    MinAngelLabel: TLabel;
    MaxAngelLabel: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    LoadButton: TButton;
    Panel2: TPanel;
    ProgressBar1: TProgressBar;
    SaveDialog1: TSaveDialog;
    ScanButton: TButton;
    OptionsButton: TButton;
    OpenDatFileDialog: TOpenDialog;
    RotationsEdit: TEdit;
    RangeStepEdit: TEdit;
    RangeEndEdit: TEdit;
    RangeStartEdit: TEdit;
    PPSEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Renderer: TOpenGLControl;
    Panel1: TPanel;
    ScanTimer: TTimer;
    MinAngelTrackbar: TTrackBar;
    MaxAngelTrackbar: TTrackBar;
    NormalizeTrackbar: TTrackBar;
    procedure BackgroundColorButtonClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure LoadButtonClick(Sender: TObject);
    procedure NormalizeCheckboxChange(Sender: TObject);
    procedure NormalizeTrackbarChange(Sender: TObject);
    procedure PointColorButtonClick(Sender: TObject);
    procedure TrackbarChange(Sender: TObject);
    procedure OptionsButtonClick(Sender: TObject);
    procedure RendererMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RendererMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure RendererMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure RendererPaint(Sender: TObject);
    procedure ScanButtonClick(Sender: TObject);
    procedure ScanTimerTimer(Sender: TObject);
  private
    FScanProcess: TProcess;

    FScan: TScanData;
    FScale: Double;
    FRotX: Double;
    FRotY: Double;
    FMoveX, FMoveY: Double;
    FMousePoint: TPoint;

    procedure HorizontalRange(out l,h: Double);
    procedure PitchRange(out l,h: Double);
    procedure DistanceRange(out l,h: Double);
    procedure UpdateUI;
  public

  end;

var
  RendererForm: TRendererForm;

implementation

{$R *.lfm}

type
  TPoint3D = record
    X, Y, Z: Double;
  end;

function ConvertPoint(const p: TPointRecord): TPoint3D; inline;

  function DegToRad(const d: Double): Double; inline;
  begin
    Result:=d/180*pi;
  end;

var
  tmp: Double;
begin
  Result:=Default(TPoint3D);
  Result.Y:=Sin(DegToRad(p.Pitch))*p.Distance;
  tmp:=Cos(DegToRad(p.Pitch))*p.Distance;
  Result.Z:=-Sin(DegToRad(p.Yaw))*tmp;
  Result.X:=Cos(DegToRad(p.Yaw))*tmp;
end;

function inFilter(value: Double; LowValue, HighValue: Double): Boolean; inline;
begin
  if LowValue<HighValue then
    Result := (value>=LowValue) and (value<=HighValue)
  else
    Result := (value>=LowValue) or (value<=HighValue);
end;


function DropForNormalization(const P: TPointRecord; NormalizationRadius: Double;
                              const ScanData: TScanData): Boolean; inline;
var
  PResolution, YResolution,
  BaseProb, DistanceProb: Double;
begin
  if NormalizationRadius<=0 then
    Exit(False);
  PResolution:=ScanData.PointsPerScan/360; // Pitch axis resolution
  YResolution:=1/ScanData.Step; // Yaw axis resolution
  // Basis probability to drop is to normalize the axial resolutions
  if PResolution>YResolution then
    BaseProb:=YResolution/PResolution
  else
    BaseProb:=PResolution/YResolution;
  // Drop probability based on distance: If larger than normalization distance
  // don't drop, otherwise drop such that the density on circle of that distance
  // is the same as on the normalization distance
  // TODO: Actually we're talking about the surface of a sphere?
  if P.Distance > NormalizationRadius then
    DistanceProb:=1
  else
    DistanceProb:=abs(Cos(DegToRad(p.Pitch))*p.Distance)/NormalizationRadius;
  // Drop the point with probability 1-BaseProb*DistanceProb
  Result := Random > BaseProb*DistanceProb;
end;


function ReadDatFile(const FileName: String; out ScanData: TScanData): Boolean;

  function CheckHeader(fs: TFileStream): Boolean; inline;
  var
    s: String[10];
    v: LongWord;
  begin
    Result := False;
    SetLength(s,10);
    if (fs.Read(s[1], 10) <> 10) or (s <> 'LIDARSCAN'#0) then
    begin
      MessageDlg('Error reading File', 'Invalid MAGIC number', mtError, [mbOK], 'Header Error');
      Exit;
    end;
    if (fs.Read(v,SizeOf(v))<>SizeOf(v)) or (v<>1) then
    begin
      MessageDlg('Error reading File', 'Invalid File Version', mtError, [mbOK], 'Header Error');
      Exit;
    end;

    Result := True;
  end;

var
  fs: TFileStream;
  buff: array[0..4095 div sizeof(TPointRecord)] of TPointRecord;
  Remainder, NumPoints: Int64;
  i, ReadHead, WriteHead: SizeInt;
begin
  ScanData:=Default(TScanData);
  Result:=False;
  fs:=TFileStream.Create(FileName,fmOpenRead);
  try
    if not CheckHeader(fs) then
      Exit;
    if (fs.Read(ScanData.Start, SizeOf(ScanData.Start)) <> SizeOf(ScanData.Start)) or
       (fs.Read(ScanData.Stop, SizeOf(ScanData.Stop)) <> SizeOf(ScanData.Stop)) or
       (fs.Read(ScanData.Step, SizeOf(ScanData.Step)) <> SizeOf(ScanData.Step)) or
       (fs.Read(ScanData.Rotations, SizeOf(ScanData.Rotations)) <> SizeOf(ScanData.Rotations)) or
       (fs.Read(ScanData.PointsPerScan, SizeOf(ScanData.PointsPerScan)) <> SizeOf(ScanData.PointsPerScan)) then
    begin
      MessageDlg('Error reading File', 'Unable to read Metadata', mtError, [mbOK], 'Metadata Error');
      Exit;
    end;
    Remainder:=fs.Size-fs.Position;
    if (Remainder mod SizeOf(TPointRecord)) <> 0 then
    begin
      MessageDlg('Error reading File', 'Malformed Point Data', mtError, [mbOK], 'Pointdata Error');
      Exit;
    end;
    NumPoints:=Remainder div SizeOf(TPointRecord);
    SetLength(ScanData.Points,NumPoints);
    ReadHead:=0;
    WriteHead:=0;
    for i:=1 to NumPoints do
    begin
      if ReadHead=0 then
      begin
        if fs.Read(buff, SizeOf(buff)) div SizeOf(TPointRecord) < Min(Length(buff), NumPoints - i) then
        begin
          MessageDlg('Error reading File', 'Missing point data', mtError, [mbOK], 'Pointdata Error');
          Exit;
        end;
      end;
      if (buff[ReadHead].Quality>0) and (buff[ReadHead].Distance>0) then
      begin
        ScanData.Points[WriteHead]:=buff[ReadHead];
        Inc(WriteHead);
      end;
      ReadHead:=(ReadHead+1) mod Length(buff);
    end;
  finally
    fs.Free;
  end;
  SetLength(ScanData.Points,WriteHead);
  Result := True;
end;

{ TRendererForm }

procedure TRendererForm.RendererPaint(Sender: TObject);
var
  p: TPointRecord;
  pd: TPoint3D;
  bgRGB, ptRGB: LongInt;
  ptAlpha, aspectRatio, ld, hd, hp, lp, la, ha, nr: Double;
begin
  // Same as exporting, if change here also change in Button Event
  DistanceRange(ld, hd);
  PitchRange(lp, hp);
  HorizontalRange(la, ha);
  nr:=NormalizeTrackbar.Position/10;
  bgRGB:=ColorToRGB(BackgroundColorButton.ButtonColor);
  ptRGB:=ColorToRGB(PointColorButton.ButtonColor);
  ptAlpha:=1.0;
  aspectRatio:=Renderer.ClientWidth/Renderer.ClientHeight;

  glClearColor((bgRGB mod 256)/$FF, ((bgRGB shr 8) mod 256)/$FF, ((bgRGB shr 16) mod 256)/$FF, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glViewport(0,0,Renderer.ClientWidth,renderer.ClientHeight);
  glFrustum(0,0,Renderer.ClientWidth,Renderer.ClientHeight, 0.01, 1000);

  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glTranslated(FMoveX,FMoveY,0);
  glScaled(FScale/aspectRatio,FScale,FScale);
  glRotatef(FRotX,0,1,0);
  glRotatef(FRotY,1,0,0);

  glBegin(GL_POINTS);
  for p in FScan.Points do
  begin
    if not inFilter(p.Pitch,lp,hp) or
       not inFilter(p.Yaw, la, ha) or
       not inFilter(p.Distance,ld,hd) or
       (NormalizeCheckbox.Checked and not DropForNormalization(p,nr,FScan)) then
      continue;
    glPointSize(4);
    ptAlpha:=p.Quality/255;
    pd:=ConvertPoint(p);
    glColor4d((ptRGB mod 256)/$FF, ((ptRGB shr 8) mod 256)/$FF, ((ptRGB shr 16) mod 256)/$FF,ptAlpha);
    glVertex3d(pd.X,pd.Y,pd.Z);
  end;
  glEnd;

  Renderer.SwapBuffers;
end;

procedure TRendererForm.ScanButtonClick(Sender: TObject);
var
  formatOpts: TFormatSettings;
begin
  if ScanButton.Tag=0 then
  begin
    ScanButton.Caption:='Stop';
    ScanButton.Tag:=1;
    ProgressBar1.Min:=Trunc(OptionsDialog.ScanOptions.RangeStart);
    ProgressBar1.Max:=Trunc(OptionsDialog.ScanOptions.RangeEnd);
    ProgressBar1.Position:=ProgressBar1.Min;

    formatOpts:=FormatSettings;
    formatOpts.DecimalSeparator:='.';
    formatOpts.ThousandSeparator:='_';

    FScanProcess:=TProcess.Create(Self);
    FScanProcess.Executable:=OptionsDialog.ScanOptions.ScanApp;
    FScanProcess.Parameters.Clear;
    FScanProcess.Parameters.Add(OptionsDialog.ScanOptions.LidarPort);
    FScanProcess.Parameters.Add(OptionsDialog.ScanOptions.ServoPort);
    FScanProcess.Parameters.Add('-f');
    FScanProcess.Parameters.Add(FloatToStr(OptionsDialog.ScanOptions.RangeStart, formatOpts));
    FScanProcess.Parameters.Add('-t');
    FScanProcess.Parameters.Add(FloatToStr(OptionsDialog.ScanOptions.RangeEnd, formatOpts));
    FScanProcess.Parameters.Add('-s');
    FScanProcess.Parameters.Add(FloatToStr(OptionsDialog.ScanOptions.RangeStep, formatOpts));
    FScanProcess.Parameters.Add('-r');
    FScanProcess.Parameters.Add(FloatToStr(OptionsDialog.ScanOptions.Rotations, formatOpts));
    FScanProcess.Parameters.Add('-b');
    FScanProcess.Parameters.Add(OptionsDialog.ScanOptions.DatFile);
    FScanProcess.Options:=FScanProcess.Options+[poUsePipes];
    FScanProcess.Execute;
    ScanTimer.Enabled:=True;
  end
  else
  begin
    FScanProcess.Terminate(1);
  end;
end;

procedure TRendererForm.ScanTimerTimer(Sender: TObject);
var
  sl: TStringList;
  line: String;
  deg, i: Integer;
  ScanData: TScanData;
begin
  if not Assigned(FScanProcess) then
    Exit;

  if FScanProcess.Output.NumBytesAvailable>0 then
  begin
    sl:=TStringList.Create;
    try
      sl.LoadFromStream(FScanProcess.Output);
      for line in sl do
        if line.StartsWith('Scanning at ') then
        begin
          deg:=0;
          for i:=13 to line.Length do
            case line[i] of
            '0'..'9': deg := deg * 10 + ord(line[i])-ord('0');
            otherwise break;
            end;
          ProgressBar1.Position:=deg;
        end;
    finally
      sl.Free;
    end;
  end;
  if FScanProcess.Running then
    Exit;

  try
    if FScanProcess.ExitCode<>0 then
    begin
      sl:=TStringList.Create;
      try
        sl.LoadFromStream(FScanProcess.Stderr);
        MessageDlg('Error while Scanning', sl.Text, mtError, [mbOK], 'Error');
      finally
        sl.Free;
      end;
      Exit;
    end;
  finally
    ScanButton.Caption:='Scan';
    ScanButton.Tag:=0;
    ScanTimer.Enabled:=False;
    FreeAndNil(FScanProcess);
  end;

  FScan:=Default(TScanData);
  if not ReadDatFile(OptionsDialog.ScanOptions.DatFile, ScanData) then
    Exit;
  FScan:=ScanData;
  RangeStartEdit.Text:=ScanData.Start.ToString;
  RangeEndEdit.Text:=ScanData.Stop.ToString;
  RangeStepEdit.Text:=ScanData.Step.ToString;
  RotationsEdit.Text:=ScanData.Rotations.ToString;
  PPSEdit.Text:=ScanData.PointsPerScan.ToString;
  FScale:=0.1;
  FRotX:=0;
  FRotY:=0;
  FMoveX:=0;
  FMoveY:=0;
  Renderer.Invalidate;
end;

procedure TRendererForm.HorizontalRange(out l, h: Double);
begin
  l:=FScan.Start+(FScan.Stop-FScan.Start)*(1-MinAngelTrackbar.Position/MinAngelTrackbar.Max);
  h:=FScan.Start+(FScan.Stop-FScan.Start)/MaxAngelTrackbar.Max*MaxAngelTrackbar.Position;
end;

procedure TRendererForm.PitchRange(out l, h: Double);
begin
  l:=360-360/MinPitchTrackbar.Max*MinPitchTrackbar.Position;
  h:=360/MaxPitchTrackbar.Max*MaxPitchTrackbar.Position;
end;

procedure TRendererForm.DistanceRange(out l, h: Double);
begin
  l:=32-32/MinDistanceTrackbar.Max*MinDistanceTrackbar.Position;
  h:=32/MaxDistanceTrackbar.Max*MaxDistanceTrackbar.Position;
end;

procedure TRendererForm.UpdateUI;
var
  ld, hd, lp, hp, la, ha: Double;
begin
  DistanceRange(ld, hd);
  MinDistanceLabel.Caption:=FloatToStrF(ld,ffFixed,2,2);
  MaxDistanceLabel.Caption:=FloatToStrF(hd,ffFixed,2,2);
  PitchRange(lp, hp);
  MinPitchLabel.Caption:=FloatToStrF(lp,ffFixed,2,2);
  MaxPitchLabel.Caption:=FloatToStrF(hp,ffFixed,2,2);
  HorizontalRange(la, ha);
  MinAngelLabel.Caption:=FloatToStrF(la,ffFixed,2,2);
  MaxAngelLabel.Caption:=FloatToStrF(ha,ffFixed,2,2);
  NormalizeTrackbar.Enabled:=NormalizeCheckbox.Checked;
  Invalidate;
end;

procedure TRendererForm.LoadButtonClick(Sender: TObject);
var
  ScanData: TScanData;
begin
  if not OpenDatFileDialog.Execute then
    Exit;
  ScanData:=Default(TScanData);
  if not ReadDatFile(OpenDatFileDialog.FileName, ScanData) then
    Exit;
  FScan:=ScanData;
  RangeStartEdit.Text:=ScanData.Start.ToString;
  RangeEndEdit.Text:=ScanData.Stop.ToString;
  RangeStepEdit.Text:=ScanData.Step.ToString;
  RotationsEdit.Text:=ScanData.Rotations.ToString;
  PPSEdit.Text:=ScanData.PointsPerScan.ToString;
  FScale:=0.1;
  FRotX:=0;
  FRotY:=0;
  FMoveX:=0;
  FMoveY:=0;
  Renderer.Invalidate;
end;

procedure TRendererForm.NormalizeCheckboxChange(Sender: TObject);
begin
  UpdateUI;
end;

procedure TRendererForm.NormalizeTrackbarChange(Sender: TObject);
begin
  UpdateUI;
end;

procedure TRendererForm.PointColorButtonClick(Sender: TObject);
begin
  UpdateUI;
end;

procedure TRendererForm.TrackbarChange(Sender: TObject);
begin
  if MaxDistanceTrackbar.Position<MinDistanceTrackbar.Max - MinDistanceTrackbar.Position then
    MaxDistanceTrackbar.Position:=MinDistanceTrackbar.Max - MinDistanceTrackbar.Position;
  UpdateUI;
end;

procedure TRendererForm.FormCreate(Sender: TObject);
begin
  Randomize;
  FScan.Start:=0;
  FScan.Stop:=180;
  UpdateUI;
end;

procedure TRendererForm.BitBtn1Click(Sender: TObject);
var
  ld, hd, lp, hp, la, ha, nr: Double;
  p: TPointRecord;
  pd: TPoint3D;
  OutFile: TextFile;
  Cnt: SizeInt;
begin
  if not SaveDialog1.Execute then
    Exit;
  System.Assign(OutFile, SaveDialog1.FileName);
  try
    Rewrite(OutFile);
    // Same as rendering, if change here also change in Paint Event
    DistanceRange(ld, hd);
    PitchRange(lp, hp);
    HorizontalRange(la, ha);
    nr:=NormalizeTrackbar.Position/10;
    cnt:=0;
    for p in FScan.Points do
    begin
      if not inFilter(p.Pitch,lp,hp) or
         not inFilter(p.Yaw, la, ha) or
         not inFilter(p.Distance,ld,hd) or
         (NormalizeCheckbox.Checked and not DropForNormalization(p,nr,FScan)) then
        continue;
      Inc(cnt);
      pd:=ConvertPoint(p);
      WriteLn(OutFile, Format('%.6f %.6f %.6f %d 255 255 255 %f %f %f', [pd.X,pd.Y,pd.Z,p.Quality,-pd.X/p.Distance,-pd.Y/p.Distance,-pd.Z/p.Distance]));
    end;
  finally
    System.Close(OutFile);
  end;
end;

procedure TRendererForm.BackgroundColorButtonClick(Sender: TObject);
begin
  UpdateUI;
end;

procedure TRendererForm.FormResize(Sender: TObject);
begin
  MaxPitchTrackbar.Height:=(Panel4.ClientHeight-MaxPitchLabel.Height-MinPitchLabel.Height) div 2;
  MaxDistanceTrackbar.Height:=(Panel3.ClientHeight-MaxDistanceLabel.Height-MinDistanceLabel.Height) div 2;
end;

procedure TRendererForm.OptionsButtonClick(Sender: TObject);
begin
  OptionsDialog.ShowModal;
  Renderer.Invalidate;
end;

procedure TRendererForm.RendererMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMousePoint:=Point(X,Y);
end;

procedure TRendererForm.RendererMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  dx, dy: Double;
begin
  dx:=(X-FMousePoint.X)/Renderer.ClientWidth;
  dy:=(Y-FMousePoint.Y)/Renderer.ClientHeight;
  FMousePoint:=Point(X,Y);
  if ssLeft in Shift then
  begin
    FRotX+=dx*180;
    FRotY+=dy*180;
    Renderer.Invalidate;
  end;
  if ssRight in Shift then
  begin
    FMoveX+=dx*2;
    FMoveY-=dy*2;
    Renderer.Invalidate;
  end;
end;

procedure TRendererForm.RendererMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  FScale *= 1+WheelDelta/512;
  Renderer.Invalidate;
end;

end.

