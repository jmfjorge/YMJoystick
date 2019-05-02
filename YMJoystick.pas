unit YMJoystick;
interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Forms, Dialogs, MMSystem;

type
  {Event prototypes}
  TErrorOccurred  = procedure (Sender: TObject; Error: integer; Msg: string) of object;
  TMove           = procedure (Sender: TObject; Joystick: word; X,Y: word; Buttons: word) of object;
  TZMove          = procedure (Sender: TObject; Joystick: word; Z: word; Buttons: word) of object;
  TButtonPushed   = procedure (Sender: TObject; Joystick: word; Buttons: word) of object;
  TButtonReleased = procedure (Sender: TObject; Joystick: word; Buttons: word) of object;

  TJoystickId = (JoystickId1, JoystickId2);

  TYMJoystick = class(TComponent)
  private
    { Private declarations }
    Handle          : THandle;
    FPolling        : Boolean;{private} {Is message receive active}
    FEnabled        : Boolean;
    FPassivePolling : Boolean;
    {from DevCaps}
    FManufacturerId : Word;   {r}
    FProductId      : word;   {r}
    FProductName    : string; {r}
    FXmin           : word;   {r}
    FXmax           : word;   {r}
    fXpos           : word;   {r}
    FYmin           : word;   {r}
    FYmax           : word;   {r}
    fYpos           : word;   {r}
    FZmin           : word;   {r}
    FZmax           : word;   {r}
    fZpos           : word;   {r}
    FPeriodMax      : word;   {r}
    FPeriodMin      : word;   {r}
    FPeriod         : word;   {r/w/d} {polling rate, in milliseconds}
    FNumButtons     : word;   {r}
    FThreshold      : word;   {r/w/d}
    FButton1        : Boolean;{r}
    FButton2        : Boolean;{r}
    FButton3        : Boolean;{r}
    FButton4        : Boolean;{r}
    FNumJoysticks   : word;   {r}
    FJoystickId     : TJoystickId;
    FJoyId          : word;   {r/w/d} {Control working on joy1 or joy2}
    {events}
    FOnMove           : TMove;           {Fires when Joystick X,Y move message is recieved}
    FOnZMove          : TZMove;          {Fires when Joystick Z move message is recieved}
    FOnButtonPushed   : TButtonPushed;   {Fires when Joystick button is pushed}
    FOnButtonReleased : TButtonReleased; {Fires when Joystick button is released}
    FOnErrorOccurred  : TErrorOccurred;  {Fires when error message is received}
  protected
    { Protected declarations }
    procedure UpdateGeneralProperties;            {Fill properties with GetDeviceCaps}
    procedure SetJoystick(Value: TJoystickId);    {Set Joystick to poll}
    procedure SetEnabled(Value: Boolean);         {Start or Stop polling}
    procedure SetThreshold(Value: word);
    function  GetThreshold: word;
    procedure StartPolling;                       {Start receiving joystick messages}
    procedure StopPolling;                        {Stop receiving joystick messages}
    procedure SetPeriod(Value: word);             {Set the polling period}
    function  GetNumJoysticks: word;              {Return # joysticks supported by driver}
    procedure JoystickInput(var Msg: TMessage);   {MM message handler}
    procedure Error(ErrValue: integer);           {Handle Errors}
  public
    { Public declarations }
    constructor Create(AOwner:TComponent); override;
    destructor  Destroy; override;
    procedure   PollJoystick;                     {Force a read of the joystick}
  published
    { Published declarations }
    property Enabled        : Boolean read FEnabled write SetEnabled default False;
    property ManufacturerId : Word    read FManufacturerId;
    property ProductId      : word    read FProductId;
    property ProductName    : string  read FProductName;
    property Xmin           : word    read FXmin;
    property Xmax           : word    read FXmax;
    property Xpos           : word    read FXpos;
    property Ymin           : word    read FYmin;
    property Ymax           : word    read FYmax;
    property Ypos           : word    read FYpos;
    property Zmin           : word    read FZmin;
    property Zmax           : word    read FZmax;
    property Zpos           : word    read FZpos;
    property PeriodMax      : word    read FPeriodMax;
    property PeriodMin      : word    read FPeriodMin;
    property PollingPeriod  : word    read FPeriod write SetPeriod default 50;
    property NumButtons     : word    read FNumButtons;
    property Button1        : boolean read FButton1;
    property Button2        : boolean read FButton2;
    property Button3        : boolean read FButton3;
    property Button4        : boolean read FButton4;
    property NumJoysticks   : word    read GetNumJoysticks;
    property Threshold      : word    read GetThreshold write SetThreshold default 1000;
    property PassivePolling : Boolean read FPassivePolling write FPassivePolling default true;
    property Joystick       : TJoystickId read FJoystickId write SetJoystick default JOYSTICKID1; {0}
    {events}
    property OnMove           : TMove           read FOnMove           write FOnMove;
    property OnZMove          : TZMove          read FOnZMove          write FOnZMove;
    property OnButtonPushed   : TButtonPushed   read FOnButtonPushed   write FOnButtonPushed;
    property OnButtonReleased : TButtonReleased read FOnButtonReleased write FOnButtonReleased;
    property OnErrorOccurred  : TErrorOccurred  read FOnErrorOccurred  write FOnErrorOccurred;
  end;

procedure Register;

implementation

constructor TYMJoystick.Create(AOwner:TComponent);
var
  wResult : word;
  JoyCaps : TJoyCaps;
begin
  inherited Create(AOwner);

  {Set defaults}
  FPassivePolling := True;
  FPolling        := False;  {check enabled}
  FPeriod         := 50;
  FJoystickId     := JOYSTICKID1;

  {Create the window for callback notification }
  if not (csDesigning in ComponentState) then begin
    Handle := AllocateHwnd(JoyStickInput);
  end;

  {Get Device caps}
  UpdateGeneralProperties;
end;

destructor TYMJoystick.Destroy;
begin
  {Stop Polling if active}
  If FPolling then begin
    StopPolling;
    FPolling := False;
  end;
  {Free the handle created to receive messages}
  If Handle <> 0 then begin
    DeallocateHwnd(Handle);
  end;
  inherited Destroy;
end;

procedure TYMJoystick.SetEnabled(Value: Boolean);
begin
  if (csDesigning in ComponentState) then begin
    FEnabled := Value;
    exit;
  end;

  If Value <> FEnabled then begin
    If Value then begin
      If not FPolling then StartPolling;
      FEnabled := True;
    end else begin
      If FPolling then StopPolling;
      FEnabled := False;
    end;
  end;
end;

function TYMJoystick.GetNumJoysticks: word;
begin
  Result := joyGetNumDevs;
end;

procedure TYMJoystick.SetPeriod(Value: word);
begin
  If Value > FPeriodMax      then FPeriod := FPeriodMax
  else if Value < FPeriodMin then FPeriod := FPeriodMin
  else                            FPeriod := Value;
end;

procedure TYMJoystick.UpdateGeneralProperties;
var
  wResult : word;
  JoyCaps : TJoyCaps;
begin
  wResult := joyGetDevCaps(FJoyId, @JoyCaps, SizeOf(TJoyCaps));
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
    exit;
  end else begin
    with JoyCaps do begin
      FManufacturerId := wMid;            { manufacturer ID                       }
      FProductId      := wPid;            { product ID                            }
      FProductName    := StrPas(szPname); { product name (NULL terminated string) }
      FXmin           := wXmin;           { minimum x position value              }
      FXmax           := wXmax;           { maximum x position value              }
      FYmin           := wYmin;           { minimum y position value              }
      FYmax           := wYmax;           { maximum y position value              }
      FXmin           := wZmin;           { minimum z position value              }
      FZmax           := wZmax;           { maximum z position value              }
      FNumButtons     := wNumButtons;     { number of buttons                     }
      FPeriodMin      := wPeriodMin;      { minimum message period when captured  }
      FPeriodMax      := wPeriodMax;      { maximum message period when captured  }
    end;
  end;
end;

procedure TYMJoystick.SetJoystick(Value: TJoystickId);
begin
  If Value <> FJoystickId then begin
    If (Value <> JoystickId1) and (Value <> JoystickId2) then begin
      FJoyId := Word(JoystickId1);
    end else begin
      If Value =  JoystickId1 then begin
        FJoyId      := Word(JoystickId1);
        UpdateGeneralProperties;
      end else begin
        FJoyId      := Word(JoystickId2);
        UpdateGeneralProperties;
      end;
    end;
  end;
end;

procedure TYMJoystick.PollJoystick;  {Force a read of the joystick}
var
  wResult : word;
  JoyInfo : TJoyInfo;
begin
  wResult := joyGetPos(FJoyId, @JoyInfo);
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
    exit;
  end;
  {Set values}
  With JoyInfo do begin
    FXpos := wXpos;                 { x position }
    FYpos := wYpos;                 { y position }
    FZpos := wZpos;                 { z position }
    { button states }
    If Bool(wButtons and JOY_BUTTON1) then FButton1 := True else FButton1 := False;
    If Bool(wButtons and JOY_BUTTON2) then FButton2 := True else FButton2 := False;
    If Bool(wButtons and JOY_BUTTON3) then FButton3 := True else FButton3 := False;
    If Bool(wButtons and JOY_BUTTON4) then FButton4 := True else FButton4 := False;
  end;
end;

procedure TYMJoystick.SetThreshold(Value: word);
var
  wResult : word;
begin
  wResult := joySetThreshold(FJoyId, Value);
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
    exit;
  end;
  FThreshold := Value;
end;

function TYMJoystick.GetThreshold: word;
var
  wResult   : word;
  Threshold : word;
begin
  wResult := joyGetThreshold(FJoyId, @Threshold);
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
    exit;
  end;
  FThreshold := Threshold;
  Result := Threshold;
end;

procedure TYMJoystick.StartPolling;
var
  wResult : word;
begin
  If Handle = 0 then exit;
  wResult := joySetCapture(Handle, FJoyId, FPeriod, FPassivePolling);
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
    exit;
  end;
  FEnabled := True;
  FPolling := True;
end;

procedure TYMJoystick.StopPolling;
var
  wResult : word;
begin
  If Handle = 0 then exit;
  wResult := joyReleaseCapture(FJoyId);
  If wResult <> JOYERR_NOERROR then begin
    Error(wResult);
  end;
  FPolling := False;
end;

procedure TYMJoystick.JoystickInput(var Msg: TMessage);
var
  Joystick : word;
  Buttons  : word;
  X,Y,Z    : word;

  procedure SetButtonStates(Buttons: word);
  begin
    If Bool(Buttons and JOY_BUTTON1) then FButton1 := True else FButton1 := False;
    If Bool(Buttons and JOY_BUTTON2) then FButton2 := True else FButton2 := False;
    If Bool(Buttons and JOY_BUTTON3) then FButton3 := True else FButton3 := False;
    If Bool(Buttons and JOY_BUTTON4) then FButton4 := True else FButton4 := False;
  end;

  procedure SetButtonDown(Buttons: word);
  begin
    If Bool(Buttons and JOY_BUTTON1CHG) then FButton1 := True;
    If Bool(Buttons and JOY_BUTTON2CHG) then FButton2 := True;
    If Bool(Buttons and JOY_BUTTON3CHG) then FButton3 := True;
    If Bool(Buttons and JOY_BUTTON4CHG) then FButton4 := True;
  end;

  procedure SetButtonUp(Buttons: word);
  begin
    If Bool(Buttons and JOY_BUTTON1CHG) then FButton1 := False;
    If Bool(Buttons and JOY_BUTTON2CHG) then FButton2 := False;
    If Bool(Buttons and JOY_BUTTON3CHG) then FButton3 := False;
    If Bool(Buttons and JOY_BUTTON4CHG) then FButton4 := False;
  end;

begin
  Case Msg.Msg of
    MM_Joy1ButtonDown :
      begin
        If  FJoyId = word(JOYSTICKID1) then begin
          FXPos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          SetButtonDown(Msg.wParam);
          {Call the user's event handler}
          If Assigned(FOnButtonPushed) then FOnButtonPushed(Self, 1, Msg.wParam);
        end;
      end;
    MM_Joy1ButtonUp   :
      begin
        If  FJoyId = word(JOYSTICKID1) then begin
          FXPos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          SetButtonUp(Msg.wParam);
          {Call the user's event handler}
          If Assigned(FOnButtonReleased) then FOnButtonReleased(Self, 1, Msg.wParam);
        end;
      end;
    MM_Joy1Move      :
      begin
        If  FJoyId = word(JOYSTICKID1) then begin
          SetButtonStates(Msg.wParam);
          FXPos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          {Call the user's event handler}
          If Assigned(FOnMove) then FOnMove(Self, 2, Msg.lParamLo, Msg.lParamHi, Msg.wParam);
        end;
      end;
    MM_Joy1ZMove     :
      begin
        If  FJoyId = word(JOYSTICKID1) then begin
          SetButtonStates(Msg.wParam);
          FZpos := Msg.lParamLo;
          {Call the user's event handler}
          If Assigned(FOnZMove) then FOnZMove(Self, 2, Msg.lParamLo, Msg.wParam);
        end;
      end;
    MM_Joy2ButtonDown :
      begin
        If  FJoyId = word(JOYSTICKID2) then begin
          FXPos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          SetButtonDown(Msg.wParam);
          {Call the user's event handler}
          If Assigned(FOnButtonPushed) then FOnButtonPushed(Self, 2, Msg.wParam);
        end;
      end;
    MM_Joy2ButtonUp   :
      begin
        If  FJoyId = word(JOYSTICKID2) then begin
          FXPos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          SetButtonUp(Msg.wParam);
          {Call the user's event handler}
          If Assigned(FOnButtonReleased) then FOnButtonReleased(Self, 2, Msg.wParam);
       end;
      end;
    MM_Joy2Move       :
      begin
        If  FJoyId = word(JOYSTICKID2) then begin
          SetButtonStates(Msg.wParam);
          FXpos := Msg.lParamLo;
          FYpos := Msg.lParamHi;
          {Call the user's event handler}
          If Assigned(FOnMove) then FOnMove(Self, 2, Msg.lParamLo, Msg.lParamHi, Msg.wParam);
        end;
      end;
    MM_Joy2ZMove      :
      begin
        If  FJoyId = word(JOYSTICKID2) then begin
          SetButtonStates(Msg.wParam);
          FZpos := Msg.lParamLo;
          {Call the user's event handler}
          If Assigned(FOnZMove) then FOnZMove(Self, 2, Msg.lParamLo, Msg.wParam);
        end;
      end;
    else
      If Handle <> 0 then Msg.Result := DefWindowProc(Handle, Msg.Msg, Msg.wParam, Msg.lParam);
  end; {Case}
end;

{Handle Driver and other joystick errors}
procedure TYMJoystick.Error(ErrValue: integer);
var
  Msg : string;
begin
  case ErrValue of
    MMSYSERR_NODRIVER :
      begin
        FEnabled := False;
        FPolling := False;
        Msg := 'The joystick driver is not present.';
      end;
    JOYERR_PARMS      :
      begin
        FEnabled := False;
        FPolling := False;
        Msg := 'The specified joystick device ID wId is invalid.';
      end;
    JOYERR_NOCANDO    :
      begin
        FEnabled := False;
        FPolling := False;
        Msg := 'Cannot capture joystick input because some required'+ #13#10 +
               'service (for example, a Windows timer) is unavailable.';
      end;
    JOYERR_UNPLUGGED  :
      begin
        FEnabled := False;
        FPolling := False;
        Msg := 'The specified joystick is not connected to the system.';
      end;
    else begin
      FEnabled := False;
      FPolling := False;
      Msg := 'An unknown error has occurred.';
    end;
  end; {case}

  if Assigned(FOnErrorOccurred) then
    FOnErrorOccurred(Self, ErrValue, Msg);
end;

procedure Register;
begin
  RegisterComponents('YoungArts', [TYMJoystick]);
end;


end.
