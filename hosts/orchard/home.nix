# ABOUTME: Home Manager configuration for orchard VM user
# ABOUTME: Imports base k3s VM home configuration

{ config, pkgs, lib, user, ... }:

{
  imports = [
    ../base-k3s-vm/home.nix
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
    stateVersion = "24.05";
  };
}
