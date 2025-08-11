# ABOUTME: Common CLI tools that are useful but not essential
# ABOUTME: These tools enhance productivity but aren't required for basic operation

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.core.commonCli;
in {
  options.modules.core.commonCli = {
    enable = mkEnableOption "common CLI tools";
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional CLI packages";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Enhanced tools
      yadm         # Dotfile manager
      grc          # Generic colouriser
      xsv          # CSV toolkit
      glow         # Markdown renderer
      just         # Command runner
      
      # Security
      pass         # Password manager
      
      # Development adjacent
      tree-sitter  # Parser generator
      cachix       # Nix binary cache
      
      # Documentation
      ispell       # Spell checker
    ] ++ cfg.extraPackages;
  };
}