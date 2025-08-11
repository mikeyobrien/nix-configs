# ABOUTME: Zellij terminal workspace manager configuration module
# ABOUTME: Modern alternative to tmux with better defaults and UI

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.terminal.zellij;
in {
  options.modules.terminal.zellij = {
    enable = mkEnableOption "Zellij terminal workspace";
    
    theme = mkOption {
      type = types.str;
      default = "gruvbox-dark";
      description = "Zellij color theme";
    };
    
    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Zellij settings";
    };
  };
  
  config = mkIf cfg.enable {
    programs.zellij = {
      enable = true;
      settings = {
        theme = cfg.theme;
      } // cfg.extraSettings;
    };
  };
}