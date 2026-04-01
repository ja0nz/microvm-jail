{
  description = "VM jail for agents and the like";
  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    let
      vmList = [
        {
          name = "my-jail1";
          modules = [ ];
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
          modules = [
            microvm.nixosModules.microvm
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
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations = vms;
      packages.${system} = builtins.mapAttrs (
        _: vm: vm.config.microvm.runner.${vm.config.microvm.hypervisor}
      ) self.nixosConfigurations;

      formatter.x86_64-linux = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          mise
          deadnix
          pre-commit
          # LSP Server
          tombi
          bash-language-server
          nixd
        ];
        shellHook = ''
          echo "Mise environment active"
        '';
      };

    };
}
