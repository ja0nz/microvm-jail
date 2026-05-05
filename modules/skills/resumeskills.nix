/**
  Module: skills/resumeskills.nix
  URL: https://github.com/Paramchoudhary/ResumeSkills
  Description: Resume writing skills
*/
{
  inputs,
  homeDir,
  ...
}:
let
  dataDir = "${homeDir}/.agents";
  skills = "${inputs.paramchoudhary-resumeSkills}/skills";
in
{
  systemd.tmpfiles.rules = map (name: "L+ ${dataDir}/skills/${name} - - - - ${skills}/${name}") (
    builtins.attrNames (builtins.readDir skills)
  );
}
