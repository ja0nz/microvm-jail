/**
  Module: pi-mono/extensions/inherit-ownership
  Description: Apply ownership according to parent directory
*/
{
  pkgs,
  homeDir,
  ...
}:
let
  dataDir = "${homeDir}/.pi";
  ext = "inherit-ownership.ts";
  exe = pkgs.writeText ext (builtins.readFile ./inherit-ownership_v1.ts);
in
{
  systemd.tmpfiles.rules = [
    "L+ ${dataDir}/extensions/${ext} - - - - ${exe}"
  ];
}
