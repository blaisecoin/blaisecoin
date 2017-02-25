{
  Copyright (c) 2016 by Albert Molina
  Copyright (c) 2017 by BlaiseCoin developers

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  This unit is a part of BlaiseCoin, a P2P crypto-currency.
}

unit UGridUtils;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
{$IFnDEF FPC}
  Windows,
{$ELSE}
  LCLIntf, LCLType, LMessages,
{$ENDIF}
  Classes, Grids, UNode, UAccounts, UBlockChain, UAppParams,
  UWalletKeys, UCrypto;

Type
  // TAccountsGrid implements a visual integration of TDrawGrid
  // to show accounts information
  TAccountColumnType = (act_account_number,act_account_key,act_balance,act_updated,act_n_operation,act_updated_state);
  TAccountColumn = Record
    ColumnType : TAccountColumnType;
    width : Integer;
  end;

  TAccountsGrid = class(TComponent)
  private
    FAccountsBalance : Int64;
    FAccountsList : TOrderedCardinalList;
    FColumns : Array of TAccountColumn;
    FDrawGrid : TDrawGrid;
    FNodeNotifyEvents : TNodeNotifyEvents;
    FShowAllAccounts: Boolean;
    FOnUpdated: TNotifyEvent;
    FAccountsCount: Integer;
    procedure SetDrawGrid(const Value: TDrawGrid);
    procedure InitGrid;
    procedure OnNodeNewOperation(Sender : TObject);
    procedure OnGridDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure SetNode(const Value: TNode);
    function GetNode: TNode;
    procedure SetShowAllAccounts(const Value: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); Override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    property DrawGrid : TDrawGrid read FDrawGrid write SetDrawGrid;
    function LockAccountsList : TOrderedCardinalList;
    procedure UnlockAccountsList;
    property Node : TNode read GetNode write SetNode;
    function AccountNumber(GridRow : Integer) : Int64;
    procedure SaveToStream(Stream : TStream);
    procedure LoadFromStream(Stream : TStream);
    property ShowAllAccounts : Boolean read FShowAllAccounts write SetShowAllAccounts;
    property AccountsBalance : Int64 read FAccountsBalance;
    property AccountsCount : Integer read FAccountsCount;
    function MoveRowToAccount(nAccount : Cardinal) : Boolean;
    property OnUpdated : TNotifyEvent read FOnUpdated write FOnUpdated;
  end;

  TOperationsGrid = class(TComponent)
  private
    FDrawGrid: TDrawGrid;
    FAccountNumber: Int64;
    FOperationsResume : TOperationsResumeList;
    FNodeNotifyEvents : TNodeNotifyEvents;
    FPendingOperations: Boolean;
    FBlockStart: Int64;
    FBlockEnd: Int64;
    FMustShowAlwaysAnAccount: Boolean;
    procedure OnNodeNewOperation(Sender : TObject);
    procedure OnNodeNewAccount(Sender : TObject);
    procedure InitGrid;
    procedure OnGridDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    procedure SetDrawGrid(const Value: TDrawGrid);
    procedure SetAccountNumber(const Value: Int64);
    procedure SetNode(const Value: TNode);
    function GetNode: TNode;
    procedure SetPendingOperations(const Value: Boolean);

    procedure SetBlockEnd(const Value: Int64);
    procedure SetBlockStart(const Value: Int64);
    procedure SetMustShowAlwaysAnAccount(const Value: Boolean);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); Override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    property DrawGrid : TDrawGrid read FDrawGrid write SetDrawGrid;
    property PendingOperations : Boolean read FPendingOperations write SetPendingOperations;
    property AccountNumber : Int64 read FAccountNumber write SetAccountNumber;
    property MustShowAlwaysAnAccount : Boolean read FMustShowAlwaysAnAccount write SetMustShowAlwaysAnAccount;
    property Node : TNode read GetNode write SetNode;
    procedure UpdateAccountOperations; virtual;
    procedure ShowModalDecoder(WalletKeys: TWalletKeys; AppParams : TAppParams);
    property BlockStart : Int64 read FBlockStart write SetBlockStart;
    property BlockEnd : Int64 read FBlockEnd write SetBlockEnd;
    procedure SetBlocks(bstart,bend : Int64);
  end;

  TBlockChainData = Record
    Block : Cardinal;
    Timestamp : Cardinal;
    BlockProtocolVersion,
    BlockProtocolAvailable : Word;
    OperationsCount : Cardinal;
    Volume : Int64;
    Reward, Fee : Int64;
    Target : Cardinal;
    HashRateKhs : Int64;
    MinerPayload : TRawBytes;
    PoW : TRawBytes;
    SafeBoxHash : TRawBytes;
    AccumulatedWork : UInt64;
  end;
  TBlockChainDataArray = Array of TBlockChainData;

  TBlockChainGrid = class(TComponent)
  private
    FBlockChainDataArray : TBlockChainDataArray;
    FBlockStart: Int64;
    FMaxBlocks: Integer;
    FBlockEnd: Int64;
    FDrawGrid: TDrawGrid;
    FNodeNotifyEvents : TNodeNotifyEvents;
    FHashRateAverageBlocksCount: Integer;
    procedure OnNodeNewAccount(Sender : TObject);
    procedure InitGrid;
    procedure OnGridDrawCell(Sender: TObject; ACol, ARow: Longint; Rect: TRect; State: TGridDrawState);
    function GetNode: TNode;
    procedure SetBlockEnd(const Value: Int64);
    procedure SetBlockStart(const Value: Int64);
    procedure SetDrawGrid(const Value: TDrawGrid);
    procedure SetMaxBlocks(const Value: Integer);
    procedure SetNode(const Value: TNode);
    procedure SetHashRateAverageBlocksCount(const Value: Integer); public
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); Override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    property DrawGrid : TDrawGrid read FDrawGrid write SetDrawGrid;
    property Node : TNode read GetNode write SetNode;
    procedure UpdateBlockChainGrid; virtual;
    property BlockStart : Int64 read FBlockStart write SetBlockStart;
    property BlockEnd : Int64 read FBlockEnd write SetBlockEnd;
    procedure SetBlocks(bstart,bend : Int64);
    property MaxBlocks : Integer read FMaxBlocks write SetMaxBlocks;
    property HashRateAverageBlocksCount : Integer read FHashRateAverageBlocksCount write SetHashRateAverageBlocksCount;
  end;

