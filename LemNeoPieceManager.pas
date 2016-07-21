unit LemNeoPieceManager;

// The TNeoPieceManager class is used in a similar manner to how
// graphic sets were in the past. It could be thought of as a huge
// dynamic graphic set.

interface

uses
  Dialogs,
  LemNeoParser, PngInterface, LemNeoTheme,
  LemMetaTerrain, LemMetaObject, LemTypes, GR32, LemStrings,
  StrUtils, Classes, SysUtils;

type

  TLabelRecord = record
    GS: String;
    Piece: String;
  end;

  TNeoPieceManager = class
    private
      fTheme: TNeoTheme;
      fTerrains: TMetaTerrains;
      fObjects: TMetaObjects;
      //fTerrainImages: TBitmaps;
      fObjectImages: TBitmapses;

      function GetTerrainCount: Integer;
      function GetObjectCount: Integer;

      function FindTerrainIndexByIdentifier(Identifier: String): Integer;
      function FindObjectIndexByIdentifier(Identifier: String): Integer;
      function ObtainTerrain(Identifier: String): Integer;
      function ObtainObject(Identifier: String): Integer;

      //function GetTerrain(Identifier: String): TMetaTerrain;
      //function GetObject(Identifier: String): TMetaObject;
      function GetMetaTerrain(Identifier: String): TMetaTerrain;
      function GetMetaObject(Identifier: String): TMetaObject;
      //function GetTerrainBitmap(Identifier: String): TBitmap32;
      //function GetObjectBitmaps(Identifier: String): TBitmaps;
      function GetThemeColor(Index: String): TColor32;

      property TerrainCount: Integer read GetTerrainCount;
      property ObjectCount: Integer read GetObjectCount;

      property ThemeColor[Index: String]: TColor32 read GetThemeColor;
    public
      constructor Create;
      destructor Destroy; override;

      procedure Tidy;

      procedure SetTheme(aTheme: TNeoTheme);

      property Terrains[Identifier: String]: TMetaTerrain read GetMetaTerrain;
      property Objects[Identifier: String]: TMetaObject read GetMetaObject;
  end;

  function SplitIdentifier(Identifier: String): TLabelRecord;
  function CombineIdentifier(Identifier: TLabelRecord): String;

implementation

uses
  LemMetaConstruct;

// These two standalone functions are just to help shifting labels around

function SplitIdentifier(Identifier: String): TLabelRecord;
var
  i: Integer;
  FoundDivider: Boolean;
begin
  Result.GS := '';
  Result.Piece := '';
  FoundDivider := false;
  for i := 1 to Length(Identifier) do
    if Identifier[i] = ':' then
      FoundDivider := true
    else if FoundDivider then
      Result.Piece := Result.Piece + Identifier[i]
    else
      Result.GS := Result.GS + Identifier[i];
end;

function CombineIdentifier(Identifier: TLabelRecord): String;
begin
  // This one is much simpler.
  Result := Identifier.GS + ':' + Identifier.Piece;
end;

// Constructor, destructor, usual boring stuff

constructor TNeoPieceManager.Create;
begin
  inherited;
  fTerrains := TMetaTerrains.Create;
  fObjects := TMetaObjects.Create;
  //fTerrainImages := TBitmaps.Create(true);
  fObjectImages := TBitmapses.Create(true);
  fTheme := nil;
end;

destructor TNeoPieceManager.Destroy;
begin
  fTerrains.Free;
  fObjects.Free;
  //fTerrainImages.Free;
  fObjectImages.Free;
  inherited;
end;

// Tidy-up function. Pretty much clears out the lists. Might add
// stuff in the future so it retains frequently-used pieces.
procedure TNeoPieceManager.Tidy;
begin
  fTerrains.Clear;
  fObjects.Clear;
  //fTerrainImages.Clear;
  fObjectImages.Clear;
end;

// Quick shortcuts to get number of pieces currently present

function TNeoPieceManager.GetTerrainCount: Integer;
begin
  Result := fTerrains.Count;
end;

function TNeoPieceManager.GetObjectCount: Integer;
begin
  Result := fObjects.Count;
end;

// Some functions to locate a piece in the internal arrays...

function TNeoPieceManager.FindTerrainIndexByIdentifier(Identifier: String): Integer;
begin
  Identifier := Lowercase(Identifier);
  for Result := 0 to TerrainCount-1 do
    if fTerrains[Result].Identifier = Identifier then Exit;

  // if it's not found
  Result := ObtainTerrain(Identifier);
end;

function TNeoPieceManager.FindObjectIndexByIdentifier(Identifier: String): Integer;
begin
  Identifier := Lowercase(Identifier);
  for Result := 0 to ObjectCount-1 do
    if fObjects[Result].Identifier = Identifier then Exit;

  // if it's not found
  Result := ObtainObject(Identifier);
