{$include lem_directives.inc}

// code onder end bevat ook nog oude code om te saven!!!!!!!!!!!!!
// en nog wat zooi. voorzichtig weggooien.

unit LemDosBmp;

interface

uses
  Dialogs,
  Classes, Types, SysUtils, Contnrs, Math,
  UMisc,
  GR32, GR32_OrdinalMaps,
  LemStrings,
  LemTypes,
  LemDosStructures,
  LemDosCmp;

type
  TColor32Array8  = array[0..7] of TColor32;
  TColor32Array16 = array[0..15] of TColor32;
//  TPlaneFilter    = set of 0..7;

  {-------------------------------------------------------------------------------
    planar bitmaps in the dosfiles are stored per plane, not interlaced
  -------------------------------------------------------------------------------}
  TDosPlanarBitmap = class
  private
    //fDirectRGB: Boolean;
  protected
  public

  { load new }
    procedure GetByteMap(S: TStream; aByteMap: TByteMap; aPos, aWidth, aHeight: Integer; BPP: Byte);

    procedure LoadFromFile(const aFilename: string; aBitmap: TBitmap32;
      aPos, aWidth, aHeight: Integer; BPP: Byte; const aPalette: TArrayOfColor32); overload;

    procedure LoadFromStream(S: TStream; aBitmap: TBitmap32; aPos, aWidth, aHeight: Integer;
      BPP: Byte; const aPalette: TArrayOfColor32); overload;

    procedure LoadAnimationFromStream(S: TStream; aBitmap: TBitmap32; aPos, aWidth, aHeight, aFrameCount: Integer;
      BPP: Byte; const aPalette: TArrayOfColor32);


  published
  end;

  {-------------------------------------------------------------------------------
    class to extract the "special" bitmaps from dos-files.
    can also create vgaspec-files
  -------------------------------------------------------------------------------}
  TVgaSpecBitmap = class
  private
  { reading methods}
    procedure GetSectionsAndPalette(Src, Dst: TStream; var Pal: TDosVGAPalette8; var PalInfo: TDosVgaSpecPaletteHeader);
  public
  { reading methods }
    function DecodeSection(var Src, Dst: PBytes; SrcSize: Integer): Integer;
    procedure LoadFromFile(const aFileName: string; aBitmaps: TBitmaps);
    procedure LoadFromStream(S: TStream; aBitmaps: TBitmaps);
    procedure LoadPaletteFromFile(const aFileName: string; var Pal: TDosVGAPalette8);
    procedure LoadPaletteFromStream(S: TStream; var Pal: TDosVGAPalette8);
  end;


function DosPaletteEntryToColor32(Red, Green, Blue: Byte): TColor32; overload;
function DosPaletteEntryToColor32(const Entry: TDOSVGAColorRec): TColor32; overload;
function DosPaletteToArrayOfColor32(const Pal: TDosVGAPalette8): TArrayOfColor32;
function Color32ToDosPaletteEntry(C: TColor32): TDOSVGAColorRec;

const
  VGASPEC_SECTIONSIZE = 14400;
  VGASPEC_SECTIONSIZE_EXT = 86400;

implementation

uses
  LemNeoGraphicSet;


function DosPaletteEntryToColor32(Red, Green, Blue: Byte): TColor32;
begin
  with TColor32Entry(Result) do
  begin
    A := $FF;
    R := Red shl 2;
    G := Green shl 2;
    B := Blue shl 2;
    // handle transparancy
    if (R = 0) and (G = 0) and (B = 0) then
      A := 0
    else
      A := $FF;


(*
    for i := 0 to 7 do
    begin
      E := @LemmixPal[i];
      D := @DosPal[i];
      with TColor32Entry(LemmixPal[i]) do
      begin
        E^.A := 0;
        E^.R := (Integer(D^.R) * 255) div 63;
        E^.G := (Integer(D^.G) * 255) div 63;
        E^.B := (Integer(D^.B) * 255) div 63;
      end;
    end;
*)



  end;
end;

function DosPaletteEntryToColor32(const Entry: TDOSVGAColorRec): TColor32;
begin
  with Entry do
    Result := DosPaletteEntryToColor32(R, G, B);
end;

function Color32ToDosPaletteEntry(C: TColor32): TDOSVGAColorRec;
begin
  with Result do
  begin
    R := TColor32Entry(C).R shr 2;
    G := TColor32Entry(C).G shr 2;
    B := TColor32Entry(C).B shr 2;
  end;
end;

function DosPaletteToArrayOfColor32(const Pal: TDosVGAPalette8): TArrayOfColor32;
var
  i: Integer;
