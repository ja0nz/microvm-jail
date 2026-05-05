/**
  Module: base.nix
  Description: Basic microvm configuration

  Consume with:
    microvm-base = {
      id = 1;
      name = "my-microvm1";
    };
*/
{
  config,
  lib,
  persistDir,
  ...
}:
let
  cfg = config.microvm-base;

  # Derive MAC from name — deterministic, no collision risk
  hash = builtins.hashString "sha256" cfg.name;
  c = off: builtins.substring off 2 hash;
  mac = "02:${c 0}:${c 2}:${c 4}:${c 6}:${c 8}";

  tapId = "mvm-${toString cfg.id}";
  imgId = "var-${toString cfg.id}.img";
  vsockCid = 3 + cfg.id;

  # Secret mount (check vm-create task in ../scripts/default.nix)
  secretDir = "/etc/age";
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
    # SOPS-NIX
    fileSystems."${secretDir}".neededForBoot = true;
    sops = {
      defaultSopsFormat = "yaml";
      defaultSopsFile = ../secrets.enc.yaml;
      age.keyFile = "${secretDir}/keys.txt";
    };

    # PRESERVATION
    fileSystems."${persistDir}".neededForBoot = true;
    preservation = {
      enable = true;
      preserveAt."${persistDir}" = {
        directories = [
          "/var/lib/systemd/timers"
          # NixOS user state
          "/var/lib/nixos"
          "/var/log"
        ];
      };
    };

    # NIX config
    system.stateVersion = "24.05";
    time.timeZone = "Europe/Berlin";
    networking.hostName = cfg.name;
    nix = {
      nixPath = [ ];
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    systemd.network.enable = true;
    boot.kernelParams = [ "systemd.machine_id=${builtins.hashString "md5" cfg.name}" ];
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

    environment = {
      # systemPackages = with pkgs; [
      #   comma
      # ];
      shellAliases = {
        sd = "sudo shutdown now";
        root = "sudo -s";
        ".." = "cd ..";
      };
    };
    microvm = {
      hypervisor = "qemu";
      socket = "control.socket";
      vcpu = 2;
      mem = 1024;
      # For comma
      writableStoreOverlay = "/nix/.rw-store";
      volumes = [
        {
          mountPoint = persistDir;
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
          readOnly = true;
        }
        {
          proto = "virtiofs";
          tag = "age-key";
          source = "age-key";
          mountPoint = "${secretDir}";
          readOnly = true;
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
