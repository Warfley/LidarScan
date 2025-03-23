unit RenderingForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, process, openglcontext, gl, Math, Types, optionsform;

type
  TPointData = record
    X, Y, Z: Double;
    Quality: Double;
  end;

  TPointDataArray = Array of TPointData;

  TScanData = record
    Start, Stop, Step,
    Rotations: Double;
    PointsPerScan: LongWord;
    Points: Array of TPointData;
  end;

  { TRendererForm }

  TRendererForm = class(TForm)
    LoadButton: TButton;
    ProgressBar1: TProgressBar;
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
    procedure FormCreate(Sender: TObject);
    procedure LoadButtonClick(Sender: TObject);
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

    FPoints: TPointDataArray;
    FScale: Double;
    FRotX: Double;
    FRotY: Double;
    FMoveX, FMoveY: Double;
    FMousePoint: TPoint;
  public

  end;

var
  RendererForm: TRendererForm;

implementation

{$R *.lfm}


function ReadDatFile(const FileName: String; out ScanData: TScanData;
                     const Filters: TFilterRanges; const MaxRadius: Double;
                     const NormalizationRadius: Double): Boolean;

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

type
  TPointRecord = packed record
    Yaw, Pitch, Distance: Double;
    Quality: Byte;
  end;

  function ConvertPoint(const p: TPointRecord): TPointData; inline;

    function DegToRad(const d: Double): Double; inline;
    begin
      Result:=d/180*pi;
    end;

  var
    tmp: Double;
  begin
    Result:=Default(TPointData);
    Result.Y:=Sin(DegToRad(p.Pitch))*p.Distance;
    tmp:=Cos(DegToRad(p.Pitch))*p.Distance;
    Result.Z:=-Sin(DegToRad(p.Yaw))*tmp;
    Result.X:=Cos(DegToRad(p.Yaw))*tmp;
    Result.Quality:=p.Quality/255;
  end;

  function inFilter(pitch: Double): Boolean;
  var
    range: Array[0..1] of Double;
  begin
    if Length(Filters) = 0 then
      Exit(True);
    Result:=False;
    for range in Filters do
      if range[0]<=range[1] then
      begin
        if (pitch>=range[0]) and (pitch<=range[1]) then
          Exit(True);
      end
      else if (pitch>=range[0]) or (pitch<=range[1]) then
        Exit(True);
  end;

  function DropForNormalization(const P: TPointRecord): Boolean; inline;
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
      if (buff[ReadHead].Quality>0) and (buff[ReadHead].Distance>0) and
         inFilter(buff[ReadHead].Pitch) and
         (buff[ReadHead].Distance<=MaxRadius) and
         not DropForNormalization(buff[ReadHead]) then
      begin
        ScanData.Points[WriteHead]:=ConvertPoint(buff[ReadHead]);
        Inc(WriteHead);
      end;
      ReadHead:=(ReadHead+1) mod Length(buff);
    end;
  finally
    fs.Free;
  end;
  Result := True;
end;

{ TRendererForm }

procedure TRendererForm.RendererPaint(Sender: TObject);
var
  p: TPointData;
  bgRGB, ptRGB: LongInt;
  ptAlpha, aspectRatio: Double;
begin
  bgRGB:=ColorToRGB(OptionsDialog.RenderingOptions.BackgroundColor);
  ptRGB:=ColorToRGB(OptionsDialog.RenderingOptions.PointColor);
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
  for p in FPoints do
  begin
    glPointSize(4);
    if OptionsDialog.RenderingOptions.AlphaQuality then
      ptAlpha:=p.Quality;
    glColor4d((ptRGB mod 256)/$FF, ((ptRGB shr 8) mod 256)/$FF, ((ptRGB shr 16) mod 256)/$FF,ptAlpha);
    glVertex3d(p.X,p.Y,p.Z);
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

  ScanData:=Default(TScanData);
  if not ReadDatFile(OptionsDialog.ScanOptions.DatFile, ScanData,
                     OptionsDialog.RenderingOptions.FilterRanges,
                     OptionsDialog.RenderingOptions.MaximumRadius,
                     OptionsDialog.RenderingOptions.NormalizationRadius) then
    Exit;
  FPoints:=ScanData.Points;
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

procedure TRendererForm.LoadButtonClick(Sender: TObject);
var
  ScanData: TScanData;
begin
  if not OpenDatFileDialog.Execute then
    Exit;
  ScanData:=Default(TScanData);
  if not ReadDatFile(OptionsDialog.ScanOptions.DatFile, ScanData,
                     OptionsDialog.RenderingOptions.FilterRanges,
                     OptionsDialog.RenderingOptions.MaximumRadius,
                     OptionsDialog.RenderingOptions.NormalizationRadius) then
    Exit;
  FPoints:=ScanData.Points;
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

procedure TRendererForm.FormCreate(Sender: TObject);
begin
  Randomize;
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