Const
  CT_TBlockChainData_NUL : TBlockChainData = (Block:0;Timestamp:0;BlockProtocolVersion:0;BlockProtocolAvailable:0;OperationsCount:0;Volume:0;Reward:0;Fee:0;Target:0;HashRateKhs:0;MinerPayload:'';PoW:'';SafeBoxHash:'';AccumulatedWork:0);


implementation

uses
  Graphics, SysUtils, UTime, UOpTransaction, UConst,
  UFRMPayloadDecoder, ULog;

{ TAccountsGrid }

Const CT_ColumnHeader : Array[TAccountColumnType] Of String =
  ('Account N.','Key','Balance','Updated','N Oper.','State');

function TAccountsGrid.AccountNumber(GridRow: Integer): Int64;
begin
  if GridRow<1 then Result := -1
  else if FShowAllAccounts then begin
    if Assigned(Node) then begin
      Result := GridRow-1;
    end else Result := -1;
  end else if GridRow<=FAccountsList.Count then begin
    Result := (FAccountsList.Get(GridRow-1));
  end else Result := -1;
end;

constructor TAccountsGrid.Create(AOwner: TComponent);
var i : Integer;
begin
  inherited;
  FOnUpdated := nil;
  FAccountsBalance := 0;
  FAccountsCount := 0;
  FShowAllAccounts := false;
  FAccountsList := TOrderedCardinalList.Create;
  FDrawGrid := nil;
  SetLength(FColumns,4);
  FColumns[0].ColumnType := act_account_number;
  FColumns[0].width := 80;
  FColumns[1].ColumnType := act_balance;
  FColumns[1].width := 100;
  FColumns[2].ColumnType := act_n_operation;
  FColumns[2].width := 50;
  FColumns[3].ColumnType := act_updated_state;
  FColumns[3].width := 50;
  FNodeNotifyEvents := TNodeNotifyEvents.Create(Self);
  FNodeNotifyEvents.OnOperationsChanged := OnNodeNewOperation;
end;

destructor TAccountsGrid.Destroy;
begin
  FNodeNotifyEvents.Free;
  FAccountsList.Free;
  inherited;
end;

function TAccountsGrid.GetNode: TNode;
begin
  Result := FNodeNotifyEvents.Node;
end;

procedure TAccountsGrid.InitGrid;
var i : Integer;
  acc : TAccount;
begin
  FAccountsBalance := 0;
  FAccountsCount := FAccountsList.Count;
  if not assigned(DrawGrid) then exit;
  if FShowAllAccounts then begin
    if Assigned(Node) then begin
      if Node.Bank.AccountsCount<1 then DrawGrid.RowCount := 2
      else DrawGrid.RowCount := Node.Bank.AccountsCount+1;
      FAccountsBalance := Node.Bank.SafeBox.TotalBalance;
    end else DrawGrid.RowCount := 2;
  end else begin
    if FAccountsList.Count<1 then DrawGrid.RowCount := 2
    else DrawGrid.RowCount := FAccountsList.Count+1;
    if Assigned(Node) then begin
      for i := 0 to FAccountsList.Count - 1 do begin
        acc := Node.Bank.SafeBox.Account( FAccountsList.Get(i) );
        inc(FAccountsBalance, acc.balance);
      end;
    end;
  end;
  DrawGrid.FixedRows := 1;
  if Length(FColumns)=0 then DrawGrid.ColCount := 1
  else DrawGrid.ColCount := Length(FColumns);
  DrawGrid.FixedCols := 0;
  for i := low(FColumns) to high(FColumns) do begin
    DrawGrid.ColWidths[i] := FColumns[i].width;
  end;
  FDrawGrid.DefaultRowHeight := 18;
  DrawGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    {goRangeSelect, }goDrawFocusSelected, {goRowSizing, }goColSizing, {goRowMoving,}
    {goColMoving, goEditing, }goTabs, goRowSelect, {goAlwaysShowEditor,}
    goThumbTracking{$IFnDEF FPC}, goFixedColClick, goFixedRowClick, goFixedHotTrack{$ENDIF}];
  FDrawGrid.Invalidate;
  if Assigned(FOnUpdated) then FOnUpdated(Self);
end;

procedure TAccountsGrid.LoadFromStream(Stream: TStream);
var c,i,j : Integer;
begin
  if Stream.Read(c,sizeof(c))<sizeof(c) then exit;
  if c<=0 then exit;
  SetLength(FColumns,c);
  for i := 0 to c - 1 do begin
    Stream.Read(j,sizeof(j));
    if (j>=Integer(Low(TAccountColumnType))) And (j<=Integer(High(TAccountColumnType))) then begin
      FColumns[i].ColumnType := TAccountColumnType(j);
    end else FColumns[i].ColumnType := act_account_number;
    Stream.Read(FColumns[i].width,sizeof(FColumns[i].width));
  end;
  Stream.Read(j,sizeof(j));
  if Assigned(FDrawGrid) then FDrawGrid.Width := j;
  Stream.Read(j,sizeof(j));
  if Assigned(FDrawGrid) then FDrawGrid.Height := j;
end;

function TAccountsGrid.LockAccountsList: TOrderedCardinalList;
begin
  Result := FAccountsList;
end;

