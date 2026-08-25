{
  description = "mikeyobrien's nix config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Reef is pinned independently while the rest of the fleet remains on 25.05.
    # These are the exact revisions exercised by the guarded 6.18.40 trial.
    nixpkgs-reef.url = "github:NixOS/nixpkgs/2f5a153c270b70cb0f8c11f46d96d6d3bc39f4e3";
    home-manager-reef = {
      url = "github:nix-community/home-manager/d4fd24667c8cbef124bb70a20380cab75ec8474d";
      inputs.nixpkgs.follows = "nixpkgs-reef";
    };
    microvm-reef = {
      url = "github:astro/microvm.nix/39a499ab85311b56dddb09ec43351cc3658f22c1";
      inputs.nixpkgs.follows = "nixpkgs-reef";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

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

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    jovian.inputs.nixpkgs.follows = "nixpkgs";

    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = {
    self,
    nixpkgs,
    nix-on-droid,
    home-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;

    overlays = import ./overlays {inherit inputs;};
    mkSystem = import ./lib/mkSystem.nix {
      inherit nixpkgs inputs overlays outputs;
    };
    reefInputs = inputs // {
      nixpkgs = inputs.nixpkgs-reef;
      home-manager = inputs.home-manager-reef;
      microvm = inputs.microvm-reef;
    };
    mkReefSystem = import ./lib/mkSystem.nix {
      nixpkgs = inputs.nixpkgs-reef;
      inputs = reefInputs;
      inherit overlays outputs;
    };
    mkHome = import ./lib/mkHome.nix {
      inherit nixpkgs inputs outputs;
    };

    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system}) // {
      aarch64-darwin.orchardVM = self.nixosConfigurations.orchard.config.system.build.vm;
    };
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    nixosModules = import ./modules/nixos {inherit inputs;};
    homeManagerModules = import ./modules/home-manager {inherit inputs;};
    overlays = overlays;

    nixosConfigurations = {
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

      reef = mkReefSystem "reef" {
        user = "mobrienv";
        system = "x86_64-linux";
      };

      orchard = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./hosts/orchard/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              overlays.modifications
              overlays.additions
              overlays.unstable-packages
            ];
            nixpkgs.config.allowUnfree = true;
            virtualisation.vmVariant.virtualisation.host.pkgs = nixpkgs.legacyPackages.aarch64-darwin;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mobrienv = ./hosts/orchard/home.nix;
            home-manager.extraSpecialArgs = {
              currentSystem = "aarch64-linux";
              user = "mobrienv";
              inputs = inputs;
              outputs = outputs;
              isDarwin = false;
              isWsl = false;
            };
          }
          {
            config._module.args = {
              currentSystemName = "orchard";
              currentSystem = "aarch64-linux";
              user = "mobrienv";
              inputs = inputs;
              outputs = outputs;
            };
          }
        ];
      };
    };

    darwinConfigurations = {
      rainforest = mkSystem "rainforest" {
        user = "mobrienv";
        system = "aarch64-darwin";
        isDarwin = true;
      };

      studio = mkSystem "studio" {
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

    homeConfigurations = {
      "rainforest" = mkHome {
        user = "mobrienv";
        system = "aarch64-darwin";
        isDarwin = true;
        hostName = "rainforest";
      };
      "wsl" = mkHome {
        user = "mobrienv";
        system = "x86_64-linux";
        isWsl = true;
        hostName = "wsl";
      };
      "g14" = mkHome {
        user = "arch";
        system = "x86_64-linux";
        hostName = "g14";
      };
      "darwin" = mkHome {
        user = "mobrienv";
        system = "aarch64-darwin";
        isDarwin = true;
        hostName = "darwin";
      };
    };
  };
}