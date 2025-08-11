# ABOUTME: Terminal module aggregator for terminal emulators and multiplexers
# ABOUTME: Imports all terminal-related configuration modules

{ config, lib, pkgs, ... }:

with lib;
{
  imports = [
    ./alacritty.nix
    ./tmux.nix
    ./zellij.nix
  ];
}