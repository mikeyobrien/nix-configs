{
  nixpkgs,
  inputs,
  outputs,
  overlays,
}: {
  # Helper to create home-manager configurations with standardized arguments
  mkHome = { user, system, isDarwin ? false, isWsl ? false, hostName, ... }: 
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
        overlays = overlays;
      };
      extraSpecialArgs = {
        inherit inputs outputs;
        user = user;
        currentSystem = system;
        isDarwin = isDarwin;
        isWsl = isWsl;
        hostName = hostName;
      };
      modules = [
        (import ./hosts/${hostName}/home.nix { 
          inherit user; 
          lib = nixpkgs.lib; 
          currentSystem = system; 
        })
      ];
    };
}
