unit LemReplay;

// Handles replay files. Has backwards compatibility for loading old replay
// files, too.

// The replay items contain a lot of unnessecary information for normal
// usage. Only the type of action (inferred from which of TReplay's lists
// the item is stored in, and if nessecary, using an "if <var> is <class>"),
// the frame number, and if applicable the skill, release rate and/or lemming
// index are used in normal situations. The remaining data is intended to be
// used by a future "replay repair" code. (The main purpose of the seperation
// into three lists is due to the different timings of when they're acted on,
// more than being primarily intended to distinguish them. But the distinction
// may as well be taken advantage of.)

interface

uses
  Dialogs,
  LemNeoParser, LemLemming, LemCore, LemStrings,
  Contnrs, Classes, SysUtils, StrUtils;

const
  SKILL_REPLAY_NAME_COUNT = 16;
  SKILL_REPLAY_NAMES: array[0..SKILL_REPLAY_NAME_COUNT-1] of String =
                                               ('WALKER', 'CLIMBER', 'SWIMMER',
                                                'FLOATER', 'GLIDER', 'DISARMER',
                                                'BOMBER', 'STONER', 'BLOCKER',
                                                'PLATFORMER', 'BUILDER', 'STACKER',
                                                'BASHER', 'MINER', 'DIGGER',
                                                'CLONER');


type
  TReplayAction = (ra_None, ra_AssignSkill, ra_ChangeReleaseRate, ra_Nuke,
                   ra_SelectSkill, ra_HighlightLemming);

  TBaseReplayItem = class
    private
      fFrame: Integer;
    protected
      function DoLoadLine(Line: TParserLine): Boolean; virtual;    // Return TRUE if the line is understood. Should start with "if inherited then Exit".
      procedure DoSave(SL: TStringList; aLabel: String); virtual;                  // Should start with a call to inherited.
    public
      procedure Load(Parser: TNeoLemmixParser);
      procedure Save(SL: TStringList);
      property Frame: Integer read fFrame write fFrame;
  end;

  TBaseReplayLemmingItem = class(TBaseReplayItem)
    private
      fLemmingIndex: Integer;
      fLemmingX: Integer;
      fLemmingDx: Integer;
      fLemmingY: Integer;
      fLemmingHighlit: Boolean;
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
    public
      procedure SetInfoFromLemming(aLemming: TLemming; aHighlit: Boolean);
      property LemmingIndex: Integer read fLemmingIndex write fLemmingIndex;
      property LemmingX: Integer read fLemmingX write fLemmingX;
      property LemmingDx: Integer read fLemmingDx write fLemmingDx;
      property LemmingY: Integer read fLemmingY write fLemmingY;
      property LemmingHighlit: Boolean read fLemmingHighlit write fLemmingHighlit;
  end;

  TReplaySkillAssignment = class(TBaseReplayLemmingItem)
    private
      fSkill: TBasicLemmingAction;
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
    public
      property Skill: TBasicLemmingAction read fSkill write fSkill;
  end;

  TReplayChangeReleaseRate = class(TBaseReplayItem)
    private
      fNewReleaseRate: Integer;
      fSpawnedLemmingCount: Integer;
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
    public
      property NewReleaseRate: Integer read fNewReleaseRate write fNewReleaseRate;
      property SpawnedLemmingCount: Integer read fSpawnedLemmingCount write fSpawnedLemmingCount;
  end;

  TReplayNuke = class(TBaseReplayItem)
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
  end;

  {TReplaySelectSkill = class(TBaseReplayItem)
    private
      fSkill: TSkillPanelButton;
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
    public
      property Skill: TSkillPanelButton read fSkill write fSkill;
  end;

  TReplayHighlightLemming = class(TBaseReplayLemmingItem)
    protected
      function DoLoadLine(Line: TParserLine): Boolean; override;
      procedure DoSave(SL: TStringList; aLabel: String); override;
  end;}

  TReplayItemList = class(TObjectList)
    private
      function GetItem(Index: Integer): TBaseReplayItem;
    public
      constructor Create;
      function Add(Item: TBaseReplayItem): Integer;
      procedure Insert(Index: Integer; Item: TBaseReplayItem);
      property Items[Index: Integer]: TBaseReplayItem read GetItem; default;
      property List;
  end;

  TReplay = class
    private
      fAssignments: TReplayItemList;        // nuking is also included here
      fReleaseRateChanges: TReplayItemList;
      fInterfaceActions: TReplayItemList;
      fPlayerName: String;
      fLevelName: String;
      fLevelAuthor: String;
      fLevelGame: String;
      fLevelRank: String;
      fLevelPosition: Integer;
      fLevelID: Cardinal;
      function GetLastActionFrame: Integer;
      function GetItemByFrame(aFrame: Integer; aItemType: Integer): TBaseReplayItem;
      procedure SaveReplayList(aList: TReplayItemList; SL: TStringList);
      //procedure SaveReplayItem(aItem: TBaseReplayItem; SL: TStringList);
      //function LoadReplayItem(aParser: TNeoLemmixParser): TBaseReplayItem;
    public
      constructor Create;
      destructor Destroy; override;
      procedure Add(aItem: TBaseReplayItem);
      procedure Clear(EraseLevelInfo: Boolean = false);
      procedure LoadFromFile(aFile: String);
      procedure SaveToFile(aFile: String);
      procedure LoadOldReplayFile(aFile: String);
      procedure Cut(aLastFrame: Integer);
      function HasAnyActionAt(aFrame: Integer): Boolean;
      property PlayerName: String read fPlayerName write fPlayerName;
      property LevelName: String read fLevelName write fLevelName;
      property LevelAuthor: String read fLevelAuthor write fLevelAuthor;
      property LevelGame: String read fLevelGame write fLevelGame;
      property LevelRank: String read fLevelRank write fLevelRank;
      property LevelPosition: Integer read fLevelPosition write fLevelPosition;
      property LevelID: Cardinal read fLevelID write fLevelID;
      property Assignment[aFrame: Integer]: TBaseReplayItem Index 1 read GetItemByFrame;
      property ReleaseRateChange[aFrame: Integer]: TBaseReplayItem Index 2 read GetItemByFrame;
      property InterfaceAction[aFrame: Integer]: TBaseReplayItem Index 3 read GetItemByFrame;
      property LastActionFrame: Integer read GetLastActionFrame;
  end;

  function GetSkillReplayName(aButton: TSkillPanelButton): String; overload;
  function GetSkillReplayName(aAction: TBasicLemmingAction): String; overload;
  function GetSkillButton(aName: String): TSkillPanelButton;
  function GetSkillAction(aName: String): TBasicLemmingAction;

