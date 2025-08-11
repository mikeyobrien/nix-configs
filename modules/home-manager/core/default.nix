# ABOUTME: Core module aggregator that imports all core modules
# ABOUTME: Provides a single enable option to activate all core functionality

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.core;
in {
  imports = [
    ./essential.nix
    ./common-cli.nix
    ./packages.nix  # Legacy compatibility
    ./fonts.nix
  ];
  
  options.modules.core = {
    enable = mkEnableOption "all core modules";
  };
  
  config = mkIf cfg.enable {
    modules.core.essential.enable = true;
    modules.core.commonCli.enable = true;
    modules.core.fonts.enable = true;
  };
}