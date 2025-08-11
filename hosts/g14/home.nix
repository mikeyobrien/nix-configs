# ABOUTME: Home-manager configuration for g14 laptop
# ABOUTME: CLI developer setup with laptop-specific customizations

{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/profiles/cli-developer.nix
    # Import an inline module that adds laptop packages
    ({ pkgs, ... }: {
      home.packages = with pkgs; [
        brightnessctl  # Screen brightness control
        powertop       # Power management analysis
        acpi           # Battery information
      ];
    })
  ];
  
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  
  # Enable additional terminal emulator for laptop use
  modules.terminal.alacritty = {
    enable = true;
    fontSize = 14; # Larger font for high-DPI display
  };
}