function TAccountsGrid.MoveRowToAccount(nAccount: Cardinal): Boolean;
var oal : TOrderedCardinalList;
  idx : Integer;
begin
  Result := false;
  if not Assigned(FDrawGrid) then exit;
  if not Assigned(Node) then exit;
  if FDrawGrid.RowCount<=1 then exit;
  if FShowAllAccounts then begin
    if (FDrawGrid.RowCount>nAccount+1) And (nAccount>=0) And (nAccount<Node.Bank.AccountsCount) then begin
      FDrawGrid.Row := nAccount+1;
      Result := true;
    end else begin
      FDrawGrid.Row := FDrawGrid.RowCount-1;
    end;
  end else begin
    oal := LockAccountsList;
    try
      if oal.Find(nAccount,idx) then begin
        if FDrawGrid.RowCount>idx+1 then begin
          FDrawGrid.Row := idx+1;
          Result := true;
        end else begin
          FDrawGrid.Row := FDrawGrid.RowCount-1;
        end;
      end else begin
        if FDrawGrid.RowCount>idx+1 then begin
          FDrawGrid.Row := idx+1;
        end else begin
          FDrawGrid.Row := FDrawGrid.RowCount-1;
        end;
      end;
    finally
      UnlockAccountsList;
    end;
  end;
end;

procedure TAccountsGrid.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation=opRemove then begin
    if (AComponent=FDrawGrid) then begin
      SetDrawGrid(nil);
    end;
  end;
end;

{$IFDEF FPC}
Type
TTextFormats = (tfBottom, tfCalcRect, tfCenter, tfEditControl, tfEndEllipsis,
  tfPathEllipsis, tfExpandTabs, tfExternalLeading, tfLeft, tfModifyString,
  tfNoClip, tfNoPrefix, tfRight, tfRtlReading, tfSingleLine, tfTop,
  tfVerticalCenter, tfWordBreak);
TTextFormat = set of TTextFormats;

procedure Canvas_TextRect(Canvas : TCanvas; var Rect: TRect; var Text: string; State: TGridDrawState; TextFormat: TTextFormat = []);
var ts : TTextStyle;
Begin
  if (tfRight in TextFormat) then ts.Alignment:=taRightJustify
  else if (tfCenter in TextFormat) then ts.Alignment:=taCenter
  else ts.Alignment:=taLeftJustify;
  if (tfWordBreak in TextFormat) then ts.Wordbreak:=true
  else ts.Wordbreak:=false;
  if (tfVerticalCenter in TextFormat) then ts.Layout:=tlCenter
  else if (tfBottom in TextFormat) then ts.Layout:=tlBottom
  else ts.Layout:=tlTop;
  ts.Clipping:=Not (tfNoClip in TextFormat);
  ts.SingleLine := (tfSingleLine in TextFormat);
  ts.Wordbreak:= (tfWordBreak in TextFormat);
  ts.EndEllipsis:= (tfEndEllipsis in TextFormat);
  ts.ExpandTabs:=false;
  ts.Opaque:=false;
  ts.ShowPrefix:= not (tfNoPrefix in TextFormat);
  ts.SystemFont:=false;
  Canvas.TextRect(Rect,Rect.Left,Rect.Top,Text,ts);
end;
{$ELSE}
procedure Canvas_TextRect(Canvas : TCanvas; var Rect: TRect; var Text: string; State: TGridDrawState; TextFormat: TTextFormat = []);
Begin
  Canvas.TextRect(Rect,Text,TextFormat);
end;
{$ENDIF}

procedure TAccountsGrid.OnGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
  function FromColorToColor(colorstart,colordest : Integer; step,totalsteps : Integer) : Integer;
  var sr,sg,sb,dr,dg,db : Byte;
    i : Integer;
  begin
    i := colorstart;
    sr := GetRValue(i);
    sg := GetGValue(i);
    sb := GetBValue(i);
    i := colordest;
    dr := GetRValue(i);
    dg := GetGValue(i);
    db := GetBValue(i);
    sr := sr + (((dr-sr) DIV totalsteps)*step);
    sg := sg + (((dg-sg) DIV totalsteps)*step);
    sb := sb + (((db-sb) DIV totalsteps)*step);
    Result :=RGB(sr,sg,sb);
  end;
var C : TAccountColumn;
  s : String;
  n_acc : Int64;
  account : TAccount;
  ndiff : Cardinal;
