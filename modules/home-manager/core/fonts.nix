# ABOUTME: Font configuration module providing Nerd Fonts
# ABOUTME: Manages font packages needed for terminal and editor icons

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.core.fonts;
in {
  options.modules.core.fonts = {
    enable = mkEnableOption "Nerd Fonts";
    
    fonts = mkOption {
      type = types.listOf types.str;
      default = ["FiraCode" "JetBrainsMono"];
      description = "List of Nerd Fonts to install";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.nerdfonts.override { fonts = cfg.fonts; })
    ];
  };
}