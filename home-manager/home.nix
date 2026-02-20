# ABOUTME: Minimal base home-manager configuration
# ABOUTME: Provides only essential packages and shell - hosts add what they need

{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  user,
  ...
}:
{
  imports = [
    # Import all available modules; hosts opt into profiles explicitly
    outputs.homeManagerModules.core
    outputs.homeManagerModules.shells
    outputs.homeManagerModules.terminal
    outputs.homeManagerModules.editors
    outputs.homeManagerModules.development
    outputs.homeManagerModules.llm
  ];

  nixpkgs.overlays = [
    outputs.overlays.modifications
    outputs.overlays.additions
    outputs.overlays.unstable-packages
  ];

  # Minimal defaults - essentials plus prompt-aware fish shell
  modules.core.essential.enable = lib.mkDefault true;
  modules.core.commonCli.enable = lib.mkDefault true;
  modules.shells.fish.enable = lib.mkDefault true;
  modules.shells.prompts.enable = lib.mkDefault true;

  # Home Manager bookkeeping
  programs.home-manager.enable = true;
  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "sd-switch";
  home.stateVersion = "23.05";

  # npm global prefix configuration
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    
    # pi-otlp metrics collection
    PI_OTLP_ENABLE = "1";
    OTEL_METRICS_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_ENDPOINT = "https://otel.lan.mobrienv.dev/v1/metrics";
    # Optional: enable debug logging
    PI_OTLP_DEBUG = "1";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
