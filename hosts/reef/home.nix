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
    "org/gnome/desktop/interface" = {
      scaling-factor = 2;
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
  home.packages = with pkgs; [
    google-chrome
    kdePackages.konsole
    nodejs
    way-displays
  ];

  # Enable uvx
  modules.development.uvx.enable = true;
}
