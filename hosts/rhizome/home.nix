{user, ...}: {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  modules.editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = true;
  };
}