implementation

// Standalone functions

function GetSkillReplayName(aButton: TSkillPanelButton): String;
begin
  Result := SKILL_REPLAY_NAMES[Integer(aButton)];
end;

function GetSkillReplayName(aAction: TBasicLemmingAction): String;
begin
  Result := GetSkillReplayName(ActionToSkillPanelButton[aAction]);
end;

function GetSkillButton(aName: String): TSkillPanelButton;
var
  i: Integer;
begin
  aName := Uppercase(aName);
  for i := 0 to SKILL_REPLAY_NAME_COUNT-1 do
    if aName = SKILL_REPLAY_NAMES[i] then
    begin
      Result := TSkillPanelButton(i);
      Exit;
    end;
end;

function GetSkillAction(aName: String): TBasicLemmingAction;
begin
  Result := SkillPanelButtonToAction[GetSkillButton(aName)];
end;

// Stuff for the old LRB format
type
  TReplayFileHeaderRec = packed record
    Signature         : array[0..2] of Char;     //  3 bytes -  3
    Version           : Byte;                    //  1 byte  -  4
    FileSize          : Integer;                 //  4 bytes -  8
    HeaderSize        : Word;                    //  2 bytes - 10
    Mechanics         : Word;                    //  2 bytes - 12
    FirstRecordPos    : Integer;                 //  4 bytes - 16
    ReplayRecordSize  : Word;                    //  2 bytes - 18
    ReplayRecordCount : Word;                    //  2 bytes - 20

    ReplayGame        : Byte;
    ReplaySec         : Byte;
    ReplayLev         : Byte;
    ReplayOpt         : Byte;

    ReplayTime        : LongWord;
    ReplaySaved       : Word;

    ReplayLevelID    : LongWord;

    Reserved        : array[0..29] of Char;
  end;

  TReplayRec = packed record
    Check          : Char;         //  1 byte  -  1
    Iteration      : Integer;      //  4 bytes -  5
    ActionFlags    : Word;         //  2 bytes -  7
    AssignedSkill  : Byte;         //  1 byte  -  8
    SelectedButton : Byte;         //  1 byte  -  9
    ReleaseRate    : Integer;      //  4 bytes  - 13
    LemmingIndex   : Integer;      //  4 bytes - 17
    LemmingX       : Integer;      //  4 bytes - 21
    LemmingY       : Integer;      //  4 bytes - 25
    CursorX        : SmallInt;     //  2 bytes - 27
    CursorY        : SmallInt;     //  2 bytes - 29
    SelectDir      : ShortInt;
    Reserved2      : Byte;
    Reserved3      : Byte;         // 32
  end;

