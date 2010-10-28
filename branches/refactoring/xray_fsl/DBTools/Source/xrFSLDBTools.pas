{-----------------------------------------------------------------------------
 Unit Name: xrFSLDBTools
 Author:    Neo][
 Date:      27-���-2009
 Purpose:
 History:
-----------------------------------------------------------------------------}

unit xrFSLDBTools;

interface

uses
  SAFileSystem, Generics.Collections;

const
  // ��������� ������ ������
  DB_VERSION_AUTO = 0;
  DB_VERSION_1114 = $01;
  DB_VERSION_2215 = $02;
  DB_VERSION_2945 = $04;
  DB_VERSION_2947RU = $08;
  DB_VERSION_2947WW = $10;
  DB_VERSION_XDB = $20;

  // ID-����� ������ � ����� ������
  DB_CHUNK_DATA = 0;
  DB_CHUNK_HEADER = 1;
  DB_CHUNK_USERDATA = $29A;

  DBT_PROGRESS_RES = 50;                /// ���������� �������� ����� ������������ ���������

type
  // Forward decl
  TDBTools = class;

  {*-----------------------------------------------------------------------
    ��������� ������������ ��� �������� ���������� � ��������� � �������
    �������-�������.
  -------------------------------------------------------------------------}
  TDBProgress = record
    Canceled: Boolean;                  /// ���� ����������� �� ��������
    OperationName: string;              /// ��� �������� � ��������� ������� �� ����������
    Progress: Byte;                     /// �������� �������� � %
  end;

  {*------------------------------------------------------------------------------
    �������� ������ ������ ���������.
    @param Sender ��������� ������, ���������� �����.
    @param aProgress ��������� � ����������� � ���������.
    @return ��������� ������� ���������� ����������� ����������� ��������
    � ��������� ������� �� ���� ����������. True - ����������,
    False - ��������.
    @author Neo][
    @throws
    @todo
  -------------------------------------------------------------------------------}
  {(*}
  TDBProgressProc = reference to function(Sender: TDBTools; const aProgress: TDBProgress): Boolean;
  {*)}

{*------------------------------------------------------------------------------
  ��������� ����������� ���� � ������.
-------------------------------------------------------------------------------}
  PDBFile = ^TDBFile;
  TDBFile = record
    Path: string;                       /// ���� �� �����
    Offset: Cardinal;                   /// �������� ������ �����
    RealSize: Cardinal;                 /// �������� ������ �����
    CompressedSize: Cardinal;           /// ������ ������ ������
    CRC: Cardinal;                      /// CRC32 �����
  end;

  TDBFileList = TList < TDBFile > ;

  {*------------------------------------------------------------------------------
    ����� ��� ������ � �������.
  -------------------------------------------------------------------------------}
  TDBTools = class(tobject)
  private
    FFS: TSAFileSystem;                 /// ����� �������� �������

    FDBFileName: string;                /// ��� ��������� �����
    FDBVersion: Cardinal;               /// ������ ������
    FFiles: TDBFileList;                /// ������ ������ � ������
    FOnProgress: TDBProgressProc;       /// ��������� �� ������ ����� ��������� ���������

    { extension archive type }
    function IsXRP(const aFileExt: string): Boolean;
    function IsXP(const aFileExt: string): Boolean;
    function IsXDB(const aFileExt: string): Boolean;
    function IsDB(const aFileExt: string): Boolean;

    { reading archive }
    procedure Read1114(const aPrefix: string; const aReader: TSAReader);
    procedure Read2215(const aPrefix: string; const aReader: TSAReader);
    procedure Read2945(const aPrefix: string; const aReader: TSAReader);
  public
    { constructors/destructors }
    constructor Create;
    destructor Destroy; override;

    {}
    function IsKnown(const aFileExt: string): Boolean;
    procedure Open(const aFileName: string);
    procedure Close;

    property Version: Cardinal read FDBVersion;
    property FileName: string read FDBFileName;
    property Files: TDBFileList read FFiles;
    property OnProgress: TDBProgressProc read FOnProgress write FOnProgress;
  end;

implementation

uses
  SysUtils, JclFileUtils, SAStringUtils, Character;

{ TDBTools }

