unit dbtOperationsThreads;

interface

uses
  xrFSLDBTools, Classes, Forms;

type
  {*------------------------------------------------------------------------------
    ����� �������� ������ ��� �������� � ����������.
  -------------------------------------------------------------------------------}
  TBaseProgressThread = class(TThread)
  private
    FProgressForm: TForm;               /// ��������� ����� ���������
    FDBTools: TDBTools;                 /// ��������� �� ����� ������

    FDBToolsOwner: Boolean;             /// ����, ��������� �� �� ���� DBTools ��� ����� �������

    FProgress: TDBProgress;             /// ��������(����������� �� �����������)
    FProgressHandler: TDBProgressProc;  /// ������ ����� ���������� ���������

  protected
    procedure OnComplete(Sender: TObject);
  public
    constructor Create(const aProgressForm: TForm; const aDBTools: TDBTools = nil);
    destructor Destroy; override;
  end;

  {*------------------------------------------------------------------------------
    ����� ������, ������������ �������� ������ � ��������� ������.
  -------------------------------------------------------------------------------}
  TOpenDBThread = class(TBaseProgressThread)
  private
    FFileName: string;                  /// ��� �����, ������� ���������� �������
  public
    constructor Create(const aProgressForm: TForm; const aDBTools: TDBTools; const aFileName: string);
    destructor Destroy; override;

    procedure Execute; override;
  end;

implementation

uses
  formProgress, Controls, SysUtils;

{ TBaseProgressThread }

{*------------------------------------------------------------------------------

  @param aProgressForm
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TBaseProgressThread.Create(const aProgressForm: TForm;
  const aDBTools: TDBTools);
begin
  // ���������� ����� ������
  FProgressForm := aProgressForm;

  // ���������� �������� ���������� ������
  OnTerminate := OnComplete;

  //--------------------------------------
  // ����������� ������ ������ ���������
  //--------------------------------------
  {(*}
  FProgressHandler := function(Sender: TDBTools; const aProgress: TDBProgress): Boolean
  var
    // ������ ��������� ��� ������������������� ������
    UpdateProc: TThreadProcedure;
  begin
    // ��������� ������ ���������
    FProgress := aProgress;

    // ����������� ������ ��������� ��� ������������������� ���������� ���������
    UpdateProc := procedure
    begin
      TfrmProgress(FProgressForm).lbl1.Caption := FProgress.OperationName;
      TfrmProgress(FProgressForm).pbProgress.Position := FProgress.Progress;
      FProgress.Canceled := TfrmProgress(FProgressForm).Canceled;
    end;

    Synchronize(UpdateProc);
    Result := FProgress.Canceled;
  end;
  {*)}

  //------------------------
  // �������� ������ ������
  //------------------------
  FDBToolsOwner := not Assigned(aDBTools);
  if FDBToolsOwner then
    FDBTools := TDBTools.Create
  else
    FDBTools := aDBTools;

  FDBTools.OnProgress := FProgressHandler;

  inherited Create(False);
end;

{*------------------------------------------------------------------------------

  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TBaseProgressThread.Destroy;
begin
  if FDBToolsOwner and Assigned(FDBTools) then
    FreeAndNil(FDBTools);

  inherited;
end;

{*------------------------------------------------------------------------------
  �������� ���� ���������.
  @param Sender
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TBaseProgressThread.OnComplete(Sender: TObject);
begin
  FProgressForm.ModalResult := mrOk;
end;

{ TOpenDBThread }

{*------------------------------------------------------------------------------

  @param aProgressForm
  @param aFileName
  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

constructor TOpenDBThread.Create(const aProgressForm: TForm;
  const aDBTools: TDBTools; const aFileName: string);
begin
  inherited Create(aProgressForm, aDBTools);

  FFileName := aFileName;
end;

{*------------------------------------------------------------------------------

  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

destructor TOpenDBThread.Destroy;
begin

  inherited;
end;

{*------------------------------------------------------------------------------

  @author Neo][
  @throws
  @todo
-------------------------------------------------------------------------------}

procedure TOpenDBThread.Execute;
begin
  inherited;

  FDBTools.Open(FFileName);
end;

end.

