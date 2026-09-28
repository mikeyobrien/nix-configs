# ABOUTME: Profile module aggregator for convenient imports
# ABOUTME: Profiles are pre-configured combinations of modules

{
  minimal = import ./minimal.nix;
  "cli-developer" = import ./cli-developer.nix;
  "desktop-user" = import ./desktop-user.nix;
  "full-developer" = import ./full-developer.nix;
}