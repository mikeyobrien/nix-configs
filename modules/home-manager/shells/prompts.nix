# ABOUTME: Shell prompt configuration module using Starship
# ABOUTME: Provides a customizable cross-shell prompt

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.shells.prompts;
in {
  options.modules.shells.prompts = {
    enable = mkEnableOption "Starship prompt";
    
    showHostname = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to show hostname in prompt";
    };
    
    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Starship configuration";
    };
  };
  
  config = mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings = {
        hostname = mkIf cfg.showHostname {
          ssh_only = false;
          format = "[$hostname]($style) ";
        };
      } // cfg.extraConfig;
    };
  };
}