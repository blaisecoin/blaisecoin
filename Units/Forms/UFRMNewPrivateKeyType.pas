{
  Copyright (c) 2016 by Albert Molina
  Copyright (c) 2017 by BlaiseCoin developers

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  This unit is a part of BlaiseCoin, a P2P crypto-currency.
}

unit UFRMNewPrivateKeyType;

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
  Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons, ExtCtrls, UWalletKeys,UCrypto;

type
  TFRMNewPrivateKeyType = class(TForm)
    Label1: TLabel;
    ebName: TEdit;
    rgKeyType: TRadioGroup;
    bbOk: TBitBtn;
    bbCancel: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure bbOkClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FWalletKeys: TWalletKeys;
    FGeneratedPrivateKey: TECPrivateKey;
    procedure SetWalletKeys(const Value: TWalletKeys);
    { Private declarations }
  public
    { Public declarations }
    property WalletKeys : TWalletKeys read FWalletKeys write SetWalletKeys;
    property GeneratedPrivateKey : TECPrivateKey read FGeneratedPrivateKey write FGeneratedPrivateKey;
  end;


implementation

uses
  UAccounts, UConst ;

{$IFnDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}

procedure TFRMNewPrivateKeyType.bbOkClick(Sender: TObject);
begin
  if not Assigned(WalletKeys) then exit;
  if rgKeyType.ItemIndex<0 then raise Exception.Create('Select a key type');

  if Assigned(FGeneratedPrivateKey) then FGeneratedPrivateKey.Free;

  FGeneratedPrivateKey := TECPrivateKey.Create;
  FGeneratedPrivateKey.GenerateRandomPrivateKey( PtrInt(rgKeyType.Items.Objects[rgKeyType.ItemIndex]) );
  WalletKeys.AddPrivateKey(ebName.Text,FGeneratedPrivateKey);
  ModalResult := MrOk;
end;

procedure TFRMNewPrivateKeyType.FormCreate(Sender: TObject);
var l : TList;
  i : Integer;
begin
  FGeneratedPrivateKey := Nil;
  FWalletKeys := Nil;
  ebName.Text := DateTimeToStr(now);
  rgKeyType.Items.Clear;
  l := TList.Create;
  try
    TAccountComp.ValidsEC_OpenSSL_NID(l);
    for i := 0 to l.Count - 1 do begin
      rgKeyType.Items.AddObject(TAccountComp.GetECInfoTxt(PtrInt(l[i])),l[i]);
    end;
  finally
    l.free;
  End;
end;

procedure TFRMNewPrivateKeyType.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FGeneratedPrivateKey);
end;

procedure TFRMNewPrivateKeyType.SetWalletKeys(const Value: TWalletKeys);
begin
  FWalletKeys := Value;
end;

end.