end;

// ... and to load it if not found.

function TNeoPieceManager.ObtainTerrain(Identifier: String): Integer;
var
  BasePath: String;
  TerrainLabel: TLabelRecord;
  T: TMetaTerrain;
begin
  TerrainLabel := SplitIdentifier(Identifier);

  Result := fTerrains.Count;

  BasePath := AppPath + SFStylesPieces + TerrainLabel.GS + SFPiecesTerrain + TerrainLabel.Piece;

  if FileExists(BasePath + '.png') then  // .nxtp is optional, but .png is not :)
    T := TMetaTerrain.Create
  else if FileExists(BasePath + '.nxcs') then
    T := TMetaConstruct.Create;
  fTerrains.Add(T);
  T.Load(TerrainLabel.GS, TerrainLabel.Piece);
end;

function TNeoPieceManager.ObtainObject(Identifier: String): Integer;
var
  ObjectLabel: TLabelRecord;
  Parser: TNeoLemmixParser;
  Line: TParserLine;
  O: TMetaObject;
  BMP: TBitmap32;
  BMPs: TBitmaps;
  SkipOneRead: Boolean;

  procedure ShiftRect(var aRect: TRect; dX, dY: Integer);
  begin
    aRect.Left := aRect.Left + dX;
    aRect.Right := aRect.Right + dX;
    aRect.Top := aRect.Top + dY;
    aRect.Bottom := aRect.Bottom + dY;
  end;

  procedure MakeStripFromHorizontal(aFrames: Integer);
  var
    TempBmp: TBitmap32;
    SrcRect, DstRect: TRect;
    i: Integer;
  begin
    TempBmp := TBitmap32.Create;
    TempBmp.Assign(BMP);
    BMP.SetSize(BMP.Width div aFrames, BMP.Height * aFrames);
    BMP.Clear($00000000);
    SrcRect := Rect(0, 0, BMP.Width, TempBmp.Height);
    DstRect := SrcRect;

    for i := 0 to aFrames do
    begin
      TempBmp.DrawTo(BMP, DstRect, SrcRect);
      ShiftRect(SrcRect, BMP.Width, 0);
      ShiftRect(DstRect, 0, TempBmp.Height);
    end;
  end;

  procedure LoadApplyMask;
  var
    MaskName, MaskColor: String;
  begin
    MaskName := '';
    MaskColor := '';
    repeat
      Line := Parser.NextLine;

      if Line.Keyword = 'COLOR' then
        MaskColor := Line.Value;

      if Line.Keyword = 'NAME' then
        MaskName := Line.Value;
    until (Line.Keyword <> 'COLOR') and (Line.Keyword <> 'NAME');

    SkipOneRead := true; // because the above has already read it

    if Lowercase(MaskName) = '*self' then
      TPngInterface.MaskImageFromImage(Bmp, Bmp, ThemeColor[MaskColor]) // yes, this works :D
    else
      TPngInterface.MaskImageFromFile(Bmp, ObjectLabel.Piece + '_mask_' + MaskName + '.png', ThemeColor[MaskColor]);
  end;