const
  //Recorded Action Flags
	raf_StartIncreaseRR   = $0008;
	raf_StartDecreaseRR   = $0010;
	raf_StopChangingRR    = $0020;
	raf_SkillSelection    = $0040;
	raf_SkillAssignment   = $0080;
	raf_Nuke              = $0100;

  BUTTON_TABLE: array[0..20] of TSkillPanelButton =
                 (spbNone, spbNone, spbNone,
                  spbClimber,
                  spbUmbrella,
                  spbExplode,
                  spbBlocker,
                  spbBuilder,
                  spbBasher,
                  spbMiner,
                  spbDigger,
                  spbNone, spbNone,
                  spbWalker,
                  spbSwimmer,
                  spbGlider,
                  spbMechanic,
                  spbStoner,
                  spbPlatformer,
                  spbStacker,
                  spbCloner);

{ TReplay }

constructor TReplay.Create;
begin
  inherited;
  fAssignments := TReplayItemList.Create;
  fReleaseRateChanges := TReplayItemList.Create;
  fInterfaceActions := TReplayItemList.Create;
  Clear(true);
end;

destructor TReplay.Destroy;
begin
  fAssignments.Free;
  fReleaseRateChanges.Free;
  fInterfaceActions.Free;
  inherited;
end;

procedure TReplay.Add(aItem: TBaseReplayItem);
var
  Dst: TReplayItemList;
  i: Integer;
begin
  Dst := nil;

  if aItem is TReplaySkillAssignment then Dst := fAssignments;
  if aItem is TReplayChangeReleaseRate then Dst := fReleaseRateChanges;
  if aItem is TReplayNuke then Dst := fAssignments;
  //if aItem is TReplayHighlightLemming then Dst := fInterfaceActions;
  //if aItem is TReplaySelectSkill then Dst := fInterfaceActions;

  if Dst = nil then
    raise Exception.Create('Unknown type passed to TReplay.Add!');

  for i := Dst.Count-1 downto 0 do
    if (Dst[i].Frame = aItem.Frame) and (Dst[i].ClassName = aItem.ClassName) then
      Dst.Delete(i);
  Dst.Add(aItem);
end;

procedure TReplay.Clear(EraseLevelInfo: Boolean = false);
begin
  fAssignments.Clear;
  fReleaseRateChanges.Clear;
  fInterfaceActions.Clear;
  if not EraseLevelInfo then Exit;
  fPlayerName := '';
  fLevelName := '';
  fLevelAuthor := '';
  fLevelGame := '';
  fLevelRank := '';
  fLevelPosition := 0;
  fLevelID := 0;
end;

procedure TReplay.Cut(aLastFrame: Integer);

  procedure DoCut(aList: TReplayItemList);
  var
    i: Integer;
  begin
    for i := aList.Count-1 downto 0 do
      if aList[i].Frame > aLastFrame then aList.Delete(i);
  end;
begin
  DoCut(fAssignments);
  DoCut(fReleaseRateChanges);
  DoCut(fInterfaceActions);
end;

function TReplay.HasAnyActionAt(aFrame: Integer): Boolean;

  function CheckForAction(aList: TReplayItemList): Boolean;
  var
    i: Integer;
  begin
    Result := false;
    for i := 0 to aList.Count-1 do
      if aList[i].Frame = aFrame then
      begin
        Result := true;
        Exit;
      end;
  end;
begin
  Result := CheckForAction(fAssignments)
         or CheckForAction(fReleaseRateChanges)
         or CheckForAction(fInterfaceActions);
end;