begin
  if not Assigned(Node) then exit;

  if (ACol>=0) and (ACol<length(FColumns)) then begin
    C := FColumns[ACol];
  end else begin
    C.ColumnType := act_account_number;
    C.width := -1;
  end;
  {.$IFDEF FPC}
  DrawGrid.Canvas.Font.Color:=clBlack;
  {.$ENDIF}
  if (ARow=0) then begin
    // Header
    s := CT_ColumnHeader[C.ColumnType];
    Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter]);
  end else begin
    n_acc := AccountNumber(ARow);
    if (n_acc>=0) then begin
      if (n_acc>=Node.Bank.AccountsCount) then account := CT_Account_NUL
      else account := Node.Operations.SafeBoxTransaction.Account(n_acc);
      ndiff := Node.Bank.BlocksCount - account.updated_block;
      if (gdSelected in State) then
        if (gdFocused in State) then DrawGrid.Canvas.Brush.Color := clGradientActiveCaption
        else DrawGrid.Canvas.Brush.Color := clGradientInactiveCaption
      else DrawGrid.Canvas.Brush.Color := clWindow;
      DrawGrid.Canvas.FillRect(Rect);
      InflateRect(Rect,-2,-1);
      case C.ColumnType of
        act_account_number : begin
          s := TAccountComp.AccountNumberToAccountTxtNumber(n_acc);
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
        end;
        act_account_key : begin
          s := Tcrypto.ToHexaString(TAccountComp.AccountKey2RawString(account.accountkey));
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter,tfSingleLine]);
        end;
        act_balance : begin
          if ndiff=0 then begin
            // Pending operation... showing final balance
            DrawGrid.Canvas.Font.Color := clBlue;
            s := '('+TAccountComp.FormatMoney(account.balance)+')';
          end else begin
            s := TAccountComp.FormatMoney(account.balance);
            if account.balance>0 then DrawGrid.Canvas.Font.Color := ClGreen
            else if account.balance=0 then DrawGrid.Canvas.Font.Color := clGrayText
            else DrawGrid.Canvas.Font.Color := clRed;
          end;
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
        end;
        act_updated : begin
          s := Inttostr(account.updated_block);
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
        end;
        act_n_operation : begin
          s := InttoStr(account.n_operation);
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
        end;
        act_updated_state : begin
          if TAccountComp.IsAccountBlockedByProtocol(account.account,Node.Bank.BlocksCount) then begin
            DrawGrid.Canvas.Brush.Color := clRed;
            DrawGrid.Canvas.Ellipse(Rect.Left+1,Rect.Top+1,Rect.Right-1,Rect.Bottom-1);
          end else if ndiff=0 then begin
            DrawGrid.Canvas.Brush.Color := RGB(255,128,0);
            DrawGrid.Canvas.Ellipse(Rect.Left+1,Rect.Top+1,Rect.Right-1,Rect.Bottom-1);
          end else if ndiff<=8 then begin
            DrawGrid.Canvas.Brush.Color := FromColorToColor(RGB(253,250,115),ColorToRGB(clGreen),ndiff-1,8-1);
            DrawGrid.Canvas.Ellipse(Rect.Left+1,Rect.Top+1,Rect.Right-1,Rect.Bottom-1);
          end else begin
            DrawGrid.Canvas.Brush.Color := clGreen;
            DrawGrid.Canvas.Ellipse(Rect.Left+1,Rect.Top+1,Rect.Right-1,Rect.Bottom-1);
          end;
        end;
      else
        s := '(???)';
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter,tfSingleLine]);
      end;
    end;
  end;
end;

procedure TAccountsGrid.OnNodeNewOperation(Sender: TObject);
begin
  if Assigned(FDrawGrid) then FDrawGrid.Invalidate;
end;

procedure TAccountsGrid.SaveToStream(Stream: TStream);
var c,i,j : Integer;
begin
  c := Length(FColumns);
  Stream.Write(c,sizeof(c));
  for i := 0 to c - 1 do begin
    j := Integer(FColumns[i].ColumnType);
    Stream.Write(j,sizeof(j));
    if Assigned(FDrawGrid) then begin
      FColumns[i].width := FDrawGrid.ColWidths[i];
    end;
    Stream.Write(FColumns[i].width,sizeof(FColumns[i].width));
  end;
  j := FDrawGrid.Width;
  Stream.Write(j,sizeof(j));
  j := FDrawGrid.Height;
  Stream.Write(j,sizeof(j));
end;

procedure TAccountsGrid.SetDrawGrid(const Value: TDrawGrid);
begin
  if FDrawGrid=Value then exit;
  FDrawGrid := Value;
  if Assigned(Value) then begin
    Value.FreeNotification(self);
    FDrawGrid.OnDrawCell := OnGridDrawCell;
    InitGrid;
  end;
end;

procedure TAccountsGrid.SetNode(const Value: TNode);
begin
  if GetNode=Value then exit;
  FNodeNotifyEvents.Node := Value;
  InitGrid;
end;

procedure TAccountsGrid.SetShowAllAccounts(const Value: Boolean);
begin
  if FShowAllAccounts=Value then exit;
  FShowAllAccounts := Value;
  InitGrid;
end;

procedure TAccountsGrid.UnlockAccountsList;
begin
  InitGrid;
end;

{ TOperationsGrid }

constructor TOperationsGrid.Create(AOwner: TComponent);
begin
  FAccountNumber := 0;
  FDrawGrid := nil;
  MustShowAlwaysAnAccount := false;
  FOperationsResume := TOperationsResumeList.Create;
  FNodeNotifyEvents := TNodeNotifyEvents.Create(Self);
  FNodeNotifyEvents.OnBlocksChanged := OnNodeNewAccount;
  FNodeNotifyEvents.OnOperationsChanged := OnNodeNewOperation;
  FBlockStart := -1;
  FBlockEnd := -1;
  FPendingOperations := false;
  inherited;
end;

destructor TOperationsGrid.Destroy;
begin
  FOperationsResume.Free;
  FNodeNotifyEvents.Free;
  inherited;
end;

function TOperationsGrid.GetNode: TNode;
begin
  Result := FNodeNotifyEvents.Node;
end;

procedure TOperationsGrid.InitGrid;
begin
  if not Assigned(FDrawGrid) then exit;
  if FOperationsResume.Count>0 then FDrawGrid.RowCount := FOperationsResume.Count+1
  else FDrawGrid.RowCount := 2;
  DrawGrid.FixedRows := 1;
  DrawGrid.DefaultDrawing := true;
  DrawGrid.FixedCols := 0;
  DrawGrid.ColCount := 8;
  DrawGrid.ColWidths[0] := 110; // Time
  DrawGrid.ColWidths[1] := 70; // Block/Op
  DrawGrid.ColWidths[2] := 60; // Account
  DrawGrid.ColWidths[3] := 180; // OpType
  DrawGrid.ColWidths[4] := 70; // Amount
  DrawGrid.ColWidths[5] := 60; // Operation Fee
  DrawGrid.ColWidths[6] := 80; // Balance
  DrawGrid.ColWidths[7] := 500; // Payload
  FDrawGrid.DefaultRowHeight := 18;
  FDrawGrid.Invalidate;
  DrawGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    {goRangeSelect, }goDrawFocusSelected, {goRowSizing, }goColSizing, {goRowMoving,}
    {goColMoving, goEditing, }goTabs, goRowSelect, {goAlwaysShowEditor,}
    goThumbTracking{$IFnDEF FPC}, goFixedColClick, goFixedRowClick, goFixedHotTrack{$ENDIF}];
