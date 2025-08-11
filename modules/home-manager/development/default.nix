# ABOUTME: Development module aggregator for all development tools
# ABOUTME: Central import point for development-related configurations

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development;
in {
  imports = [
    ./git.nix
    ./direnv.nix
    ./languages.nix
    ./gpg.nix
    ./tools.nix
    ./uvx.nix
  ];
  
  options.modules.development = {
    enable = mkEnableOption "all development modules";
  };
  
  config = mkIf cfg.enable {
    modules.development = {
      git.enable = true;
      direnv.enable = true;
      languages.enable = true;
      gpg.enable = true;
      tools.enable = true;
    };
  };
}