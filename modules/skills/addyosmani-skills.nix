/**
  Module: skills/addyosmani-skills.nix
  URL: https://github.com/addyosmani/agent-skills
  Description: Production level coding skills
*/
{
  inputs,
  homeDir,
  ...
}:
let
  srcDir = inputs.addyosmani-agentSkills;
  targetDir = "${homeDir}/.agents";
in
{
  systemd.tmpfiles.rules = map (
    name: "L+ ${targetDir}/skills/${name} - - - - ${srcDir}/skills/${name}"
  ) (builtins.attrNames (builtins.readDir "${srcDir}/skills"));
}
