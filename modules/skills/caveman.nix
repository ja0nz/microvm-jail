/**
  Module: skills/caveman.nix
  URL: https://github.com/JuliusBrussee/caveman
  Description: Silence LLMs, save tokens
*/
{
  inputs,
  ...
}:
let
  dataDir = "/root/.agents";
  cavemanSkills = [
    "caveman"
    "caveman-commit"
    "caveman-review"
    "compress"
  ];
in
{
  systemd.tmpfiles.rules = map (
    name: "L+ ${dataDir}/skills/${name} - - - - ${inputs.caveman}/skills/${name}"
  ) cavemanSkills;
}
