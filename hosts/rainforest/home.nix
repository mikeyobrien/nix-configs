{ user, lib, currentSystem, ... }: 
 
let
    isDarwin = lib.hasSuffix "darwin" currentSystem;
in {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = lib.mkForce (if isDarwin then "/Users/${user}" else "/home/${user}");
  };

  modules.editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = false;
  };

  modules.editors.emacs.enable = true;

  programs.tmux = {
    prefix = lib.mkForce "C-a";
  };
}
