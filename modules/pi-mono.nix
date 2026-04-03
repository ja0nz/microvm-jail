/**
  Module: pi-mono.nix
  Description: PI mono & OpenRouter
*/
{
  inputs,
  system,
  persistDir,
  config,
  ...
}:
let
  agents = inputs.llm-agents.packages.${system};
  dataDir = "/var/pi";
  authConfig = {
    openrouter = {
      type = "api_key";
      key = config.sops.placeholder."openrouter_api_key";
    };
  };
in
{
  # SOPS-NIX
  sops.secrets."openrouter_api_key" = { };
  sops.templates."agent-auth.json" = {
    content = builtins.toJSON authConfig;
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

  microvm = {
    # ln -s manually some shared directories to operate on
    shares = [
      {
        proto = "virtiofs";
        tag = "pitest";
        source = "pitest";
        mountPoint = "/mnt/pitest";
      }
    ];
  };
}
