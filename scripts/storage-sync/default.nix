{ pkgs, ... }:

let
  storageSyncScript = pkgs.writeShellScriptBin "storage-sync" (builtins.readFile ./storage-sync.sh);
in
{
  environment.systemPackages = [
    storageSyncScript
    pkgs.curl
  ];
}