end;

procedure TOperationsGrid.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation=opRemove then begin
    if (AComponent=FDrawGrid) then begin
      SetDrawGrid(nil);
    end;
  end;
end;

procedure TOperationsGrid.OnGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var s : String;
  opr : TOperationResume;
begin
  {.$IFDEF FPC}
  DrawGrid.Canvas.Font.Color:=clBlack;
  {.$ENDIF}
  opr := CT_TOperationResume_NUL;
  try
  if (ARow=0) then begin
    // Header
    case ACol of
      0 : s := 'Time';
      1 : s := 'Block/Op';
      2 : s := 'Account';
      3 : s := 'Operation';
      4 : s := 'Amount';
      5 : s := 'Fee';
      6 : s := 'Balance';
      7 : s := 'Payload';
    else s:= '';
    end;
    Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter]);
  end else begin
    if (gdSelected in State) then
      if (gdFocused in State) then DrawGrid.Canvas.Brush.Color := clGradientActiveCaption
      else DrawGrid.Canvas.Brush.Color := clGradientInactiveCaption
    else DrawGrid.Canvas.Brush.Color := clWindow;
    DrawGrid.Canvas.FillRect(Rect);
    InflateRect(Rect,-2,-1);
    if (ARow<=FOperationsResume.Count) then begin
      opr := FOperationsResume.OperationResume[ARow-1];
      if ACol=0 then begin
        if opr.time=0 then s := '(Pending)'
        else s := DateTimeToStr(UnivDateTime2LocalDateTime(UnixToUnivDateTime(opr.time)));
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfleft,tfVerticalCenter,tfSingleLine]);
      end else if ACol=1 then begin
        s := Inttostr(opr.Block);
        if opr.NOpInsideBlock>=0 then s := s + '/'+Inttostr(opr.NOpInsideBlock+1);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfleft,tfVerticalCenter,tfSingleLine]);
      end else if ACol=2 then begin
        s := TAccountComp.AccountNumberToAccountTxtNumber(opr.AffectedAccount);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfleft,tfVerticalCenter,tfSingleLine]);
      end else if ACol=3 then begin
        s := opr.OperationTxt;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfleft,tfVerticalCenter,tfSingleLine]);
      end else if ACol=4 then begin
        s := TAccountComp.FormatMoney(opr.Amount);
        if opr.Amount>0 then DrawGrid.Canvas.Font.Color := ClGreen
        else if opr.Amount=0 then DrawGrid.Canvas.Font.Color := clGrayText
        else DrawGrid.Canvas.Font.Color := clRed;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=5 then begin
        s := TAccountComp.FormatMoney(opr.Fee);
        if opr.Fee>0 then DrawGrid.Canvas.Font.Color := ClGreen
        else if opr.Fee=0 then DrawGrid.Canvas.Font.Color := clGrayText
        else DrawGrid.Canvas.Font.Color := clRed;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=6 then begin
        if opr.time=0 then begin
          // Pending operation... showing final balance
          DrawGrid.Canvas.Font.Color := clBlue;
          s := '('+TAccountComp.FormatMoney(opr.Balance)+')';
        end else begin
          s := TAccountComp.FormatMoney(opr.Balance);
          if opr.Balance>0 then DrawGrid.Canvas.Font.Color := ClGreen
          else if opr.Balance=0 then DrawGrid.Canvas.Font.Color := clGrayText
          else DrawGrid.Canvas.Font.Color := clRed;
        end;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=7 then begin
        s := opr.PrintablePayload;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter,tfSingleLine]);
      end else begin
        s := '(???)';
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter,tfSingleLine]);
      end;
    end;
  end;
  except
    on E:Exception do begin
      TLog.NewLog(lterror,Classname,Format('Error at OnGridDrawCell row %d col %d Block %d - %s',[ARow,ACol,opr.Block,E.Message]));
    end;
  end;
end;

procedure TOperationsGrid.OnNodeNewAccount(Sender: TObject);
begin
  if (AccountNumber<0) And (FBlockEnd<0) And (not FPendingOperations) then UpdateAccountOperations;
end;

procedure TOperationsGrid.OnNodeNewOperation(Sender: TObject);
var //Op : TPCOperation;
  l : TList;
begin
  try
    if (AccountNumber<0) then begin
      if (FPendingOperations) then UpdateAccountOperations;
    end else begin
      l := TList.Create;
      try
        if Node.Operations.OperationsHashTree.GetOperationsAffectingAccount(AccountNumber,l)>0 then begin
          if l.IndexOf(TObject(PtrInt(AccountNumber)))>=0 then UpdateAccountOperations;
        end;
      finally
        l.Free;
      end;
    end;
  except
    on E:Exception do begin
      E.message := 'Exception on updating OperationsGrid '+inttostr(AccountNumber)+': '+E.Message;
      raise;
    end;
  end;
end;

procedure TOperationsGrid.SetAccountNumber(const Value: Int64);
begin
  if FAccountNumber=Value then exit;
  FAccountNumber := Value;
  if FAccountNumber>=0 then FPendingOperations := false;
  UpdateAccountOperations;
end;

procedure TOperationsGrid.SetBlockEnd(const Value: Int64);
begin
  FBlockEnd := Value;
end;

procedure TOperationsGrid.SetBlocks(bstart, bend: Int64);
begin
  if (bstart=FBlockStart) And (bend=FBlockEnd) then exit;
  FBlockStart := bstart;
  FBlockEnd := bend;
  if (FBlockEnd>0) And (FBlockStart>FBlockEnd) then FBlockStart := -1;
  FAccountNumber := -1;
  FPendingOperations := false;
  UpdateAccountOperations;
