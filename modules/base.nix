/**
  Module: base.nix
  Description: Basic microvm configuration

  Consume with:
    microvm-base = {
      id = 1;
      name = "my-microvm1";
    };
*/
{ config, lib, ... }:
let
  cfg = config.microvm-base;

  # Derive MAC from name — deterministic, no collision risk
  hash = builtins.hashString "sha256" cfg.name;
  c = off: builtins.substring off 2 hash;
  mac = "02:${c 0}:${c 2}:${c 4}:${c 6}:${c 8}";

  tapId = "mvm-${toString cfg.id}";
  imgId = "var-${toString cfg.id}.img";
  vsockCid = 3 + cfg.id;
in
{
  options.microvm-base = {
    id = lib.mkOption {
      type = lib.types.int;
      description = "Unique VM index (affects tapId and vsockCid)";
    };
    name = lib.mkOption {
      type = lib.types.str;
      description = "Hostname and MAC seed";
    };
  };

  config = {
    system.stateVersion = "24.05";
    networking.hostName = cfg.name;

    systemd.network.enable = true;
    users.users.root.password = "";
    users.users.root.openssh.authorizedKeys.keys = [
      (builtins.readFile ../ident.pub)
    ];
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
      };
    };

    microvm = {
      hypervisor = "qemu";
      socket = "control.socket";
      vcpu = 2;
      mem = 1024;
      volumes = [
        {
          mountPoint = "/var";
          image = imgId;
          size = 256;
        }
      ];
      shares = [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
      ];
      interfaces = [
        {
          type = "tap";
          inherit mac;
          id = tapId;
        }
      ];
      vsock.cid = vsockCid;
    };
  };
}