begin
  SetLength(Result, Length(Pal));
  for i := 0 to Length(Pal) - 1 do
  begin
    Result[i] := DosPaletteEntryToColor32(Pal[i]);
  end;
end;

{ TDosPlanarBitmap }

procedure TDosPlanarBitmap.LoadFromFile(const aFilename: string;
  aBitmap: TBitmap32; aPos, aWidth, aHeight: Integer; BPP: Byte;
  const aPalette: TArrayOfColor32);
var
  F: TFileStream;
begin
  F := TFileStream.Create(aFileName, fmOpenRead);
  try
    LoadFromStream(F, aBitmap, aPos, aWidth, aHeight, BPP, aPalette);
  finally
    F.Free;
  end;
end;

const
  ALPHA_TRANSPARENTBLACK = $80000000;

procedure TDosPlanarBitmap.LoadFromStream(S: TStream; aBitmap: TBitmap32;
  aPos, aWidth, aHeight: Integer; BPP: Byte;
  const aPalette: TArrayOfColor32);
{-------------------------------------------------------------------------------
  load bytemap and convert it to bitmap, using the palette parameter
-------------------------------------------------------------------------------}
var
  ByteMap: TByteMap;
  x, y: Integer;
  C: PColor32;
  B: Types.PByte;
  PalLen: Integer;

    procedure PreparePal;
    var
      i: Integer;
    begin
      for i := 1 to PalLen - 1 do
        if aPalette[i] = 0 then
          aPalette[i] := aPalette[i] or ALPHA_TRANSPARENTBLACK;
    end;

begin

  PalLen := Length(aPalette);
  PreparePal;
//  Assert(PalLen >= BPP div 8)

  ByteMap := TByteMap.Create;
  try
    GetByteMap(S, ByteMap, aPos, aWidth, aHeight, BPP);
    aBitmap.SetSize(aWidth, aHeight);
    aBitmap.Clear(0);
    C := aBitMap.PixelPtr[0, 0];
    B := ByteMap.ValPtr[0, 0];
    for y := 0 to aHeight - 1 do
      for x := 0 to aWidth - 1 do
      begin
        if not (BPP in [18, 19]) then Assert(B^ < PalLen, 'error color ' + i2s(B^) + ',' + i2s(PalLen));
        (*
        if B^ >= PalLen then
        begin
          C^ := aPalette[B^ - 8];
          //C^ := clYellow32
          windlg(['this is not good yet', x , y, B^, pallen]);
        end
        else *)
        if BPP in [18, 19] then
        begin
          C^ := B^ shl 18;
          Inc(B);
          C^ := C^ + (B^ shl 10);
          Inc(B);
          C^ := C^ + (B^ shl 2);
          Inc(B);
          if BPP = 18 then
          begin
            if C^ <> 0 then C^ := C^ or $FF000000;
          end else begin
            if (B^ and $1 <> 0) then
              C^ := C^ or $FF000000
              else
              C^ := 0;
          end;
        end else
          C^ := aPalette[B^];
        Inc(C); // typed pointer increment
        Inc(B); // typed pointer increment
      end;

  finally
    ByteMap.Free;
  end;
end;


procedure TDosPlanarBitmap.GetByteMap(S: TStream; aByteMap: TByteMap;
  aPos, aWidth, aHeight: Integer; BPP: Byte);
{-------------------------------------------------------------------------------
  This should be the key routine: it converts a planar stored bitmap to
  a simple two-dimensional palette entry array.
  We use the Graphics32 TByteMap for that.
-------------------------------------------------------------------------------}
var
  NumBytes : Integer;
  Buf: PBytes;
  PlaneSize: Integer;
  LineSize: Integer;

    // local function
    function GetPix(X, Y: Integer): LongWord;
    var
      BytePtr: PByte;
      //B: Byte;
      i, P: Integer;
      BitNumber, Mask: Byte;
    begin
      Result := 0;
      // adres of pixel in the first plane
      P := Y * LineSize + X div 8;
      // get the right bit (Wow, totally excellent, its backwards !)
      BitNumber := 7 - X mod 8; // downwards!
      Mask := 1 shl BitNumber;
      // get the seperated bits from the planes
      BytePtr := @Buf^[P];
      for i := 0 to BPP - 1 do
      begin
        if BytePtr^ and Mask <> 0 then
          Result := Result or (1 shl i);
        Inc(BytePtr, PlaneSize);
      end;
    end;

var
  x, y: Integer;
  Entry: LongWord;