function TReplay.GetLastActionFrame: Integer;
// We could assume that the last action in the list is the last one in order,
// but let's not, just in case.
  procedure CheckForAction(aList: TReplayItemList);
  var
    i: Integer;
  begin
    for i := 0 to aList.Count-1 do
      if aList[i].Frame > Result then Result := aList[i].Frame;
  end;
begin
  Result := 0;
  CheckForAction(fAssignments);
  CheckForAction(fReleaseRateChanges);
  CheckForAction(fInterfaceActions);
end;

procedure TReplay.LoadFromFile(aFile: String);
var
  Parser: TNeoLemmixParser;
  Line: TParserLine;
  i: Integer;
  Item: TBaseReplayItem;
begin
  Clear(true);
  Parser := TNeoLemmixParser.Create;
  try
    Parser.LoadFromFile(aFile);
    repeat
      Line := Parser.NextLine;

      if Line.Keyword = 'USER' then
        fPlayerName := Line.Value;

      if Line.Keyword = 'TITLE' then
        fLevelName := Line.Value;

      if Line.Keyword = 'AUTHOR' then
        fLevelAuthor := Line.Value;

      if Line.Keyword = 'GAME' then
        fLevelGame := Line.Value;

      if Line.Keyword = 'RANK' then
        fLevelRank := Line.Value;

      if Line.Keyword = 'LEVEL' then
        fLevelPosition := Line.Numeric;

      if Line.Keyword = 'ID' then
        fLevelID := StrToIntDef('x' + Line.Value, 0);

      if Line.Keyword = 'ACTIONS' then Break;

    until Line.Keyword = '';

    repeat
      Item := nil;
      Line := Parser.NextLine;

      if Line.Keyword = 'ASSIGNMENT' then
        Item := TReplaySkillAssignment.Create;

      if Line.Keyword = 'RELEASE_RATE' then
        Item := TReplayChangeReleaseRate.Create;

      if Line.Keyword = 'NUKE' then
        Item := TReplayNuke.Create;

      if Item <> nil then
      begin
        Item.Load(Parser);
        Add(Item);
      end;
    until Line.Keyword = '';
  finally
    Parser.Free;
  end;
end;

procedure TReplay.SaveToFile(aFile: String);
var
  SL: TStringList;
  E: TBaseReplayItem; //why do I keep naming it E? I don't know. But it's become a thing now.
  i: Integer;
begin
  SL := TStringList.Create;

  SL.Add('# NeoLemmix Replay File');
  SL.Add('# Saved from NeoLemmix V' + PVersion);

  // Debug
  SL.Add('# Assignments: ' + IntToStr(fAssignments.Count));
  SL.Add('# RR Changes: ' + IntToStr(fReleaseRateChanges.Count));

  SL.Add('');
  if Trim(fPlayerName) <> '' then
    SL.Add('USER ' + fPlayerName);
  SL.Add('TITLE ' + fLevelName);
  if Trim(fLevelAuthor) <> '' then
    SL.Add('AUTHOR ' + fLevelAuthor);
  if Trim(fLevelGame) <> '' then
  begin
    SL.Add('GAME ' + fLevelGame);
    SL.Add('RANK ' + fLevelRank);
    SL.Add('LEVEL ' + IntToStr(fLevelPosition));
  end;
  SL.Add('ID ' + IntToHex(fLevelID, 8));
  SL.Add('');
  SL.Add('ACTIONS');
  SL.Add('');

  SaveReplayList(fAssignments, SL);
  SaveReplayList(fReleaseRateChanges, SL);
  SaveReplayList(fInterfaceActions, SL);

  SL.SaveToFile(aFile);

  SL.Free;
end;

procedure TReplay.SaveReplayList(aList: TReplayItemList; SL: TStringList);
var
  i: Integer;
begin
  for i := 0 to aList.Count-1 do
    aList[i].Save(SL);
end;

