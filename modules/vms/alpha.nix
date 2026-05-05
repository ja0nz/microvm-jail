/**
  Module: alpha.nix
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
    ../skills/addyosmani-skills.nix
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
        tag = "org";
        source = "/home/me/Documents/org";
        mountPoint = "${homeDir}/org";
      }
      {
        proto = "virtiofs";
        tag = "kick.d";
        source = "/home/me/emacs/kick.d";
        mountPoint = "${homeDir}/emacs";
      }
    ];
  };
}
