{ pkgs, user, ... }: {

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = user;
    startMenuLaunchers = true;
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  system.stateVersion = "23.05";
}
