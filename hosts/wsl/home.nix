{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/emacs.nix
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  editors.nixvim = {
    enable = false;
    lazyPlugins.copilot.enable = true;
  };

  programs.tmux = {
    prefix = lib.mkForce "C-a";
  };

  modules.editors.emacs.enable = true;
 
}