begin
  Assert(BPP in [1..8, 18, 19], 'bpp error');

  LineSize := aWidth div 8; // Every bit is a pixel (in each plane)
  PlaneSize := LineSize * aHeight; // Now we know the planesize
  NumBytes := PlaneSize * BPP; // and the total bytes

  GetMem(Buf, NumBytes);
  if aPos >= 0 then
    S.Seek(aPos, soFromBeginning);
  S.ReadBuffer(Buf^, NumBytes);
  if BPP in [18, 19] then
    aByteMap.SetSize(aWidth * 4, aHeight)
    else
    aByteMap.SetSize(aWidth, aHeight);
  aByteMap.Clear(0);

  for y := 0 to aHeight-1 do
  begin
    for x := 0 to aWidth - 1 do
    begin
      Entry := GetPix(x, y);
      if BPP in [18, 19] then
      begin
        aByteMap[(x*4), y] := Entry shr 12;
        aByteMap[(x*4)+1, y] := (Entry shr 6) mod $40;
        aByteMap[(x*4)+2, y] := Entry mod $40;
        if BPP = 18 then
        begin
          if (Entry and $FFFFFF) = 0 then
            aByteMap[(x*4)+3, y] := 0
            else
            aByteMap[(x*4)+3, y] := 1;
        end else
          aByteMap[(x*4)+3, y] := (Entry shr 18) mod 2;
      end else
        aByteMap[x, y] := Entry;
    end;
  end;

  FreeMem(Buf);
end;


procedure TDosPlanarBitmap.LoadAnimationFromStream(S: TStream;
  aBitmap: TBitmap32; aPos, aWidth, aHeight, aFrameCount: Integer;
  BPP: Byte; const aPalette: TArrayOfColor32);
{-------------------------------------------------------------------------------
  We assume that
  o frames are in the stream in a row
  o same size
  o same palette
  o same BPP
-------------------------------------------------------------------------------}

var
  FrameBitmap: TBitmap32;
  i: Integer;
begin
  // set initial position, the rest is read automatically
  if aPos >= 0 then
    S.Seek(aPos, soFromBeginning);

  FrameBitmap := TBitmap32.Create;
  try

    aBitmap.SetSize(aWidth, aHeight * aFrameCount);
    aBitmap.Clear(0);

    for i := 0 to aFrameCount - 1 do
    begin
      LoadFromStream(S, FrameBitmap, -1, aWidth, aHeight, BPP, aPalette);
      FrameBitmap.DrawTo(aBitmap, 0, aHeight * i);
    end;

  finally
    FrameBitmap.Free;
  end;

end;

{ TVgaSpecBitmap }


procedure TVgaSpecBitmap.GetSectionsAndPalette(Src, Dst: TStream; var Pal: TDosVGAPalette8; var PalInfo: TDosVgaSpecPaletteHeader);
var
  CurByte: Byte;
  {i, }{CSize, }Cnt, Rd, {Wr, }CurSection: Integer;
  Value: Byte;

  Buf: PBytes;
  normsize: Boolean;
begin
  Buf := nil;
  Src.Seek(0, soFromBeginning);
  Dst.Seek(0, soFromBeginning);
  //CSize := Src.Size;
  Src.Read(PalInfo, Sizeof(PalInfo));
  Pal := PalInfo.VgaPal;
  normsize := PalInfo.EgaPal[1] <> 255;
  CurSection := 0;

  try
    repeat
      Rd := Src.Read(CurByte, 1);
      if Rd <> 1 then
        Break;
      case CurByte of
        // end section
        128:
          begin
            if ((Dst.Position mod VGASPEC_SECTIONSIZE <> 0) and (Dst.Position mod VGASPEC_SECTIONSIZE_EXT <> 0)) and normsize then
              raise Exception.Create('vga spec section size error');
            //deb(['currsection', cursection, src.position]);
            Inc(CurSection);
            if (CurSection > 3) or not normsize then
              Break;
          end;
        // raw bytes
        0..127:
          begin
            Cnt := CurByte + 1;
            Dst.CopyFrom(Src, Cnt);
          end;
        // repeated bytes
        129..255:
          begin
            Cnt := 257 - CurByte;
            ReallocMem(Buf, Cnt); // we could use just a 256 byte buffer or so, no realloc needed
            Src.Read(Value, 1);
            FillChar(Buf^, Cnt, Value);
            Dst.Write(Buf^, Cnt);
          end;
      end; //case
    until False;

  finally
    FreeMem(Buf);
  end;

{  dst.seek(0,sofrombeginning);
  with tfilestream.create('d:\allsecs.tmp', fmcreate) do
  begin
    copyfrom(dst, 0);
    free;
  end; }

end;


