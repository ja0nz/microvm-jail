{
  description = "VM jail for agents and the like";
  nixConfig = {
    extra-substituters = [
      "https://microvm.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    preservation.url = "github:nix-community/preservation";
    # Non flakes
    caveman = {
      url = "github:JuliusBrussee/caveman";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      sops-nix,
      microvm,
      preservation,
      ...
    }:
    let
      system = "x86_64-linux";
      vmList = [
        {
          name = "pi-mono";
          modules = [ ./modules/pi-mono.nix ];
        }
        # {
        #   name = "my-microvm2";
        #   modules = [ ./modules/extra.nix ];
        # }
      ];
      mkVM =
        id:
        { name, modules }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            inherit system;
            persistDir = "/persistent";
          };
          modules = [
            microvm.nixosModules.microvm
            sops-nix.nixosModules.sops
            preservation.nixosModules.preservation
            ./modules/base.nix
            { microvm-base = { inherit id name; }; }
          ]
          ++ modules;
        };
      vms = builtins.listToAttrs (
        nixpkgs.lib.imap1 (id: vm: {
          inherit (vm) name;
          value = mkVM id vm;
        }) vmList
      );
      pkgs = nixpkgs.legacyPackages.${system};
      scripts = import ./scripts { inherit pkgs system inputs; };
    in
    {
      nixosConfigurations = vms;
      packages.${system} = builtins.mapAttrs (
        _: vm: vm.config.microvm.runner.${vm.config.microvm.hypervisor}
      ) self.nixosConfigurations;

      formatter.x86_64-linux = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        packages =
          with pkgs;
          [
            deadnix
            prek
            sops
            # LSP Server
            tombi
            bash-language-server
            nixd
          ]
          ++ (builtins.attrValues scripts);
        shellHook = ''
          echo "commands: ${builtins.concatStringsSep ", " (builtins.attrNames scripts)}"
          export FLAKE_ROOT="$(git rev-parse --show-toplevel)"
        '';
      };

      apps.${system} = builtins.mapAttrs (name: pkg: {
        type = "app";
        program = "${pkg}/bin/${name}";
      }) scripts;
    };
}
