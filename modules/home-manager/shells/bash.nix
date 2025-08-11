# ABOUTME: Bash shell configuration module
# ABOUTME: Configures bash with history control and aliases

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.shells.bash;
  commonAliases = config.modules.shells.common.aliases;
in {
  options.modules.shells.bash = {
    enable = mkEnableOption "bash shell configuration";
    
    extraAliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional bash-specific aliases";
    };
  };
  
  config = mkIf cfg.enable {
    programs.bash = {
      enable = true;
      shellOptions = [];
      historyControl = ["ignoredups" "ignorespace"];
      shellAliases = commonAliases // cfg.extraAliases;
    };
  };
}