function TVgaSpecBitmap.DecodeSection(var Src, Dst: PBytes; SrcSize: Integer): Integer;
var
  CodeByte, Value: Byte;
  i, si, di, Cnt, Allocated: Integer;

    procedure EnsureMem(aSize: Integer; Exact: Boolean = False);
    begin
      case Exact of
        False:
          if aSize > Allocated then
          begin
            ReallocMem(Dst, aSize);
            Allocated := aSize;
          end;
        True:
          if aSize <> Allocated then
          begin
            ReallocMem(Dst, aSize);
            Allocated := aSize;
          end;
      end;
    end;

begin
  Result := 0;
  si := 0;
  di := 0;
  Allocated := 0;
  EnsureMem(SrcSize, True);
  FillChar(Dst^, Allocated, 0);
  while si <= SrcSize - 1 do
  begin
    CodeByte := Src^[si];
    case CodeByte of
      // end section
      128:
        begin
          Exit;
        end;
      // raw bytes
      0..127:
        begin
          Cnt := CodeByte + 1;
          Inc(si);
          EnsureMem(di + Cnt);
          Move(Src^[si], Dst^[di], Cnt);
          Inc(si, Cnt);
          Inc(di, Cnt);
        end;
      // repeated bytes
      129..255:
        begin
          Cnt := 257 - CodeByte;
          Inc(si);
          EnsureMem(di + Cnt);
          Value := Src^[si];
          for i := 0 to Cnt - 1 do
            Dst^[di + i] := Value;
          Inc(di, Cnt);
          Inc(si);
        end;
    end; //case

  end;

  EnsureMem(di, True);
  Result := di;
end;


procedure TVgaSpecBitmap.LoadFromFile(const aFileName: string; aBitmaps: TBitmaps);
{-------------------------------------------------------------------------------
  method to load a bitmap from the vgaspec?.dat files
-------------------------------------------------------------------------------}
var
  F: TFileStream;
begin
  if aBitmaps = nil then
    Exit;
  F := TFileStream.Create(aFileName, fmOpenRead);
  try
    LoadFromStream(F, aBitmaps);
  finally
    F.Free;
  end;
end;

procedure TVgaSpecBitmap.LoadFromStream(S: TStream; aBitmaps: TBitmaps);
{-------------------------------------------------------------------------------
  So here we are at the decoding of vgaspec?.dat:
  o Step 1: Decompress with the "default" dos lemming decompression code
  o Step 2: Get the vga-palette from the first few bytes
  o Step 3: Decode 4 sections with the "bitmap" decompression code
  o Step 4: Now in each of the 4 sections, which should be 14400 bytes, extract
            a planar bitmap (3 BPP, 960x40)
  o Step 5: Create one big bitmap of this 4 planar bitmaps
-------------------------------------------------------------------------------}
var
  Decompressor: TDosDatDecompressor;
  Mem, PMem: TMemoryStream;
//  Header: TCompressionHeaderRec;
//  InSize, OutSize: Integer;
//  InBuf, OutBuf: PBytes;
//  CheckSum: Integer;
  Planar: TDosPlanarBitmap;
  TempBitmap, TempBitmap2: TBitmap32;
  Sec: Integer;
  DosPal: TDosVGAPalette8;
  Pal: TArrayOfColor32;
  PalInfo: TDosVgaSpecPaletteHeader;
  normsize: Boolean;
  NeoGS: TBaseNeoGraphicSet;


    procedure LogPal;
    var
      i: Integer;
    begin
      deb(['spec pal']);
      for i := 0 to 7 do
      with TColor32Entry(pal[i]) do
      begin
        deb(['RGB (' + i2s(i) + ')' + i2s(r) + ',' + i2s(g) +',' + i2s(b)])
      end;
    end;



