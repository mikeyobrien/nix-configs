{
  nixpkgs,
  inputs,
  outputs,
}: name: {
  user,
  system,
  isDarwin ? false,
  isWsl ? false,
  hostName,
  ...
}:
let
  homeManagerModules = case system of
    "x86_64-linux" => inputs.home-manager.nixosModules.home-manager;
    "aarch64-darwin" => inputs.home-manager.darwinModules.home-manager;
    "x86_64-darwin" => inputs.home-manager.darwinModules.home-manager;
    _ => throw "Unsupported system for home-manager";
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${system};
  modules = [
    ../../home-manager/home.nix
    ./hosts/${hostName}/home.nix
    {
      home-manager.extraSpecialArgs = {
        currentSystem = system;
        user = user;
        inputs = inputs;
        outputs = outputs;
        isDarwin = isDarwin;
        isWsl = isWsl;
      };
    }
  ];
}