/**
  Module: pi-mono/extensions/inherit-ownership
  Description: Apply ownership according to parent directory
*/
{
  pkgs,
  ...
}:
let
  dataDir = "/root/.pi";
  ext = "inherit-ownership.ts";
  inheritOwnership = pkgs.writeText ext (builtins.readFile ./inherit-ownership.ts);
in
{
  systemd.tmpfiles.rules = [
    "L+ ${dataDir}/extensions/${ext} - - - - ${inheritOwnership}"
  ];
}
