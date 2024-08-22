{
  description = "mikeyobrien's nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    anyrun.url = "github:anyrun-org/anyrun";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    nix-on-droid,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    overlays = import ./overlays {inherit inputs;};
    mkSystem = import ./lib/mkSystem.nix {
      inherit nixpkgs inputs overlays outputs;
    };

    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # TODO Find out whats the advantage of setting these as outputs
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    nixosModules = import ./modules/nixos {inherit inputs;};
    homeManagerModules = import ./modules/home-manager;
    overlays = overlays;

    nixosConfigurations = {
      moss = mkSystem "moss" {
        user = "mobrienv";
        system = "x86_64-linux";
      };

      wsl = mkSystem "wsl" {
        user = "mobrienv";
        system =  "x86_64-linux";
        isWsl = true;
      };

      rhizome = mkSystem "rhizome" {
        user = "mobrienv";
        system = "x86_64-linux";
      };

      driftwood = mkSystem "driftwood" {
        user = "mobrienv";
        system = "x86_64-linux";
      };
    };

    darwinConfigurations = {
      rainforest = mkSystem "rainforest" {
        user = "mobrienv";
        system = "aarch64-darwin";
        isDarwin = true;
      };
    };

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      modules = [
        (import ./hosts/droid/configuration.nix {
          user = "mobrienv";
          inputs = inputs;
        })
      ];
    };

    # TODO: make lib helper `mkHome`
    homeConfigurations = {
      "rainforest" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          (import ./hosts/rainforest/home.nix {user = "mobrienv"; lib = nixpkgs.lib; }) 
        ];
      };
      "wsl" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          (import ./hosts/wsl/home.nix {user = "mobrienv"; lib = nixpkgs.lib; }) 
        ];
      };
    };
  };
}
