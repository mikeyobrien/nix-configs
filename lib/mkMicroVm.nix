{
  nixpkgs,
  overlays,
  inputs,
  outputs,
}: name: {
  user,
  system,
  ...
}: let
in
  nixpkgs.lib.nixosSystem rec {
    inherit system;
    modules = [
      outputs.nixosModules.proxmox
      outputs.nixosModules.virtualisation
      outputs.nixosModules.proxmox
      inputs.microvm.nixosModules.microvm
      inputs.agenix.nixosModules.default
      ../microvm/${name}/configuration.nix

      inputs.home-manager.nixosModules.home-manager
      {
        nixpkgs.overlays = [
          overlays.modifications
          overlays.additions
          overlays.unstable-packages
        ];

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${user} = ../hosts/${name}/home.nix;
        home-manager.extraSpecialArgs = {
          currentSystem = system;
          user = user;
          inputs = inputs;
      	  outputs = outputs;
        };
      }

      {
        config._module.args = {
          currentSystemName = name;
          currentSystem = system;
          user = user;
          inputs = inputs;
          outputs = outputs;
        };
      }
    ];
  }
