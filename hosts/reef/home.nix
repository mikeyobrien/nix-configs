{user, microvm, pkgs, ...}: {
  imports = [
    ../../home-manager/home.nix
  ];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  modules.llm.enable = true;

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
