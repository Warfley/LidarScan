unit RenderingForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  OpenGLContext, gl, Math, Types;

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

  { TForm1 }

  TForm1 = class(TForm)
    LoadButton: TButton;
    BacksideCheckbox: TCheckBox;
    NormalizeCheckbox: TCheckBox;
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
    procedure LoadButtonClick(Sender: TObject);
    procedure RendererMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RendererMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure RendererMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure RendererPaint(Sender: TObject);
  private
    FPoints: TPointDataArray;
    FScale: Double;
    FRotX: Double;
    FRotY: Double;
    FMousePoint: TPoint;
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.RendererPaint(Sender: TObject);
var
  p: TPointData;
begin
  glClearColor(0.27, 0.53, 0.71, 1.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glScaled(FScale,FScale,FScale);
  glRotatef(FRotX,0,1,0);
  glRotatef(FRotY,1,0,0);
  glBegin(GL_POINTS);
  for p in FPoints do
  begin
    glPointSize(4);
    glColor4d(1,1,1,p.Quality);
    glVertex3d(p.X,p.Y,p.Z);
  end;
  glEnd;
  Renderer.SwapBuffers;
end;

function ReadDatFile(const FileName: String; out ScanData: TScanData; Backside:Boolean): Boolean;

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
  Result.Z:=Sin(DegToRad(p.Pitch))*p.Distance/32;
  tmp:=Cos(DegToRad(p.Pitch))*p.Distance/32;
  Result.Y:=Sin(DegToRad(p.Yaw))*tmp;
  Result.X:=Cos(DegToRad(p.Yaw))*tmp;
  Result.Quality:=p.Quality/255;
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
         (Backside or ((buff[ReadHead].Pitch<=90) or (buff[ReadHead].Pitch>=270))) then
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

procedure TForm1.LoadButtonClick(Sender: TObject);
var
  ScanData: TScanData;
begin
  if not OpenDatFileDialog.Execute then
    Exit;
  if not ReadDatFile(OpenDatFileDialog.FileName, ScanData, BacksideCheckbox.Checked) then
    Exit;
  FPoints:=ScanData.Points;
  RangeStartEdit.Text:=ScanData.Start.ToString;
  RangeEndEdit.Text:=ScanData.Stop.ToString;
  RangeStepEdit.Text:=ScanData.Step.ToString;
  RotationsEdit.Text:=ScanData.Rotations.ToString;
  PPSEdit.Text:=ScanData.PointsPerScan.ToString;
  FScale:=1;
  FRotX:=0;
  FRotY:=0;
  Renderer.Invalidate;
end;

procedure TForm1.RendererMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMousePoint:=Point(X,Y);
end;

procedure TForm1.RendererMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  dx, dy: Integer;
begin
  if ssLeft in Shift then
  begin
    dx:=X-FMousePoint.X;
    dy:=Y-FMousePoint.Y;
    FMousePoint:=Point(X,Y);
    FRotX+=dx/Renderer.ClientWidth*180;
    FRotY+=dy/Renderer.ClientHeight*180;
    Renderer.Invalidate;
  end;
end;

procedure TForm1.RendererMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  FScale *= 1+WheelDelta/512;
  Renderer.Invalidate;
end;

end.

