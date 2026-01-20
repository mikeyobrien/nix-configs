{
  pkgs,
  config,
  ...
}: {
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    
    # Remote builder configuration
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "reef";
        sshUser = "mobrienv";
        sshKey = "/Users/mobrienv/.ssh/id_ed25519";
        system = "aarch64-linux";
        maxJobs = 8;
        speedFactor = 2;
        supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ];
      }
    ];
    
    settings = {
      builders-use-substitutes = true;
    };
  };

  # For use with determinate
  nix.enable = false;

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
    
    # User Nix Profile
    if test -e $HOME/.nix-profile/bin
      fish_add_path --prepend $HOME/.nix-profile/bin
    end
  '';

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    fish
  ];
  system.stateVersion = 6;

  #homebrew = {
  #  enable = true;
 #   taps = [];
 #   casks = [
 #     "nikitabobko/tap/aerospace"
 #   ];
 # };

}
