/**
  Module: skills/rendercv-rendercvskill.nix
  URL: https://github.com/rendercv/rendercv-skill
  Description: AI agent skill for RenderCV
*/
{
  inputs,
  homeDir,
  ...
}:
let
  srcDir = inputs.rendercv-rendercvSkill;
  targetDir = "${homeDir}/.agents";
in
{
  systemd.tmpfiles.rules = map (
    name: "L+ ${targetDir}/skills/${name} - - - - ${srcDir}/skills/${name}"
  ) (builtins.attrNames (builtins.readDir "${srcDir}/skills"));
}