end;

procedure TOperationsGrid.SetBlockStart(const Value: Int64);
begin
  FBlockStart := Value;
end;

procedure TOperationsGrid.SetDrawGrid(const Value: TDrawGrid);
begin
  if FDrawGrid=Value then exit;
  FDrawGrid := Value;
  if Assigned(Value) then begin
    Value.FreeNotification(self);
    FDrawGrid.OnDrawCell := OnGridDrawCell;
    InitGrid;
  end;
end;

procedure TOperationsGrid.SetMustShowAlwaysAnAccount(const Value: Boolean);
begin
  if FMustShowAlwaysAnAccount=Value then exit;
  FMustShowAlwaysAnAccount := Value;
  UpdateAccountOperations;
end;

procedure TOperationsGrid.SetNode(const Value: TNode);
begin
  if GetNode=Value then exit;
  FNodeNotifyEvents.Node := Value;
  UpdateAccountOperations; // New Build 1.0.3
end;

procedure TOperationsGrid.SetPendingOperations(const Value: Boolean);
begin
  FPendingOperations := Value;
  if FPendingOperations then  FAccountNumber := -1;
  UpdateAccountOperations;
end;

procedure TOperationsGrid.ShowModalDecoder(WalletKeys: TWalletKeys; AppParams : TAppParams);
var
  opr : TOperationResume;
  FRM : TFRMPayloadDecoder;
begin
  if not Assigned(FDrawGrid) then exit;
  if (FDrawGrid.Row<=0) Or (FDrawGrid.Row>FOperationsResume.Count) then exit;
  opr := FOperationsResume.OperationResume[FDrawGrid.Row-1];
  FRM := TFRMPayloadDecoder.Create(FDrawGrid.Owner);
  try
    FRM.Init(opr,WalletKeys,AppParams);
    FRM.ShowModal;
  finally
    FRM.Free;
  end;
end;

procedure TOperationsGrid.UpdateAccountOperations;
var list : TList;
  i : Integer;
  OPR : TOperationResume;
  Op : TPCOperation;
  opc : TPCOperationsComp;
  bstart,bend : int64;
begin
  FOperationsResume.Clear;
  try
    if not Assigned(Node) then exit;
    if (MustShowAlwaysAnAccount) And (AccountNumber<0) then exit;

    if FPendingOperations then begin
      for i := Node.Operations.Count - 1 downto 0 do begin
        Op := Node.Operations.OperationsHashTree.GetOperation(i);
        if TPCOperation.OperationToOperationResume(0,Op,Op.SenderAccount,OPR) then begin
          OPR.NOpInsideBlock := i;
          OPR.Block := Node.Operations.OperationBlock.block;
          OPR.Balance := Node.Operations.SafeBoxTransaction.Account(Op.SenderAccount).balance;
          FOperationsResume.Add(OPR);
        end;
      end;
    end else begin
      if AccountNumber<0 then begin
        opc := TPCOperationsComp.Create(nil);
        try
          opc.bank := Node.Bank;
          if FBlockEnd<0 then begin
            if Node.Bank.BlocksCount>0 then bend := Node.Bank.BlocksCount-1
            else bend := 0;
          end else bend := FBlockEnd;
          if FBlockStart<0 then begin
            if (bend > 300) then bstart := bend - 300
            else bstart := 0;
          end else bstart:= FBlockStart;
          if bstart<0 then bstart := 0;
          if bend>=Node.Bank.BlocksCount then bend:=Node.Bank.BlocksCount;
          while (bstart<=bend) do begin
            opr := CT_TOperationResume_NUL;
            if (Node.Bank.Storage.LoadBlockChainBlock(opc,bend)) then begin
              // Reward operation
              OPR := CT_TOperationResume_NUL;
              OPR.valid := true;
              OPR.Block := bend;
              OPR.time := opc.OperationBlock.timestamp;
              OPR.AffectedAccount := bend * CT_AccountsPerBlock;
              OPR.Amount := opc.OperationBlock.reward;
              OPR.Fee := opc.OperationBlock.fee;
              OPR.Balance := OPR.Amount+OPR.Fee;
              OPR.OperationTxt := 'Blockchain reward';
              FOperationsResume.Add(OPR);
              // Reverse operations inside a block
              for i := opc.Count - 1 downto 0 do begin
                if TPCOperation.OperationToOperationResume(bend,opc.Operation[i],opc.Operation[i].SenderAccount,opr) then begin
                  opr.NOpInsideBlock := i;
                  opr.Block := bend;
                  opr.time := opc.OperationBlock.timestamp;
                  FOperationsResume.Add(opr);
                end;
              end;
            end else break;
            dec(bend);
          end;
        finally
          opc.Free;
        end;

      end else begin
        list := TList.Create;
        try
          Node.Operations.OperationsHashTree.GetOperationsAffectingAccount(AccountNumber,list);
          for i := list.Count - 1 downto 0 do begin
            Op := Node.Operations.OperationsHashTree.GetOperation(PtrInt(list[i]));
            if TPCOperation.OperationToOperationResume(0,Op,AccountNumber,OPR) then begin
              OPR.NOpInsideBlock := i;
              OPR.Block := Node.Operations.OperationBlock.block;
              OPR.Balance := Node.Operations.SafeBoxTransaction.Account(AccountNumber).balance;
              FOperationsResume.Add(OPR);
            end;
          end;
        finally
          list.Free;
        end;
        Node.GetStoredOperationsFromAccount(FOperationsResume,AccountNumber,100,5000);
      end;
    end;
  finally
    InitGrid;
  end;
end;

{ TBlockChainGrid }

