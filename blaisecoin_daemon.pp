program blaisecoin_daemon;

{$mode objfpc}{$H+}
{$define usecthreads}
{$apptype gui}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  sysutils,
  Classes, daemonapp,
  UCrypto, upcdaemon;


begin
  Application.Title:='BlaiseCoin Daemon application';
  RegisterDaemonClass(TPCDaemon);
  RegisterDaemonMapper(TPCDaemonMapper);
  TCrypto.InitCrypto;
  Application.Run;
end.