begin
  (*ObjectLabel := SplitIdentifier(Identifier);
  if not DirectoryExists(AppPath + SFStylesPieces + ObjectLabel.GS) then
    raise Exception.Create('TNeoPieceManager.ObtainTerrain: ' + ObjectLabel.GS + ' does not exist.');
  SetCurrentDir(AppPath + SFStylesPieces + ObjectLabel.GS + SFPiecesObjects);

  Result := fObjects.Count;

  O := fObjects.Add;
  BMP := TBitmap32.Create;

  TPngInterface.LoadPngFile(ObjectLabel.Piece + '.png', BMP);

  O.GS := ObjectLabel.GS;
  O.Piece := ObjectLabel.Piece;

  // We always need the parser for an object.
  Parser := TNeoLemmixParser.Create;
  SkipOneRead := false;
  try
    Parser.LoadFromFile(ObjectLabel.Piece + '.nxob');
    repeat
      if SkipOneRead then
        SkipOneRead := false
      else
        Line := Parser.NextLine;

      // Trigger effects
      if Line.Keyword = 'EXIT' then O.TriggerEffect := 1;
      if Line.Keyword = 'OWL_FIELD' then O.TriggerEffect := 2;
      if Line.Keyword = 'OWR_FIELD' then O.TriggerEffect := 3;
      if Line.Keyword = 'TRAP' then O.TriggerEffect := 4;
      if Line.Keyword = 'WATER' then O.TriggerEffect := 5;
      if Line.Keyword = 'FIRE' then O.TriggerEffect := 6;
      if Line.Keyword = 'OWL_ARROW' then O.TriggerEffect := 7;
      if Line.Keyword = 'OWR_ARROW' then O.TriggerEffect := 8;
      if Line.Keyword = 'TELEPORTER' then O.TriggerEffect := 11;
      if Line.Keyword = 'RECEIVER' then O.TriggerEffect := 12;
      if Line.Keyword = 'LEMMING' then O.TriggerEffect := 13;
      if Line.Keyword = 'PICKUP' then O.TriggerEffect := 14;
      if Line.Keyword = 'LOCKED_EXIT' then O.TriggerEffect := 15;
      if Line.Keyword = 'BUTTON' then O.TriggerEffect := 17;
      if Line.Keyword = 'RADIATION' then O.TriggerEffect := 18;
      if Line.Keyword = 'OWD_ARROW' then O.TriggerEffect := 19;
      if Line.Keyword = 'UPDRAFT' then O.TriggerEffect := 20;
      if Line.Keyword = 'SPLITTER' then O.TriggerEffect := 21;
      if Line.Keyword = 'SLOWFREEZE' then O.TriggerEffect := 22;
      if Line.Keyword = 'WINDOW' then O.TriggerEffect := 23;
      if Line.Keyword = 'ANIMATION' then O.TriggerEffect := 24;
      if Line.Keyword = 'HINT' then O.TriggerEffect := 25;
      if Line.Keyword = 'ANTISPLAT' then O.TriggerEffect := 26;
      if Line.Keyword = 'SPLAT' then O.TriggerEffect := 27;
      if Line.Keyword = 'BACKGROUND' then O.TriggerEffect := 30;
      if Line.Keyword = 'TRAP_ONCE' then O.TriggerEffect := 31;

      if Line.Keyword = 'FRAMES' then
        O.AnimationFrameCount := Line.Numeric;

      if Line.Keyword = 'HORIZONTAL' then
        MakeStripFromHorizontal(O.AnimationFrameCount);

      if Line.Keyword = 'TRIGGER_X' then
        O.TriggerLeft := Line.Numeric;

      if Line.Keyword = 'TRIGGER_Y' then
        O.TriggerTop := Line.Numeric;

      if Line.Keyword = 'TRIGGER_W' then
        O.TriggerWidth := Line.Numeric;

      if Line.Keyword = 'TRIGGER_H' then
        O.TriggerHeight := Line.Numeric;

      if Line.Keyword = 'SOUND' then
        O.SoundEffect := Line.Numeric;

      if Line.Keyword = 'PREVIEW' then
        O.PreviewFrameIndex := Line.Numeric;

      if Line.Keyword = 'KEYFRAME' then
        O.TriggerNext := Line.Numeric;

      if Line.Keyword = 'RANDOM_FRAME' then
        O.RandomStartFrame := true;

      if Line.Keyword = 'RESIZE' then
      begin
        if Lowercase(LeftStr(Line.Value, 3)) = 'hor' then  // kludgy, but allows both "horz" and "horizontal" and similar variations
          O.Resizability := mos_Horizontal;
        if Lowercase(LeftStr(Line.Value, 4)) = 'vert' then
          O.Resizability := mos_Vertical;
        if Lowercase(Line.Value) = 'both' then
          O.Resizability := mos_Both;
        if Lowercase(Line.Value) = 'none' then
          O.Resizability := mos_None;
      end;

      if Line.Keyword = 'MASK' then
        LoadApplyMask;

    until Line.Keyword = '';
  finally
    Parser.Free;
  end;

  O.Width := BMP.Width;
  O.Height := BMP.Height div O.AnimationFrameCount;

  with fObjectImages.Add do
    Generate(BMP, O.AnimationFrameCount);

  BMP.Free;*)
end;

// Functions to get the metainfo

function TNeoPieceManager.GetMetaTerrain(Identifier: String): TMetaTerrain;
var
  i: Integer;
begin
  i := FindTerrainIndexByIdentifier(Identifier);
  Result := fTerrains[i];
end;

function TNeoPieceManager.GetMetaObject(Identifier: String): TMetaObject;
var
  i: Integer;
begin
  i := FindObjectIndexByIdentifier(Identifier);
  Result := fObjects[i];
end;

// And the stuff for communicating with the theme

procedure TNeoPieceManager.SetTheme(aTheme: TNeoTheme);
begin
  fTheme := aTheme;
  Tidy;
end;

function TNeoPieceManager.GetThemeColor(Index: String): TColor32;
begin
  if fTheme = nil then
  begin
    Result := DEFAULT_COLOR;
    if Uppercase(Index) = 'BACKGROUND' then
      Result := $FF000000;
  end else
    Result := fTheme.Colors[Index];
end;

end.