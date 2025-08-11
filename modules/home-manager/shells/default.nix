# ABOUTME: Shell module aggregator providing unified shell configuration
# ABOUTME: Imports all shell-related modules for easy management

{ config, lib, pkgs, ... }:

with lib;
{
  imports = [
    ./common.nix
    ./bash.nix
    ./fish.nix
    ./prompts.nix
  ];
  
  config = {
    # Always enable common configuration when any shell is enabled
    modules.shells.common.enable = mkDefault (
      config.modules.shells.bash.enable ||
      config.modules.shells.fish.enable
    );
    
    # Enable prompts by default when any shell is enabled
    modules.shells.prompts.enable = mkDefault (
      config.modules.shells.bash.enable ||
      config.modules.shells.fish.enable
    );
  };
}