constructor TBlockChainGrid.Create(AOwner: TComponent);
begin
  inherited;
  FBlockStart:=-1;
  FBlockEnd:=-1;
  FMaxBlocks := 300;
  FDrawGrid := nil;
  FNodeNotifyEvents := TNodeNotifyEvents.Create(Self);
  FNodeNotifyEvents.OnBlocksChanged := OnNodeNewAccount;
  FHashRateAverageBlocksCount := 50;
  SetLength(FBlockChainDataArray,0);
end;

destructor TBlockChainGrid.Destroy;
begin
  FNodeNotifyEvents.OnBlocksChanged := nil;
  FNodeNotifyEvents.Node := nil;
  FreeAndnil(FNodeNotifyEvents);
  inherited;
end;

function TBlockChainGrid.GetNode: TNode;
begin
  Result := FNodeNotifyEvents.Node;
end;


procedure TBlockChainGrid.InitGrid;
begin
  if not Assigned(FDrawGrid) then exit;
  FDrawGrid.RowCount := 2;
  DrawGrid.FixedRows := 1;
  DrawGrid.DefaultDrawing := true;
  DrawGrid.FixedCols := 0;
  DrawGrid.ColCount := 13;
  DrawGrid.ColWidths[0] := 50; // Block
  DrawGrid.ColWidths[1] := 110; // Time
  DrawGrid.ColWidths[2] := 30; // Ops
  DrawGrid.ColWidths[3] := 80; // Volume
  DrawGrid.ColWidths[4] := 50; // Reward
  DrawGrid.ColWidths[5] := 50; // Fee
  DrawGrid.ColWidths[6] := 60; // Target
  DrawGrid.ColWidths[7] := 80; // Hash Rate
  DrawGrid.ColWidths[8] := 190; // Miner Payload
  DrawGrid.ColWidths[9] := 190; // PoW
  DrawGrid.ColWidths[10] := 190; // SafeBox Hash
  DrawGrid.ColWidths[11] := 50; // Protocol
  DrawGrid.ColWidths[12] := 120; // Accumulated work
  FDrawGrid.DefaultRowHeight := 18;
  FDrawGrid.Invalidate;
  DrawGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    {goRangeSelect, }goDrawFocusSelected, {goRowSizing, }goColSizing, {goRowMoving,}
    {goColMoving, goEditing, }goTabs, goRowSelect, {goAlwaysShowEditor,}
    goThumbTracking{$IFnDEF FPC}, goFixedColClick, goFixedRowClick, goFixedHotTrack{$ENDIF}];
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  if Operation=opRemove then begin
    if (AComponent=FDrawGrid) then begin
      SetDrawGrid(nil);
    end;
  end;
end;

procedure TBlockChainGrid.OnGridDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var s : String;
  bcd : TBlockChainData;
begin
  {.$IFDEF FPC}
  DrawGrid.Canvas.Font.Color:=clBlack;
  {.$ENDIF}
  if (ARow=0) then begin
    // Header
    case ACol of
      0 : s := 'Block';
      1 : s := 'Time';
      2 : s := 'Ops';
      3 : s := 'Volume';
      4 : s := 'Reward';
      5 : s := 'Fee';
      6 : s := 'Target';
      7 : s := 'Mh/s';
      8 : s := 'Miner Payload';
      9 : s := 'Proof of Work';
      10 : s := 'SafeBox Hash';
      11 : s := 'Protocol';
      12 : s := 'Acc.Work';
    else s:= '';
    end;
    Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter]);
  end else begin
    if (gdSelected in State) then
      if (gdFocused in State) then DrawGrid.Canvas.Brush.Color := clGradientActiveCaption
      else DrawGrid.Canvas.Brush.Color := clGradientInactiveCaption
    else DrawGrid.Canvas.Brush.Color := clWindow;
    DrawGrid.Canvas.FillRect(Rect);
    InflateRect(Rect,-2,-1);
    if ((ARow-1)<=High(FBlockChainDataArray)) then begin
      bcd := FBlockChainDataArray[ARow-1];
      if ACol=0 then begin
        s := IntToStr(bcd.Block);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter]);
      end else if ACol=1 then begin
        s := DateTimeToStr(UnivDateTime2LocalDateTime(UnixToUnivDateTime((bcd.Timestamp))));
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfleft,tfVerticalCenter,tfSingleLine]);
      end else if ACol=2 then begin
        s := IntToStr(bcd.OperationsCount);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter]);
      end else if ACol=3 then begin
        s := TAccountComp.FormatMoney(bcd.Volume);
        if FBlockChainDataArray[ARow-1].Volume>0 then DrawGrid.Canvas.Font.Color := ClGreen
        else DrawGrid.Canvas.Font.Color := clGrayText;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=4 then begin
        s := TAccountComp.FormatMoney(bcd.Reward);
        if FBlockChainDataArray[ARow-1].Reward>0 then DrawGrid.Canvas.Font.Color := ClGreen
        else DrawGrid.Canvas.Font.Color := clGrayText;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=5 then begin
        s := TAccountComp.FormatMoney(bcd.Fee);
        if bcd.Fee>0 then DrawGrid.Canvas.Font.Color := ClGreen
        else DrawGrid.Canvas.Font.Color := clGrayText;
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
      end else if ACol=6 then begin
        s := IntToHex(bcd.Target,8);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter]);
      end else if ACol=7 then begin
        s := Format('%.2n',[bcd.HashRateKhs/1024]);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter]);
      end else if ACol=8 then begin
        if TCrypto.IsHumanReadable(bcd.MinerPayload) then
          s := bcd.MinerPayload
        else s := TCrypto.ToHexaString( bcd.MinerPayload );
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter]);
      end else if ACol=9 then begin
        s := TCrypto.ToHexaString(bcd.PoW);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter]);
      end else if ACol=10 then begin
        s := TCrypto.ToHexaString(bcd.SafeBoxHash);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter]);
      end else if ACol=11 then begin
        s := Inttostr(bcd.BlockProtocolVersion)+'-'+IntToStr(bcd.BlockProtocolAvailable);
        Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter,tfSingleLine]);
      end else if ACol=12 then begin
        if bcd.AccumulatedWork>0 then begin
          s := Inttostr(bcd.AccumulatedWork);
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter]);
        end else begin
          DrawGrid.Canvas.Font.Color := clGrayText;
          s := '(no data)';
          Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfCenter,tfVerticalCenter,tfSingleLine]);
        end;
      end;
    end;
  end;
