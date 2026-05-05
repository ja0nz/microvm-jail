/**
  Module: beta.nix
  Description: VM
*/
{
  config,
  homeDir,
  ...
}:
let
  # dataDir = "/root/.pi";
  authConfig = {
    openrouter = {
      type = "api_key";
      key = config.sops.placeholder."openrouter_api_key";
    };
  };

in
{
  imports = [
    ../skills/caveman.nix
    #../skills/resumx.nix
    ../skills/addyosmani-skills.nix
    ../skills/rendercv-rendercvskill.nix
    # ../skills/resumeskills.nix
    ../pi-mono
  ];

  # SOPS-NIX
  sops.secrets."openrouter_api_key" = { };
  sops.templates."agent-auth.json".content = builtins.toJSON authConfig;

  microvm = {
    # ln -s manually some shared directories to operate on
    shares = [
      {
        proto = "virtiofs";
        tag = "shares";
        source = "/home/me/git/typstCV";
        mountPoint = "${homeDir}/cv";
      }
    ];
  };
}
