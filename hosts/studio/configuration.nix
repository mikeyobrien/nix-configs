{
  pkgs,
  config,
  ...
}: {
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # For use with determinate
  nix.enable = false;

  # Enable passwordless sudo
  security.sudo.extraConfig = ''
    %admin ALL=(ALL) NOPASSWD: ALL
  '';

  # Set hostname
  networking.hostName = "studio";
  networking.computerName = "studio";
  system.defaults.smb.NetBIOSName = "studio";

  programs.zsh.enable = true;
  programs.zsh.shellInit = ''
    # Nix
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    # End Nix
  '';

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    # Nix
    if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
      source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    end
    # End Nix
  '';

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];
  system.stateVersion = 6;

  #homebrew = {
  #  enable = true;
  #  taps = [];
  #  casks = [
  #    "nikitabobko/tap/aerospace"
  #  ];
  #};

}