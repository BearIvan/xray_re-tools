{-----------------------------------------------------------------------------
 Unit Name: SAFileSystem
 Author:    Neo][
 Date:      24-���-2009
 Purpose:   ���������� ����������� �������� �������, ��������� ���������
 ������ ��� ������ � �������� ��������.
 History:
 ToDo:      -- ����������� � ���������������� ��������
-----------------------------------------------------------------------------}

unit SAFileSystem;

interface

uses
  Generics.Collections, SysUtils, SAScrambler;

const
  //// ��������� ������� �����.

  PA_APP_DIR = '$app_dir$';             /// ����� ���������� ����������

  CHUNK_COMPRESSED = $80000000;
  CHUNK_ID_MASK = not CHUNK_COMPRESSED;

type

  {*------------------------------------------------------------------------------
    ������� ����� ��� ���������� �������� �������.
  -------------------------------------------------------------------------------}
  ESAFileSystem = class(Exception);

  {*------------------------------------------------------------------------------
    ����� ����������, ������������� ��� ������� �������� ����� ������������
    �����.
  -------------------------------------------------------------------------------}
  ESAFSSpecFile = class(ESAFileSystem);

  {*------------------------------------------------------------------------------
    ��������� ������ ����.
  -------------------------------------------------------------------------------}
  TSAPathAlias = record
    Name,                               /// ��� ������
    Root,                               /// ���� ������
    Caption: string;                    /// ��������(�� �����������)
  end;

  {*------------------------------------------------------------------------------
    ������� ����� ��������������� � ���� ������� ������ �����.
  -------------------------------------------------------------------------------}
  TSAReader = class
  private
    { setters/ getters }
    function GetSize: Cardinal;
    function GetData: Pointer;
    function GetEOF: Boolean;
  protected
    FData: PByte;                       /// ��������� �� ������ ������
    FNext: PByte;                       /// ???
    FEnd: PByte;                        /// ��������� �� ����� ������
    FCaret: record                      /// ��������� �� ������� �������
      case Integer of
        0: (chr: PAnsiChar);
        1: (u8: PByte);
        2: (s8: PShortInt);
        3: (u16: PWord);
        4: (s16: PSmallInt);
        5: (u32: PLongWord);
        6: (s32: PLongint);
        7: (f: PSingle);
    end;

  public
    (* constructors/destructors *)
    constructor Create; overload;
    constructor Create(aData: Pointer; aSize: Cardinal); overload;
    destructor Destroy; override;

    { chunks operations }
    function FindChunk(aID: Cardinal; var aCompressed: Boolean; aReset: Boolean = True): Cardinal; overload;
    function FindChunk(aID: Cardinal): Cardinal; overload;

    function OpenChunk(aID: Cardinal): TSAReader; overload;
    function OpenChunk(aID: Cardinal; const aScrambler: TSAScrambler): TSAReader; overload;
    procedure CloseChunk(var aReader: TSAReader);

    { reading }
    procedure r_raw(aDestination: Pointer; aDestSize: Cardinal);
    procedure r_sz(var aDest: string);
    function r_u32: LongWord;
    function r_s32: LongInt;
    function r_u24: Cardinal;
    function r_u16: Word;
    function r_s16: SmallInt;
    function r_u8: Byte;
    function r_s8: ShortInt;
    function r_bool: Boolean;

    { properties }
    property Size: Cardinal read GetSize;
    property Data: Pointer read GetData;
    property EOF: Boolean read GetEOF;
  end;

  {*------------------------------------------------------------------------------
    ����� ������, ������� ��� ���������� ����������� �������.
  -------------------------------------------------------------------------------}
  TSATempReader = class(TSAReader)
  public
    destructor Destroy; override;
  end;

  {*------------------------------------------------------------------------------
    ����� ����������� ������ �� ���� ��������.
  -------------------------------------------------------------------------------}
  TSAMMapReader = class(TSAReader)
  private
    FHFile,                             /// ����� ������������ �����
    FHMMap: Cardinal;                   /// ����� memory mapping-a
  public
    //## constructors/destructors
    constructor Create; overload;
    constructor Create(aHFile, aHMMap: Cardinal; aData: Pointer; aSize: Cardinal); overload;
    destructor Destroy; override;

  end;

  {-------------------------------------------------------------------------------
   ����� ����������� �������� �������, ������������� � ���� ��������� ������ ���
   ������ � �������� ��������.
   @Note ����� �������� ���������� ������, ��� ���������� �������������������
   ������� ������ Init. � �������� ��������� �������� ��������� ��� �����
   ������������ �����. ���� ������������ ����� �������� ����������� ������� �����.

   ������ ������ ���������:

   $�������������$ | root_path | add_path | caption
   -------------------------------------------------------------------------------}
  TSAFileSystem = class
  private
    FPathAliases: TList < TSAPathAlias > ; /// ������ ������� �����

    //## path aliases
    function AddPathAlias(const aName, aRoot, aAdd: string): Integer;
    function FindPathAlias(const aName: string): Integer;
    procedure ParseFSSpec(const aReader: TSAReader);
  public
    //## constructors/destructors
    constructor Create;
    destructor Destroy; override;

    //## path aliases
    function Init(const aFSSpecFileName: string): Boolean;

    //## read
    function ReadOpen(const aFileName: string): TSAReader;
    procedure ReadClose(var aReader: TSAReader);
  end;

