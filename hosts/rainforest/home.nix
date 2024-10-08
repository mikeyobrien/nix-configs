{ user, lib, currentSystem, ... }: 
 
let
    isDarwin = lib.hasSuffix "darwin" currentSystem;
in {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = lib.mkForce (if isDarwin then "/Users/${user}" else "/home/${user}");
  };

  editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = false;
  };

  programs.tmux = {
    prefix = lib.mkForce "C-a";
  };
}
