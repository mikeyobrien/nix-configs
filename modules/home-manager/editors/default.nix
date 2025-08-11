# ABOUTME: Editor module aggregator for text editors and IDEs
# ABOUTME: Central location for all editor configurations

{ config, lib, pkgs, ... }:

with lib;
{
  imports = [
    ./neovim.nix
    ./nixvim.nix
    ./emacs.nix
  ];
}