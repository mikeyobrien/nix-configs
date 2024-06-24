{
  description = "mikeyobrien's nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
    anyrun = {
      url = "github:anyrun-org/anyrun";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix.url = "github:ryantm/agenix";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    nix-on-droid,
    ...
  } @ inputs: let
    inherit (self) outputs;

    overlays = import ./overlays {inherit inputs;};
    mkSystem = import ./lib/mkSystem.nix {
      inherit nixpkgs inputs overlays outputs;
    };
    systems = [
      "aarch64-linux"
      "i686-linux"
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

      rhizome = mkSystem "rhizome" {
        user = "mobrienv";
        system = "x86_64-linux";
      };

      driftwood = mkSystem "driftwood" {
        user = "mobrienv";
        system = "x86_64-linux";
      };
    };

    # TODO move this to a lib helper
    # homeConfigurations = {
    #   "work" = home-manager.lib.homeManagerConfiguration {
    #     pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
    #     extraSpecialArgs = {inherit inputs outputs;};
    #     modules = [
    #       ./home-manager/home.nix
    #     ];
    #   };
    # };

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      modules = [
        #inputs.home-manager-2311.nixosModules.home-manager
        (import ./hosts/droid/configuration.nix {
          user = "mobrienv";
          inputs = inputs;
        })
      ];
    };
  };
}
