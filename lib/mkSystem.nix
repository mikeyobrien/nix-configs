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
  systemTypeMap = {
    x86_64-linux = nixpkgs.lib.nixosSystem;
    x86_64-darwin = inputs.darwin.lib.darwinSystem;
    aarm64-darwin = inputs.darwin.lib.darwinSystem;
  };

  home-managerMap = {
    x86_64-linux = inputs.home-manager.nixosModules.home-manager;
    aarm64-darwin = inputs.home-manager.darwinModules;
  };

  getMapping = systemType: systemMap:
    nixpkgs.lib.attrByPath [systemType] "unknownMapping" systemMap;

  systemFunc = getMapping system systemTypeMap;
  homeManagerModules = getMapping system home-managerMap;
in
  systemFunc rec {
    inherit system;
    modules = [
      outputs.nixosModules.proxmox
      inputs.agenix.nixosModules.default
      {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [
          overlays.modifications
          overlays.additions
          overlays.unstable-packages
        ];
      }

      ../hosts/${name}/configuration.nix
      homeManagerModules
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${user} = ../hosts/${name}/home.nix;
        home-manager.extraSpecialArgs = {
          user = user;
          inputs = inputs;
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
