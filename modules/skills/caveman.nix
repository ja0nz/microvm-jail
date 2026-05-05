/**
  Module: skills/caveman.nix
  URL: https://github.com/JuliusBrussee/caveman
  Description: Silence LLMs, save tokens
*/
{
  inputs,
  homeDir,
  ...
}:
let
  srcDir = inputs.juliusbrussee-caveman;
  targetDir = "${homeDir}/.agents";
  skills = [
    "caveman" # lite | full (default) | ultra
    "caveman-commit" # Ultra-compressed commit message generator
    "caveman-review" # Ultra-compressed code review comments
    "compress" # Compress project memory files (CLAUDE.md, etc.)
  ];
in
{
  systemd.tmpfiles.rules = map (
    name: "L+ ${targetDir}/skills/${name} - - - - ${srcDir}/skills/${name}"
  ) skills;
}