resourcestring
  StrFSSpecFileParsingErr = 'Can''t parse FS specification file, line: %d';

implementation

uses
  Windows, Character, SAStringUtils, Classes, LZH;

function GetFileSizeEx(hFile: Cardinal; out lpFileSize: LARGE_INTEGER): BOOL; stdcall; external 'kernel32.dll';
//procedure lzh_decompress(Code: PByte; var CodeSize: Cardinal; const Text: PByte; TextSize: Cardinal); cdecl; external 'xrFSL_Core.dll';

{============================================}
{============= TSAFileSystem ================}
{============================================}

{*------------------------------------------------------------------------------
  ����������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TSAFileSystem.Create;
begin
  FPathAliases := TList < TSAPathAlias > .Create;
end;

{*------------------------------------------------------------------------------
  ���������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TSAFileSystem.Destroy;
begin
  FPathAliases.Free;

  inherited;
end;

{*------------------------------------------------------------------------------
  ���������� ������ ������.
  @param aName ������������� ������.
  @param aRoot ���� ������.
  @param aAdd ���������� � ����.
  @return ������ ������������ ������ � ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAFileSystem.AddPathAlias(const aName, aRoot, aAdd: string): Integer;
var
  Idx: Integer;
  PathAlias: TSAPathAlias;
begin
  Idx := FindPathAlias(aName);
  Assert(Idx = -1, Format('Such path alias(%s) alredy exists.', [aName]));

  if Idx <> -1 then
    Exit(-1);

  // ���������� �����
  PathAlias.Name := aName;

  // ������� ����� ����� ������� ����������
  Idx := FindPathAlias(aRoot);
  if Idx <> -1 then
    PathAlias.Root := FPathAliases[Idx].Root
  else
  begin
    PathAlias.Root := aRoot;
    TSAStringUtils.PathAppendSeparator(PathAlias.Root);
  end;

  // ���� ���� ����������, ����� ��� ���� ����������
  PathAlias.Root := PathAlias.Root + aAdd;
  TSAStringUtils.PathAppendSeparator(PathAlias.Root);

  // ������� ����� � ������
  Result := FPathAliases.Add(PathAlias);
end;

{*------------------------------------------------------------------------------
  ����� ������ �� ��������������.
  @param aName ������������� ������.
  @return ������ � ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAFileSystem.FindPathAlias(const aName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FPathAliases.Count - 1 do
    if FPathAliases[i].Name = aName then
      Exit(i);

  Result := -1;
end;

{*------------------------------------------------------------------------------
  ������ ����� ������������ �����.
  @note ���� ������������ ����� �������� ����������� ������� �����.
  ������ ������ ���������:
  $�������������$ | root_path | add_path | caption
  @param aReader ��������� ������ ���������������� � ������ ������������.
  @author Neo][
  @throws ESAFSSpecFile
  @todo
-------------------------------------------------------------------------------}

procedure TSAFileSystem.ParseFSSpec(const aReader: TSAReader);

// ������� �� ��������� ������ � �����
  function NextLine(aPCaret, aPEnd: PAnsiChar): PAnsiChar;
  begin
    while (aPCaret < aPEnd) and (aPCaret^ <> #10) do
      Inc(aPCaret);

    Result := aPCaret + 1;
  end;

  // ������ ����� ������
  function ReadAlias(aPCaret, aPEnd: PAnsiChar): PAnsiChar;
  begin
    if ((aPCaret >= aPEnd) or (aPCaret^ <> '$')) then
      Exit(nil);

    Inc(aPCaret);

    if ((aPCaret >= aPEnd) or
      (not TCharacter.IsLetterOrDigit(Char(aPCaret^)) and
      (aPCaret^ <> '_'))) then
      Exit(nil);

    while aPCaret < aPEnd do
    begin
      if aPCaret^ = '$' then
        Exit(aPCaret + 1)
      else if (not TCharacter.IsLetterOrDigit(Char(aPCaret^)) and
        (aPCaret^ <> '_')) then
        Break;

      Inc(aPCaret);
    end;

    Result := nil;
  end;

  // ������� ����������� ��������(������, ���������, etc.)
  function SkipSS(aPCaret, aPEnd: PAnsiChar): PAnsiChar;
  begin
    while aPCaret < aPEnd do
    begin
      if (aPCaret^ <> ' ') and (aPCaret^ <> #9) then
        Break;

      Inc(aPCaret);
    end;
    Result := aPCaret;
  end;

  // ������ �������� ������
  function ReadValue(aPCaret, aPEnd: PAnsiChar): PAnsiChar;
  var
    PLastSS: PAnsiChar;
  begin
    aPCaret := SkipSS(aPCaret, aPEnd);
    PLastSS := nil;

    while aPCaret < aPEnd do
    begin
      if (aPCaret^ = ' ') or (aPCaret^ = #9) then
      begin
        if PLastSS = nil then
          PLastSS := aPCaret;
      end
      else if (aPCaret^ = '#10') or (aPCaret^ = #13) or (aPCaret^ = '|') then
      begin
        if PLastSS = nil then
          PLastSS := aPCaret;

        Break;
      end
      else
        PLastSS := nil;

      Inc(aPCaret);
    end;

    if PLastSS <> nil then
      Result := PLastSS
    else
      Result := aPCaret;
  end;

  // �������������� ���������� � ������
  function ToString(aPCaret, aPEnd: PAnsiChar): string;
  var
    TmpAnsi: AnsiString;
    Len: Integer;
  begin
    { TODO -oNeo][ -c : Check bounds 12.04.2009 20:07:59 }
    Len := aPEnd - aPCaret;
    SetLength(TmpAnsi, Len);
    Move(aPCaret^, TmpAnsi[1], Len);
    Result := string(TmpAnsi);
  end;

  //---------- Main func impl ----------
var
  PCaret,                               // ��������� �� ������� ������� � �����
  PEnd,                                 // ��������� �� ����� �����
  PLast: PAnsiChar;                     // ��������� �� ����� ������-���� ������ ��� ������� � �.�.

  Line: Cardinal;                       // ������ � �����
  TmpAliasName: string;                 // ��� ������
  TmpValues: array[0..2] of string;     // ������ ���������� ������
  I: Integer;
begin
  PCaret := aReader.FCaret.chr;
  PEnd := PCaret + aReader.Size;

  Line := 1;
  while PCaret < PEnd do
  begin
    // ��������� ������ ������ �������������� ������
    if PCaret^ = '$' then
    begin
      // �������� ���������� ������ ����� $...$, ������� ��� $
      PLast := ReadAlias(PCaret, PEnd);
      if PLast = nil then
      begin
        raise ESAFSSpecFile.CreateFmt(StrFSSpecFileParsingErr, [Line]);
      end;

      // ��������� ������������� ������
      TmpAliasName := ToString(PCaret, PLast);

      // ���������� ����������� �������
      PCaret := SkipSS(PLast, PEnd);
      if (PCaret = PEnd) or ((PCaret)^ <> '|') then
      begin
        raise ESAFSSpecFile.CreateFmt(StrFSSpecFileParsingErr, [Line]);
      end;

      // ������ ��������� ������
      for I := 0 to 2 do
      begin
        // ���������� ������ ����������� | � ����. �������
        Inc(PCaret);
        PCaret := SkipSS(PCaret, PEnd);

        // ������ �������� ������
        PLast := ReadValue(PCaret, PEnd);

        //if (PLast = PEnd) {or (SkipSS(PLast, PEnd)^ <> '|')} then
        //begin
        //  gCore.Log.LogFatal('[FS]Can''t parse FS specification file, line: %d', [Line]);
        //  Exit(False);
        //end;

        TmpValues[i] := ToString(PCaret, PLast);

        // ���������� ����. ������� ����� ��������.
        PCaret := SkipSS(PLast, PEnd);

        // ���� ����� �������� ��� ����������� ��� �������� ����� ����� - ��������� ����
        if (PCaret = PEnd) or (SkipSS(PLast, PEnd)^ <> '|') then
          Break;
      end;

      // ��������� ����� � ������
      if AddPathAlias(TmpAliasName, TmpValues[0], TmpValues[1]) = -1 then
      begin
        raise ESAFSSpecFile.CreateFmt(StrFSSpecFileParsingErr, [Line]);
      end;
    end
    else if (PCaret^ <> ';') and (PCaret^ <> ' ') then  { TODO : �, ���� ������ ������� ���������� ����������!? ��� ��� �������� ��� SkipSS }
    begin
      raise ESAFSSpecFile.CreateFmt(StrFSSpecFileParsingErr, [Line]);
    end;

    // ��������� �� ����. ������
    PCaret := NextLine(PCaret, PEnd);
    Inc(Line);
  end;
end;

{*------------------------------------------------------------------------------
  ������������� �������� �������. ��������� ���� ����� �� ����� ������������.
  @param aFSSpecFileName ��� ����� ������������ �����.
  @return True, ���� �������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAFileSystem.Init(const aFSSpecFileName: string): Boolean;
var
  R: TSAReader;
begin
  if aFSSpecFileName <> '' then
  begin
    // ��������� ����
    R := ReadOpen(aFSSpecFileName);
    if (R = nil) then
      Exit(False);

    // ���� �� ������ ���������� ���� ������������ �����, ����� ������� ������
    // �������, ������� � ����� ����� False
    try
      try
        ParseFSSpec(R);
      finally
        ReadClose(R);
      end;
    except
      FPathAliases.Clear;
      //raise;
    end;
  end;

  Result := FPathAliases.Count <> 0;
end;

{*------------------------------------------------------------------------------
  �������� ����� �� ������.
  @param aFileName ��� �����.
  @return ��������� ��������� �� ��������� TSAReader, ������������ � ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAFileSystem.ReadOpen(const aFileName: string): TSAReader;
var
  hFile,                                // ����� �����
  hMMap: Cardinal;                      // ����� memory mapping-a
  size64: LARGE_INTEGER;                // 64� ������ �����
  Len: Cardinal;
  SI: SYSTEM_INFO;
  Reader: TSAReader;                    // ��������� �� �����
  Data: Pointer;                        // ��������� �� ������ �����
  Read: Cardinal;                       // ���������� ����������� ���� �� �����
begin
  Reader := nil;

  hFile := CreateFile(PChar(aFileName),
    GENERIC_READ,
    FILE_SHARE_READ,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0);

  if hFile = INVALID_HANDLE_VALUE then
    Exit(nil);

  //-------------------------
  // �������� ������ �����
  //-------------------------
  if ((not GetFileSizeEx(hFile, size64)) or (size64.HighPart <> 0)) then
  begin
    CloseHandle(hFile);
    Exit(nil);
  end;

  Len := size64.LowPart;
  GetSystemInfo(SI);

  //-----------------------------------------------
  // ���� ���� ���������� � �������� ������(64��),
  // ����� �������� ������ � ����
  //-----------------------------------------------
  if Len < SI.dwAllocationGranularity then
  begin
    try
      // �������� ������ ��� ������ �� �����
      Data := GetMemory(Len);           /// !!! Throw Exception
    except
      Data := nil
    end;

    // ���� ������� �������� ������ - ������ ������ �� �����
    if Assigned(Data) then
      if (ReadFile(hFile, Data^, Len, Read, nil) and (Read = Len)) then
        Reader := TSAReader.Create(Data, Len)
      else
        FreeMem(Data);

    // ��������� ���� � ��������� ��������� ������
    CloseHandle(hFile);
    Exit(Reader);
  end;

  //----------------------
  // ����� ������� ����
  //----------------------
  hMMap := CreateFileMapping(hFile, nil, PAGE_READONLY, 0, Len, nil);
  if hMMap = 0 then
  begin
    CloseHandle(hFile);
    Exit(nil);
  end;

  Data := MapViewOfFile(hMMap, FILE_MAP_READ, 0, 0, Len);
  if Data <> nil then
  begin
    Reader := TSAMMapReader.Create(hFile, hMMap, Data, Len);
    if Reader <> nil then
      Exit(Reader);

    UnmapViewOfFile(Data);
  end
  else if GetLastError() = ERROR_NOT_ENOUGH_MEMORY then
  begin
    // ���� ��������� � ��� ������ �� �������� �����

  end;

  CloseHandle(hMMap);
  CloseHandle(hFile);

  Result := nil;
end;

{*------------------------------------------------------------------------------
  �������� ����� ��������� �� ������.
  @param aReader ��������� ������, ������� ��������� � �������� ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TSAFileSystem.ReadClose(var aReader: TSAReader);
begin
  aReader.Free;
  aReader := nil;
end;

{============================================}
{================= TSAReader ================}
{============================================}

{*------------------------------------------------------------------------------
  ����������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TSAReader.Create;
begin
  FData := nil;
  FNext := nil;
  FEnd := nil;
  FCaret.u8 := nil;
end;

{*------------------------------------------------------------------------------
  ����������� � ������������ ������� ��������� �� ������.
  @param aData ��������� �� ������.
  @param aSize ������ ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TSAReader.Create(aData: Pointer; aSize: Cardinal);
begin
  FData := aData;
  FNext := aData;
  FCaret.u8 := aData;

  FEnd := FData + aSize;
end;

{*------------------------------------------------------------------------------
  ���������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TSAReader.Destroy;
begin

  inherited;
end;

function TSAReader.FindChunk(aID: Cardinal; var aCompressed: Boolean;
  aReset: Boolean): Cardinal;
var
  ID, Size: Cardinal;
begin
  if aReset then
    FCaret.u8 := FData;

  while (FCaret.u8 < FEnd) do
  begin
    Assert(FCaret.u8 + 8 <= FEnd, 'Can''t inc pointer');

    ID := r_u32;
    Size := r_u32;

    Assert(FCaret.u8 + Size <= FEnd);

    if (aID = (ID and CHUNK_ID_MASK)) then
    begin
      aCompressed := (ID and CHUNK_COMPRESSED) <> 0;
      Exit(Size);
    end;

    Inc(FCaret.u8, Size);
  end;

  Result := 0;
end;

function TSAReader.FindChunk(aID: Cardinal): Cardinal;
var
  Compressed: Boolean;
begin
  Result := FindChunk(aID, Compressed);
end;

{*------------------------------------------------------------------------------

  @param aID
  @return
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAReader.OpenChunk(aID: Cardinal): TSAReader;
var
  Compressed: Boolean;
  Size, RealSize: Cardinal;
  Data: PByte;
  LZH: TLZH;
begin
  Size := FindChunk(aID, Compressed);

  if Size = 0 then
    Exit(nil);

  if Compressed then
  begin
    LZH := TLZH.Create;
    try
      LZH.Decompress(Data, RealSize, FCaret.u8, Size);
      Result := TSATempReader.Create(Data, RealSize);
    finally
      LZH.Free;
    end;
  end
  else
  begin
    Result := TSAReader.Create(FCaret.u8, Size);
  end;
end;

{*------------------------------------------------------------------------------

  @param aID
  @param aScrambler
  @return
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAReader.OpenChunk(aID: Cardinal;
  const aScrambler: TSAScrambler): TSAReader;
begin
  Result := nil;
end;

procedure TSAReader.CloseChunk(var aReader: TSAReader);
begin
  Assert((aReader = nil) or ((aReader <> Self) and (aReader.FCaret.u8 <= aReader.FEnd)));
  FreeAndNil(aReader);
end;

procedure TSAReader.r_raw(aDestination: Pointer; aDestSize: Cardinal);
begin
  Assert(FCaret.u8 + aDestSize <= FEnd);

  Move(FCaret.u8, aDestination, aDestSize);
  Inc(FCaret.u8, aDestSize);
end;

procedure TSAReader.r_sz(var aDest: string);
var
  p: PAnsiChar;
begin

  p := FCaret.chr;
  Assert(p < FEnd);

  while (p^ <> #0) do
  begin
    if p >= FEnd then
    begin
      aDest := TSAStringUtils.ToString(FCaret.chr, p);
      FCaret.chr := p;
      Exit;
    end;

    Inc(p);
  end;

  aDest := TSAStringUtils.ToString(FCaret.chr, p);
  FCaret.chr := p + 1;
end;

function TSAReader.r_s16: SmallInt;
begin
  Result := FCaret.s16^;
  Inc(FCaret.s16);
end;

function TSAReader.r_s32: LongInt;
begin
  Result := FCaret.s32^;
  Inc(FCaret.s32);
end;

function TSAReader.r_s8: ShortInt;
begin
  Result := FCaret.s8^;
  Inc(FCaret.s8);
end;

function TSAReader.r_u16: Word;
begin
  Result := FCaret.u16^;
  Inc(FCaret.u16);
end;

function TSAReader.r_u24: Cardinal;
begin
  Result := 0;
  r_raw(@Result, 3);
end;

function TSAReader.r_u32: LongWord;
begin
  Result := FCaret.u32^;
  Inc(FCaret.u32);
end;

function TSAReader.r_u8: Byte;
begin
  Result := FCaret.u8^;
  Inc(FCaret.u8);
end;

function TSAReader.r_bool: Boolean;
begin
  Result := FCaret.u8^ <> 0;
  Inc(FCaret.u8);
end;

{*------------------------------------------------------------------------------
  ����� �������� ��������� �� ������.
  @return ��������� �� ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAReader.GetData: Pointer;
begin
  Result := Pointer(FData);
end;

{*------------------------------------------------------------------------------
  ������ �������� EOF.
  @return True, ���� �������� ����� �����.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAReader.GetEOF: Boolean;
begin
  Assert(FCaret.u8 <= FEnd);
  Result := FCaret.u8 = FEnd;
end;

{*------------------------------------------------------------------------------
  ����� �������� ������.
  @return ������ ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

function TSAReader.GetSize: Cardinal;
begin
  Assert(FData <= FEnd);
  Result := FEnd - FData;
end;

{============================================}
{============== TSAMMapReader ===============}
{============================================}

{*------------------------------------------------------------------------------
  ����������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TSAMMapReader.Create;
begin
  FHFile := INVALID_HANDLE_VALUE;
  FHMMap := INVALID_HANDLE_VALUE;
end;

{*------------------------------------------------------------------------------
  ����������� � ������������ ���������� � ���� ��������� � �����. �������.
  @param aHFile ����� ������������ �����.
  @param aHMMap ����� memory mapping-a.
  @param aData ��������� �� ������.
  @param aSize ������ ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TSAMMapReader.Create(aHFile, aHMMap: Cardinal; aData: Pointer; aSize: Cardinal);
begin
  FHFile := aHFile;
  FHMMap := aHMMap;

  FData := aData;
  FNext := aData;
  FCaret.u8 := aData;

  FEnd := FData + aSize;
end;

{*------------------------------------------------------------------------------
  ���������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TSAMMapReader.Destroy;
begin
  Assert(Assigned(FData));
  Assert(FHMMap <> INVALID_HANDLE_VALUE);
  Assert(FHFile <> INVALID_HANDLE_VALUE);

  UnmapViewOfFile(FData);

  CloseHandle(FHMMap);
  CloseHandle(FHFile);

  inherited;
end;

{ TSATempReader }

destructor TSATempReader.Destroy;
begin
  if FData <> nil then
    FreeMem(FData);

  FData := nil;

  inherited;
end;

end.

