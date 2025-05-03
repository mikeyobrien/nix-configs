{user, microvm, pkgs, ...}: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/uvx.nix
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

  # Override GNOME Shell Wayland service to add virtual monitor
  # systemd.user.services."org.gnome.Shell@wayland" = {
  #   overrideStrategy = "asDropin";
  #   Service = {
  #     ExecStart = ["" "${pkgs.gnome.gnome-shell}/bin/gnome-shell --virtual-monitor 1920x1080"];
  #   };
  # };
  #
  home.packages = with pkgs; [
    google-chrome
    way-displays
  ];

  editors.nixvim = {
    enable = false;
    lazyPlugins.copilot.enable = false;
  };

  modules.uvx.enable = true;
}
