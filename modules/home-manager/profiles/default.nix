# ABOUTME: Profile module aggregator for convenient imports
# ABOUTME: Profiles are pre-configured combinations of modules

{ ... }:

{
  imports = [
    ./minimal.nix
    ./cli-developer.nix
    ./desktop-user.nix
    ./full-developer.nix
  ];
}