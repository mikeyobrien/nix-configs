{ user, lib, currentSystem, pkgs, ... }: 
 
let
   isDarwin = lib.hasSuffix "darwin" currentSystem;
in {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = lib.mkForce (if isDarwin then "/Users/${user}" else "/home/${user}");
  };

  modules.development.tools.enable = true;
  modules.editors.emacs.enable = true;
  modules.editors.neovim.enable = true;
  home.packages = with pkgs; [
    nodejs
  ];
  programs.tmux = {
    prefix = lib.mkForce "C-a";
  };
}