end;


procedure TBlockChainGrid.OnNodeNewAccount(Sender: TObject);
begin
  if FBlockEnd<0 then UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.SetBlockEnd(const Value: Int64);
begin
  if FBlockEnd=Value then exit;
  FBlockEnd := Value;
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.SetBlocks(bstart, bend: Int64);
begin
  if (FBlockStart=bstart) And (FBlockEnd=bend) then exit;
  FBlockStart := bstart;
  FBlockEnd := bend;
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.SetBlockStart(const Value: Int64);
begin
  if FBlockStart=Value then exit;
  FBlockStart := Value;
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.SetDrawGrid(const Value: TDrawGrid);
begin
  if FDrawGrid=Value then exit;
  FDrawGrid := Value;
  if Assigned(Value) then begin
    Value.FreeNotification(self);
    FDrawGrid.OnDrawCell := OnGridDrawCell;
    InitGrid;
  end;
end;


procedure TBlockChainGrid.SetHashRateAverageBlocksCount(const Value: Integer);
begin
  if FHashRateAverageBlocksCount=Value then exit;
  FHashRateAverageBlocksCount := Value;
  if FHashRateAverageBlocksCount<1 then FHashRateAverageBlocksCount := 1;
  if FHashRateAverageBlocksCount>1000 then FHashRateAverageBlocksCount := 1000;
  UpdateBlockChainGrid;
end;

procedure TBlockChainGrid.SetMaxBlocks(const Value: Integer);
begin
  if FMaxBlocks=Value then exit;
  FMaxBlocks := Value;
  if (FMaxBlocks<=0) Or (FMaxBlocks>500) then FMaxBlocks := 300;
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.SetNode(const Value: TNode);
begin
  FNodeNotifyEvents.Node := Value;
  UpdateBlockChainGrid;
end;


procedure TBlockChainGrid.UpdateBlockChainGrid;
var nstart,nend : Cardinal;
  opc : TPCOperationsComp;
  bcd : TBlockChainData;
  i : Integer;
begin
  if (FBlockStart>FBlockEnd) And (FBlockStart>=0) then FBlockEnd := -1;
  if (FBlockEnd>=0) And (FBlockEnd<FBlockStart) then FBlockStart:=-1;

  if not Assigned(FNodeNotifyEvents.Node) then exit;

  if FBlockStart>(FNodeNotifyEvents.Node.Bank.BlocksCount-1) then FBlockStart := -1;

  try
    if Node.Bank.BlocksCount<=0 then begin
      SetLength(FBlockChainDataArray,0);
      exit;
    end;
    if (FBlockEnd>=0) And (FBlockEnd<Node.Bank.BlocksCount) then begin
      nend := FBlockEnd
    end else begin
      if (FBlockStart>=0) And (FBlockStart+MaxBlocks<=Node.Bank.BlocksCount) then nend := FBlockStart + MaxBlocks - 1
      else nend := Node.Bank.BlocksCount-1;
    end;

    if (FBlockStart>=0) And (FBlockStart<Node.Bank.BlocksCount) then nstart := FBlockStart
    else begin
      if nend>MaxBlocks then nstart := nend - MaxBlocks + 1
      else nstart := 0;
    end;
    SetLength(FBlockChainDataArray,nend - nstart +1);
    opc := TPCOperationsComp.Create(nil);
    try
      opc.bank := Node.Bank;
      while (nstart<=nend) do begin
        i := length(FBlockChainDataArray) - (nend-nstart+1);
        bcd := CT_TBlockChainData_NUL;
        if (Node.Bank.LoadOperations(opc,nend)) then begin
          bcd.Block := opc.OperationBlock.block;
          bcd.Timestamp := opc.OperationBlock.timestamp;
          bcd.BlockProtocolVersion := opc.OperationBlock.protocol_version;
          bcd.BlockProtocolAvailable := opc.OperationBlock.protocol_available;
          bcd.OperationsCount := opc.Count;
          bcd.Volume := opc.OperationsHashTree.TotalAmount + opc.OperationsHashTree.TotalFee;
          bcd.Reward := opc.OperationBlock.reward;
          bcd.Fee := opc.OperationBlock.fee;
          bcd.Target := opc.OperationBlock.compact_target;
          bcd.HashRateKhs := Node.Bank.SafeBox.CalcBlockHashRateInKhs(bcd.Block,HashRateAverageBlocksCount);
          bcd.MinerPayload := opc.OperationBlock.block_payload;
          bcd.PoW := opc.OperationBlock.proof_of_work;
          bcd.SafeBoxHash := opc.OperationBlock.initial_safe_box_hash;
          bcd.AccumulatedWork := Node.Bank.SafeBox.Block(bcd.Block).AccumulatedWork;
        end;
        FBlockChainDataArray[i] := bcd;
        if (nend>0) then dec(nend) else break;
      end;
    finally
      opc.Free;
    end;
  finally
    if Assigned(FDrawGrid) then begin
      if Length(FBlockChainDataArray)>0 then FDrawGrid.RowCount := length(FBlockChainDataArray)+1
      else FDrawGrid.RowCount := 2;
      FDrawGrid.Invalidate;
    end;
  end;
end;

end.
