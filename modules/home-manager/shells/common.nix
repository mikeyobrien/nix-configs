# ABOUTME: Common shell configuration with shared aliases
# ABOUTME: These aliases are used across all shell types

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.shells.common;
in {
  options.modules.shells.common = {
    enable = mkEnableOption "common shell configuration";
    
    aliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Shell aliases to be shared across all shells";
    };
  };
  
  config = mkIf cfg.enable {
    modules.shells.common.aliases = {
      # Git aliases
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gd = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
      
      # Python
      python = "python3";
      
      # Other tools
      bbka = lib.getExe pkgs.babashka;
    };
  };
}