procedure TReplay.LoadOldReplayFile(aFile: String);
var
  MS: TMemoryStream;
  Header: TReplayFileHeaderRec;
  Item: TReplayRec;
  LastReleaseRate: Integer;
  LastSelectedSkill: TSkillPanelButton;

  procedure CreateAssignEntry;
  var
    E: TReplaySkillAssignment;
  begin
    E := TReplaySkillAssignment.Create;
    E.Skill := TBasicLemmingAction(Item.AssignedSkill);
    E.LemmingIndex := Item.LemmingIndex;
    E.LemmingX := Item.LemmingX;
    E.LemmingDx := Item.SelectDir; // it's the closest we've got
    E.LemmingHighlit := false; // we can't tell for old replays
    E.Frame := Item.Iteration;
    Add(E);
  end;

  procedure CreateNukeEntry;
  var
    E: TReplayNuke;
  begin
    E := TReplayNuke.Create;
    E.Frame := Item.Iteration;
    Add(E);
  end;

  procedure CreateReleaseRateEntry;
  var
    E: TReplayChangeReleaseRate;
  begin
    E := TReplayChangeReleaseRate.Create;
    E.NewReleaseRate := Item.ReleaseRate;
    E.SpawnedLemmingCount := -1; // we don't know
    E.Frame := Item.Iteration;
    Add(E);
  end;

  (*procedure CreateSelectSkillEntry;
  var
    E: TReplaySelectSkill;
  begin
    E := TReplaySelectSkill.Create;
    E.Skill := BUTTON_TABLE[Item.SelectedButton];
    E.Frame := Item.Iteration;
    Add(E);
  end;*)

begin
  Clear(true);
  MS := TMemoryStream.Create;
  try
    MS.LoadFromFile(aFile);
    MS.Position := 0;
    MS.Read(Header, SizeOf(TReplayFileHeaderRec));

    fLevelID := Header.ReplayLevelID;

    MS.Position := Header.FirstRecordPos;
    LastReleaseRate := 0;
    LastSelectedSkill := spbNone;

    while MS.Read(Item, SizeOf(TReplayRec)) = SizeOf(TReplayRec) do
    begin
      if Item.ReleaseRate <> LastReleaseRate then
      begin
        CreateReleaseRateEntry;
        LastReleaseRate := Item.ReleaseRate;
        if Item.ActionFlags and $38 <> 0 then Continue;
      end;

      (*if Item.ActionFlags and raf_SkillSelection <> 0 then
      begin
        CreateSelectSkillEntry;
        LastSelectedSkill := TSkillPanelButton(Item.SelectedButton);
      end;*)

      if Item.ActionFlags and raf_SkillAssignment <> 0 then
        CreateAssignEntry;

      if Item.ActionFlags and raf_Nuke <> 0 then
        CreateNukeEntry;
    end;
  finally
    MS.Free;
  end;

  SaveToFile(ChangeFileExt(aFile, '.nxrp'));
end;

function TReplay.GetItemByFrame(aFrame: Integer; aItemType: Integer): TBaseReplayItem;
var
  i: Integer;
  L: TReplayItemList;
begin
  Result := nil;
  case aItemType of
    1: L := fAssignments;
    2: L := fReleaseRateChanges;
    3: L := fInterfaceActions;
    else Exit;
  end;

  for i := 0 to L.Count-1 do
    if L[i].Frame = aFrame then
    begin
      Result := L[i];
      Exit;
    end;
end;

{ TBaseReplayItem }

procedure TBaseReplayItem.Load(Parser: TNeoLemmixParser);
var
  Line: TParserLine;
begin
  repeat
    Line := Parser.NextLine;
  until not DoLoadLine(Line);
  Parser.Back;
end;

procedure TBaseReplayItem.Save(SL: TStringList);
begin
  DoSave(SL, ''); // It's expected that somewhere throughout the calls to inherited DoSaves, the second parameter will be filled
  SL.Add(''); // But they won't put the blank line, as they're coded such that they don't nessecerially know which is the final one
end;

function TBaseReplayItem.DoLoadLine(Line: TParserLine): Boolean;
begin
  Result := false;

  if Line.Keyword = 'FRAME' then
  begin
    Result := true;
    fFrame := Line.Numeric;
  end;
end;

procedure TBaseReplayItem.DoSave(SL: TStringList; aLabel: String);
begin
  SL.Add(aLabel);
  SL.Add('  FRAME ' + IntToStr(fFrame));
end;

{ TBaseReplayLemmingItem }

procedure TBaseReplayLemmingItem.SetInfoFromLemming(aLemming: TLemming; aHighlit: Boolean);
begin
  fLemmingIndex := aLemming.LemIndex;
  fLemmingX := aLemming.LemX;
  fLemmingDx := aLemming.LemDX;
  fLemmingY := aLemming.LemY;
  fLemmingHighlit := aHighlit;
