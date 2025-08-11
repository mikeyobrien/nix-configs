# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{inputs, ...}: {
  # List your module files here
  llm = import ./llm.nix;
  
  # New modular structure
  core = import ./core;
  shells = import ./shells;
  terminal = import ./terminal;
  editors = import ./editors;
  development = import ./development;
  profiles = import ./profiles;
}
