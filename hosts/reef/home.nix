{user, microvm, pkgs, ...}: {
  imports = [
    ../../home-manager/home.nix
  ];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  editors.nixvim = {
    enable = false;
    lazyPlugins.copilot.enable = false;
  };

}