end;

function TBaseReplayLemmingItem.DoLoadLine(Line: TParserLine): Boolean;
begin
  Result := inherited DoLoadLine(Line);
  if Result then Exit;

  if Line.Keyword = 'LEM_INDEX' then
  begin
    fLemmingIndex := Line.Numeric;
    Result := true;
  end;

  if Line.Keyword = 'LEM_X' then
  begin
    fLemmingX := Line.Numeric;
    Result := true;
  end;

  if Line.Keyword = 'LEM_Y' then
  begin
    fLemmingX := Line.Numeric;
    Result := true;
  end;

  if Line.Keyword = 'LEM_DIR' then
  begin
    if LeftStr(Uppercase(Line.Value), 1) = 'L' then
      fLemmingDx := -1
    else if LeftStr(Uppercase(Line.Value), 1) = 'R' then
      fLemmingDx := 1
    else
      fLemmingDx := 0; // we must be able to store "unknown", eg. for converting old replays
    Result := true;
  end;

  if Line.Keyword = 'HIGHLIT' then
  begin
    fLemmingHighlit := true;
    Result := true;
  end;
end;

procedure TBaseReplayLemmingItem.DoSave(SL: TStringList; aLabel: String);
begin
  inherited;
  SL.Add('  LEM_INDEX ' + IntToStr(fLemmingIndex));
  SL.Add('  LEM_X ' + IntToStr(fLemmingX));
  SL.Add('  LEM_Y ' + IntToStr(fLemmingY));
  if fLemmingDx < 0 then
    SL.Add('  LEM_DIR LEFT')
  else if fLemmingDx > 0 then
    SL.Add('  LEM_DIR RIGHT');
  if fLemmingHighlit then
    SL.Add('  HIGHLIT');
end;

{ TReplaySkillAssignment }

function TReplaySkillAssignment.DoLoadLine(Line: TParserLine): Boolean;
begin
  Result := inherited DoLoadLine(Line);
  if Result then Exit;

  if Line.Keyword = 'ACTION' then
  begin
    Skill := GetSkillAction(Line.Value);
    Result := true;
  end;
end;

procedure TReplaySkillAssignment.DoSave(SL: TStringList; aLabel: String);
begin
  inherited DoSave(SL, 'ASSIGNMENT');
  SL.Add('  ACTION ' + GetSkillReplayName(Skill));
end;

{ TReplayReleaseRateChange }

function TReplayChangeReleaseRate.DoLoadLine(Line: TParserLine): Boolean;
begin
  Result := inherited DoLoadLine(Line);
  if Result then Exit;

  if Line.Keyword = 'RATE' then
  begin
    fNewReleaseRate := Line.Numeric;
    Result := true;
  end;

  if Line.Keyword = 'SPAWNED' then
  begin
    fSpawnedLemmingCount := Line.Numeric;
    Result := true;
  end;
end;

procedure TReplayChangeReleaseRate.DoSave(SL: TStringList; aLabel: String);
begin
  inherited DoSave(SL, 'RELEASE_RATE');
  SL.Add('  RATE ' + IntToStr(fNewReleaseRate));
  SL.Add('  SPAWNED ' + IntToStr(fSpawnedLemmingCount));
end;

{ TReplayNuke }

function TReplayNuke.DoLoadLine(Line: TParserLine): Boolean;
begin
  Result := inherited DoLoadLine(Line);
end;

procedure TReplayNuke.DoSave(SL: TStringList; aLabel: String);
begin
  inherited DoSave(SL, 'NUKE');
end;

{ TReplayItemList }

constructor TReplayItemList.Create;
var
  aOwnsObjects: Boolean;
begin
  aOwnsObjects := true;
  inherited Create(aOwnsObjects);
end;

function TReplayItemList.Add(Item: TBaseReplayItem): Integer;
begin
  Result := inherited Add(Item);
end;

procedure TReplayItemList.Insert(Index: Integer; Item: TBaseReplayItem);
begin
  inherited Insert(Index, Item);
end;

function TReplayItemList.GetItem(Index: Integer): TBaseReplayItem;
begin
  Result := inherited Get(Index);
end;

end.