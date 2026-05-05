/**
  Module: pi-mono/default.nix
  Description: PI mono basics
*/
{
  inputs,
  pkgs,
  system,
  persistDir,
  homeDir,
  ...
}:
let
  agents = inputs.llm-agents.packages.${system};
  dataDir = "${homeDir}/.pi";
  agentsMd = pkgs.writeText "AGENTS.md" (builtins.readFile ./AGENTS.md);
in
{
  imports = [
    ./extensions/inherit-ownership
  ];

  # SOPS-NIX
  sops.templates."agent-auth.json" = {
    mode = "0600";
    path = "${persistDir}${dataDir}/auth.json";
  };

  # PRESERVATION
  preservation.preserveAt."${persistDir}".directories = [
    dataDir
  ];

  environment = {
    systemPackages = [
      agents.pi
    ];
    variables = {
      PI_CODING_AGENT_DIR = dataDir;
    };
  };

  systemd.tmpfiles.rules = [
    "L+ ${dataDir}/AGENTS.md - - - - ${agentsMd}"
  ];
}
