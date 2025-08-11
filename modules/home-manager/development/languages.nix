# ABOUTME: Development languages and tools configuration module
# ABOUTME: Manages language servers, linters, and development tools

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.languages;
in {
  options.modules.development.languages = {
    enable = mkEnableOption "development language tools";
    
    enableNix = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nix language tools";
    };
    
    enableNodejs = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Node.js";
    };
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional development packages";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = with pkgs; 
      (optional cfg.enableNix nil) ++
      (optional cfg.enableNodejs nodejs) ++
      cfg.extraPackages;
  };
}