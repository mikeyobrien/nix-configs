# ABOUTME: Profile for desktop users without heavy development needs
# ABOUTME: Includes GUI terminal and basic productivity tools

{ config, lib, pkgs, ... }:

{
  # Common CLI tools for desktop users
  modules.core.commonCli.enable = true;
  
  # GUI terminal emulator
  modules.terminal.alacritty.enable = true;
  
  # Basic shell enhancements
  modules.shells.prompts.enable = true;
  
  # Fonts for GUI applications
  modules.core.fonts.enable = true;
}