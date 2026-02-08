# ABOUTME: Astral uv module
# ABOUTME: Installs uv for Python packaging and tooling

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.uv;
in {
  options.modules.development.uv = {
    enable = mkEnableOption "Astral uv";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      uv
    ];
  };
}
