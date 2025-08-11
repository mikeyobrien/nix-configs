# ABOUTME: Legacy core packages module - enables both essential and common CLI
# ABOUTME: Kept for backward compatibility, prefer using essential/commonCli directly

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.core.packages;
in {
  options.modules.core.packages = {
    enable = mkEnableOption "all core packages (legacy)";
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install";
    };
  };
  
  config = mkIf cfg.enable {
    # Enable both essential and common CLI packages
    modules.core.essential.enable = true;
    modules.core.commonCli.enable = true;
    
    # Development tools that were in core
    home.packages = with pkgs; [
      nil      # Nix LSP
      # devenv   # Development environments - temporarily disabled due to build issues
    ] ++ cfg.extraPackages;
  };
}