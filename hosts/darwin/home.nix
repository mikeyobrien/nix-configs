# ABOUTME: Home-manager configuration for darwin (macOS)
# ABOUTME: CLI developer setup adapted for macOS

{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/profiles/cli-developer.nix
    # Import an inline module that adds macOS-specific packages
    ({ pkgs, ... }: {
      home.packages = with pkgs; [
        # macOS-specific utilities
        mas           # Mac App Store CLI
        dockutil      # Dock management
        pngpaste      # Paste images from clipboard
      ];
    })
  ];

  home = {
    username = user;
    homeDirectory = "/Users/${user}";  # macOS home directory path
  };


  modules.editors.emacs.enable = true;

  # Enable additional terminal emulator for macOS
  modules.terminal.alacritty = {
    enable = true;
    fontSize = 14; # Larger font for Retina display
  };
}
