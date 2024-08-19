{
  pkgs,
  config,
  ...
}: {

  nix.useDaemon = true;
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  services.nix-daemon.enable = true;

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

  fonts.packages = [
    (pkgs.nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono"];})
    pkgs.roboto
  ];

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];

  #homebrew = {
  #  enable = true;
 #   taps = [];
 #   casks = [
 #     "nikitabobko/tap/aerospace"
 #   ];
 # };

}