begin
  Assert(aBitmaps <> nil);

  //Mem := nil;
  //Decompressor := nil;

  Decompressor := TDosDatDecompressor.Create;
  Mem := TMemoryStream.Create;
  try

    { step 1: decompress }
    try
      Decompressor.DecompressSection(S, Mem);
    finally
      Decompressor.Free;
    end;

    if S.Position <> S.Size then // definite marker of a new-format graphic set
    begin
      NeoGS := TBaseNeoGraphicSet.Create;
      NeoGS.GraphicSetFile := '*'; //give it any value, so it doesn't try to default to old-format
      NeoGS.LoadFromStream(S);
      NeoGS.ReadMetaData;
      NeoGS.ReadData;

      TempBitmap := TBitmap32.Create;
      TempBitmap.Assign(NeoGS.TerrainBitmaps[0]);
      aBitmaps.Add(TempBitmap);

      TempBitmap := TBitmap32.Create;
      if NeoGS.TerrainBitmaps.Count > 1 then
        TempBitmap.Assign(NeoGS.TerrainBitmaps[1])
      else begin
        TempBitmap.SetSize(aBitmaps[0].Width, aBitmaps[0].Height);
        TempBitmap.Clear(0);
      end;
      aBitmaps.Add(TempBitmap);

      TempBitmap := TBitmap32.Create;
      if NeoGS.TerrainBitmaps.Count > 2 then
        TempBitmap.Assign(NeoGS.TerrainBitmaps[2])
      else
        TempBitmap.Assign(aBitmaps[0]);
      aBitmaps.Add(TempBitmap);

      NeoGS.Free;
    end else begin

    PMem := TMemoryStream.Create;
    TempBitmap := TBitmap32.Create;
    try
      { step 2 + 3 : getpalette, extract 4 sections }
      GetSectionsAndPalette(Mem, PMem, DosPal, PalInfo);
      Pal := DosPaletteToArrayOfColor32(DosPal);

      normsize := PalInfo.EgaPal[1] <> 255;

      logpal;

      Planar := TDosPlanarBitmap.Create;
      try
      if normsize then
      begin
        TempBitmap2 := TBitmap32.Create;
        TempBitmap2.SetSize(960, 160);
        TempBitmap2.Clear(0); // clear with #transparent black
        for Sec := 0 to 3 do
        begin
          { step 4: read planar bitmap part from section }
          TempBitmap.Clear(0); // clear with #transparent black
          //Planar.LoadFromStream(PMem, TempBitmap, Sec * VGASPEC_SECTIONSIZE, 960, 40, 3, Pal, Pal);
          if DosPal[1].R = 255 then
            Planar.LoadFromStream(PMem, TempBitmap, Sec * VGASPEC_SECTIONSIZE_EXT, 960, 40, 18, Pal)
            else
            Planar.LoadFromStream(PMem, TempBitmap, Sec * VGASPEC_SECTIONSIZE, 960, 40, 3, Pal);
          { step 5: draw to bitmap }
          TempBitmap2.Draw(0, Sec * 40, TempBitmap);
        end;
      end else begin
        TempBitmap2 := TBitmap32.Create;
        TempBitmap2.SetSize((PalInfo.UnknownPal[0] * 256) + PalInfo.UnknownPal[1], (PalInfo.UnknownPal[2] * 256) + PalInfo.UnknownPal[3]);
        TempBitmap2.Clear(0);
        if DosPal[1].R = 255 then
            Planar.LoadFromStream(PMem, TempBitmap2, 0, TempBitmap2.Width, TempBitmap2.Height, 18, Pal)
            else
            Planar.LoadFromStream(PMem, TempBitmap2, 0, TempBitmap2.Width, TempBitmap2.Height, 3, Pal);
      end;
      aBitmaps.Add(TempBitmap2);
      TempBitmap2 := TBitmap32.Create;
      TempBitmap2.SetSize(aBitmaps[0].Width, aBitmaps[0].Height);
      aBitmaps.Add(TempBitmap2);
      TempBitmap2 := TBitmap32.Create;
      TempBitmap2.SetSize(aBitmaps[0].Width, aBitmaps[0].Height);
      aBitmaps.Add(TempBitmap2);
      finally
        Planar.Free;
      end;
    finally
      PMem.Free;
      TempBitmap.Free;
    end;
    end;

   finally
     Mem.Free;
   end;
end;

procedure TVgaSpecBitmap.LoadPaletteFromFile(const aFileName: string; var Pal: TDosVGAPalette8);
var
  F: TFileStream;
begin
  F := TFileStream.Create(aFileName, fmOpenRead);
  try
    LoadPaletteFromStream(F, Pal);
  finally
    F.Free;
  end;
end;

procedure TVgaSpecBitmap.LoadPaletteFromStream(S: TStream; var Pal: TDosVGAPalette8);
var
  Decompressor: TDosDatDecompressor;
  Mem: TMemoryStream;
  t: TDosVgaColorRec;
//  Planar: TDosPlanarBitmap;
begin
//  Mem := nil;
//  Decompressor := nil;

  Decompressor := TDosDatDecompressor.Create;
  Mem := TMemoryStream.Create;
  try

    try
      Decompressor.DecompressSection(S, Mem);
    finally
      Decompressor.Free;
    end;

    if S.Position = S.Size then
    begin
      t := Pal[0];

      Mem.Seek(0, soFromBeginning);
      Mem.Read(Pal, Sizeof(Pal)); // first section, first bytes = vgapalette

      Pal[0] := t;
    end;

   finally
     Mem.Free;
   end;
end;

end.
