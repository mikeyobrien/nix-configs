{ pkgs, user, ... }: {

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = user;
    startMenuLaunchers = true;
  };

  # Configure fish as default shell
  programs.fish.enable = true;
  users.users.${user} = {
    isNormalUser = true;
    shell = pkgs.fish;
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
  ];

  system.stateVersion = "23.05";
}
