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

  cavemanSkills = [
    "caveman"
    "caveman-commit"
    "caveman-review"
    "compress"
  ];
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
    # Map caveman skills to etc/pi/skills
    etc = builtins.listToAttrs (
      map (name: {
        name = "pi/skills/${name}";
        value.source = "${inputs.caveman}/skills/${name}";
      }) cavemanSkills
    );
  };
  # Symlink etc -> var
  systemd.tmpfiles.rules = map (
    name: "L ${dataDir}/skills/${name} - - - - /etc/pi/skills/${name}"
  ) cavemanSkills;

  microvm = {
    # ln -s manually some shared directories to operate on
    shares = [
      {
        proto = "virtiofs";
        tag = "shares";
        source = "shares";
        mountPoint = "/root/shares";
      }
    ];
  };
}
