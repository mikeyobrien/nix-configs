{ user, lib, ... }: {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = true;
  };

  programs.tmux = {
    prefix = lib.mkForce "C-a";
  };
}