{*------------------------------------------------------------------------------
  ����������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TDBTools.Create;
begin
  FDBFileName := '';
  FDBVersion := DB_VERSION_AUTO;
  FFiles := TDBFileList.Create;

  FFS := TSAFileSystem.Create;

  inherited;
end;

{*------------------------------------------------------------------------------
  ���������� �� ���������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TDBTools.Destroy;
begin
  //Close;

  FreeAndNil(FFS);
  FreeAndNil(FFiles);

  inherited;
end;

function TDBTools.IsDB(const aFileExt: string): Boolean;
begin
  Result := (TSAStringUtils.PosText('.db', aFileExt, 0, 3) <> 0) and
    (Length(aFileExt) = 4) and (TCharacter.IsNumber(aFileExt, 3));
end;

function TDBTools.IsXDB(const aFileExt: string): Boolean;
begin
  Result := (TSAStringUtils.PosText('.xdb', aFileExt, 0, 4) <> 0) and
    (Length(aFileExt) = 5) and (TCharacter.IsNumber(aFileExt, 4));
end;

function TDBTools.IsXP(const aFileExt: string): Boolean;
begin
  Result := (TSAStringUtils.PosText('.xp', aFileExt, 1, 4) <> 0) and
    (Length(aFileExt) = 4) and (TCharacter.IsNumber(aFileExt, 4));
end;

function TDBTools.IsXRP(const aFileExt: string): Boolean;
begin
  Result := CompareText(aFileExt, '.xrp') = 0;
end;

function TDBTools.IsKnown(const aFileExt: string): Boolean;
begin
  Result := IsDB(aFileExt) or
    IsXDB(aFileExt) or
    IsXRP(aFileExt) or
    IsXP(aFileExt);
end;

{*------------------------------------------------------------------------------
  �������� ����� ������. ����������� ������� ���������.
  @param aFileName ������ ���� �� ����� ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TDBTools.Open(const aFileName: string);
var
  Prefix, FileExt, TmpStr: string;
  Reader, ChunkReader: TSAReader;
begin
  // ��������, ���� ��� ��� ������ �����
  if FDBFileName <> '' then
    Close;

  // ������� ���������� �����, ����� ���������� ��� ������
  PathExtractElements(aFileName, TmpStr, TmpStr, Prefix, FileExt);

  //-------------------------
  // ����������� ���� ������
  //-------------------------
  FDBVersion := DB_VERSION_AUTO;
  if IsXDB(FileExt) then
    FDBVersion := FDBVersion or DB_VERSION_XDB
  else if IsXRP(FileExt) then
    FDBVersion := FDBVersion or DB_VERSION_1114
  else if IsXP(FileExt) then
    FDBVersion := FDBVersion or DB_VERSION_2215;

  if (FDBVersion = DB_VERSION_AUTO) or ((FDBVersion and (FDBVersion - 1)) <> 0) then
    raise Exception.CreateFmt('Unspecified archive format. Ext: %s', [FileExt]);

  //-----------------------
  // ��������� ���� ������
  //-----------------------
  ChunkReader := nil;
  Reader := FFS.ReadOpen(aFileName);
  if not Assigned(Reader) then
    raise Exception.CreateFmt('Can''t open: %s', [aFileName]);

  //------------------
  // ������ ���������
  //------------------
  case FDBVersion of
    DB_VERSION_1114, DB_VERSION_2215, DB_VERSION_2945, DB_VERSION_XDB:
      ChunkReader := Reader.OpenChunk(DB_CHUNK_HEADER);
  end;

  //---------------------
  // ������� ���������
  //---------------------
  if Assigned(ChunkReader) then
  begin
    case FDBVersion of
      DB_VERSION_1114:
        Read1114(Prefix, ChunkReader);
      DB_VERSION_2215:
        Read2215(Prefix, ChunkReader);
      DB_VERSION_2945:
        Read2945(Prefix, ChunkReader);
    end;

    Reader.CloseChunk(ChunkReader);
  end;

  FFS.ReadClose(Reader);

  FDBFileName := aFileName;
end;

{*------------------------------------------------------------------------------
  �������� ��������� ������. ��������� ������� ���� ��������� ������.
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TDBTools.Close;
begin
  FFiles.Clear;
  FDBVersion := DB_VERSION_AUTO;
  FDBFileName := '';
end;

{*------------------------------------------------------------------------------
  ����� ������ ����������� ������ ������ DB_VERSION_1114
  @param aPrefix
  @param aReader
  @param Data
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TDBTools.Read1114(const aPrefix: string; const aReader: TSAReader);
var
  TmpFile: TDBFile;
  Uncompressed: Cardinal;
  Progress: TDBProgress;
begin
  Progress.OperationName := '[1114]Reading content of archive...';

  while not aReader.EOF do
  begin
    aReader.r_sz(TmpFile.Path);

    Uncompressed := aReader.r_u32;
    TmpFile.Offset := aReader.r_u32;
    TmpFile.RealSize := aReader.r_u32;

    FFiles.Add(TmpFile);

    //-------------------------------
    // ��������� ��������� ��������
    //-------------------------------
    if Assigned(FOnProgress) and (FFiles.Count mod DBT_PROGRESS_RES = 0) then
    begin
      /// !debug
      Progress.Progress := Progress.Progress + 1;
      if Progress.Progress > 100 then
        Progress.Progress := 0;

      if FOnProgress(Self, Progress) then
        Exit;
    end;
  end;

  if Assigned(FOnProgress) then
  begin
    Progress.OperationName := 'Reading content of archive complete';
    Progress.Progress := 100;
    FOnProgress(Self, Progress);
  end;

  //xr_file_system& fs = xr_file_system::instance();
  //	for (std::string temp, path, folder; !s->eof(); ) {
  //		s->r_sz(temp);
  //		unsigned uncompressed = s->r_u32();
  //		unsigned offset = s->r_u32();
  //		unsigned size = s->r_u32();
  //		if (DB_DEBUG && fs.read_only()) {
  //			msg("%s", temp.c_str());
  //			msg("  offset: %u", offset);
  //			if (uncompressed)
  //				msg("  size (real): %u", size);
  //			else
  //				msg("  size (compressed): %u", size);
  //		} else {
  //			path = prefix;
  //			fs.split_path(path.append(temp), &folder);
  //			if (!fs.folder_exist(folder))
  //				fs.create_path(folder);
  //			if (uncompressed) {
  //				write_file(fs, path, data + offset, size);
  //			} else {
  //				size_t real_size;
  //				uint8_t* p;
  //				xr_lzhuf::decompress(p, real_size, data + offset, size);
  //				if (real_size)
  //					write_file(fs, path, p, real_size);
  //				free(p);
  //			}
  //		}
  //	}
end;

procedure TDBTools.Read2215(const aPrefix: string; const aReader: TSAReader);
var
  TmpFile: TDBFile;
  Progress: TDBProgress;
begin
  Progress.OperationName := '[2215]Reading content of archive...';

  while not aReader.EOF do
  begin
    aReader.r_sz(TmpFile.Path);

    TmpFile.Offset := aReader.r_u32;
    TmpFile.RealSize := aReader.r_u32;
    TmpFile.CompressedSize := aReader.r_u32;

    if TmpFile.Offset <> 0 then
      FFiles.Add(TmpFile);

    //-------------------------------
    // ��������� ��������� ��������
    //-------------------------------
    if Assigned(FOnProgress) and (FFiles.Count mod DBT_PROGRESS_RES = 0) then
    begin
      /// !debug
      Progress.Progress := Progress.Progress + 1;
      if Progress.Progress > 100 then
        Progress.Progress := 0;

      if FOnProgress(Self, Progress) then
        Exit;
    end;
  end;

  if Assigned(FOnProgress) then
  begin
    Progress.OperationName := 'Reading content of archive complete';
    Progress.Progress := 100;
    FOnProgress(Self, Progress);
  end;
end;

{*------------------------------------------------------------------------------

  @param aPrefix
  @param aReader
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TDBTools.Read2945(const aPrefix: string; const aReader: TSAReader);
var
  TmpFile: TDBFile;
  Progress: TDBProgress;
begin
  Progress.OperationName := '[2945]Reading content of archive...';

  while not aReader.EOF do
  begin
    aReader.r_sz(TmpFile.Path);

    TmpFile.CRC := aReader.r_u32;
    TmpFile.Offset := aReader.r_u32;
    TmpFile.RealSize := aReader.r_u32;
    TmpFile.CompressedSize := aReader.r_u32;

    if TmpFile.Offset <> 0 then
      FFiles.Add(TmpFile);

    //-------------------------------
    // ��������� ��������� ��������
    //-------------------------------
    if Assigned(FOnProgress) and (FFiles.Count mod DBT_PROGRESS_RES = 0) then
    begin
      /// !debug
      Progress.Progress := Progress.Progress + 1;
      if Progress.Progress > 100 then
        Progress.Progress := 0;

      if FOnProgress(Self, Progress) then
        Exit;
    end;
  end;

  if Assigned(FOnProgress) then
  begin
    Progress.OperationName := 'Reading content of archive complete';
    Progress.Progress := 100;
    FOnProgress(Self, Progress);
  end;
end;

end.

