# ABOUTME: Alacritty terminal emulator configuration module
# ABOUTME: Provides a fast, GPU-accelerated terminal with customizable settings

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.terminal.alacritty;
in {
  options.modules.terminal.alacritty = {
    enable = mkEnableOption "Alacritty terminal emulator";
    
    fontSize = mkOption {
      type = types.int;
      default = 14;
      description = "Font size for Alacritty";
    };
    
    fontFamily = mkOption {
      type = types.str;
      default = "JetBrainsMono Nerd Font";
      description = "Font family for Alacritty";
    };
    
    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Alacritty settings";
    };
  };
  
  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        env.TERM = "xterm-256color";
        font.size = cfg.fontSize;
        font.normal.family = cfg.fontFamily;
        keyboard.bindings = [
          {
            key = "K";
            mods = "Command";
            chars = "ClearHistory";
          }
          {
            key = "V";
            mods = "Command";
            action = "Paste";
          }
          {
            key = "C";
            mods = "Command";
            action = "Copy";
          }
          {
            key = "Key0";
            mods = "Command";
            action = "ResetFontSize";
          }
          {
            key = "Equals";
            mods = "Command";
            action = "IncreaseFontSize";
          }
          {
            key = "Minus";
            mods = "Command";
            action = "DecreaseFontSize";
          }
          {
            key = "N";
            mods = "Shift|Control";
            action = "CreateNewWindow";
          }
        ];
      } // cfg.extraSettings;
    };
  };
}