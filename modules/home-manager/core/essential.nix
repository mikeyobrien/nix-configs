# ABOUTME: Absolutely essential packages for basic system operation
# ABOUTME: These are the minimal tools needed on any system

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.core.essential;
in {
  options.modules.core.essential = {
    enable = mkEnableOption "essential core packages";
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional essential packages";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # File management
      fd       # Better find
      ripgrep  # Better grep
      tree     # Directory visualization
      
      # Text processing
      jq       # JSON processor
      bat      # Better cat with syntax highlighting
      
      # System monitoring
      htop     # Process viewer
      
      # Shell enhancement
      fzf      # Fuzzy finder
    ] ++ cfg.extraPackages;
  };
}