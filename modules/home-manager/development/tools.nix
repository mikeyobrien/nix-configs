# ABOUTME: Common development tools module
# ABOUTME: Provides CLI tools commonly used in development workflows

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.tools;
in {
  options.modules.development.tools = {
    enable = mkEnableOption "common development tools";
    
    extraTools = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional development tools to install";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      lazygit
      just
      # devenv  # Temporarily disabled due to build issues
    ] ++ cfg.extraTools;
  };
}