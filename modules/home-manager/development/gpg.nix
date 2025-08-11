# ABOUTME: GPG configuration module for encryption and signing
# ABOUTME: Manages GnuPG settings for secure communications

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.gpg;
in {
  options.modules.development.gpg = {
    enable = mkEnableOption "GPG configuration";
  };
  
  config = mkIf cfg.enable {
    programs.gpg.enable = true;
  };
}