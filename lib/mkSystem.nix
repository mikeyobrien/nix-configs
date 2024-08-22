{
  nixpkgs,
  overlays,
  inputs,
  outputs,
}: name: {
  user,
  system,
  isDarwin ? false,
  isWsl ? false,
  ...
}: let
  systemTypeMap = {
    x86_64-linux = nixpkgs.lib.nixosSystem;
    x86_64-darwin = inputs.darwin.lib.darwinSystem;
    aarch64-darwin = inputs.darwin.lib.darwinSystem;
  };

  home-managerMap = {
    x86_64-linux = inputs.home-manager.nixosModules.home-manager;
    aarch64-darwin = inputs.home-manager.darwinModules.home-manager;
  };

  getMapping = systemType: systemMap:
    nixpkgs.lib.attrByPath [systemType] "unknownMapping" systemMap;

  systemFunc = getMapping system systemTypeMap;
  homeManagerModules = getMapping system home-managerMap;
  extraNixosModules = if !isDarwin then [
    outputs.nixosModules.proxmox
    #outputs.nixosModules.virtualisation
    inputs.agenix.nixosModules.default
  ] else [];
in
  systemFunc rec {
    inherit system;
    modules = [
      outputs.nixosModules.proxmox
      outputs.nixosModules.virtualisation

      (if isWsl then inputs.nixos-wsl.nixosModules.wsl else {})

      inputs.agenix.nixosModules.default
      {
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
          currentSystem = system;
          user = user;
          inputs = inputs;
      	  outputs = outputs;
          isDarwin = isDarwin;
          isWsl = isWsl;
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
    ] ++ extraNixosModules;
  }
