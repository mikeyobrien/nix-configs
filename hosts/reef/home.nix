{user, microvm, pkgs, ...}: {
  imports = [
    ../../home-manager/home.nix
  ];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  # Reef-specific configurations
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
  
  # Additional packages for reef
  modules.core.packages.extraPackages = with pkgs; [
    google-chrome
    way-displays
  ];

  # Disable nixvim on reef
  modules.editors.nixvim = {
    enable = false;
    lazyPlugins.copilot.enable = false;
  };

  # Enable uvx
  modules.development.uvx.enable = true;
}
