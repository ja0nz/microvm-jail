/**
  Module: skills/resumx.nix
  URL: https://github.com/resumx/skills
  Description: Resume writing skills
*/
{
  inputs,
  homeDir,
  ...
}:
let
  dataDir = "${homeDir}/.agents";
  skills = "${inputs.resumx-skills}/skills";
in
{
  systemd.tmpfiles.rules = map (name: "L+ ${dataDir}/skills/${name} - - - - ${skills}/${name}") (
    builtins.attrNames (builtins.readDir skills)
  );
}
