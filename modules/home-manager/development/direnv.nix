# ABOUTME: Direnv configuration module for automatic environment loading
# ABOUTME: Enables per-directory environment variables and nix-shell integration

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.direnv;
in {
  options.modules.development.direnv = {
    enable = mkEnableOption "direnv automatic environment loading";
    
    enableNixDirenv = mkOption {
      type = types.bool;
      default = true;
      description = "Enable nix-direnv for better nix-shell integration";
    };
  };
  
  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = cfg.enableNixDirenv;
    };
    
    home.packages = mkIf cfg.enableNixDirenv [ pkgs.nix-direnv ];
  };
}