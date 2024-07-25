# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  outputs,
  config,
  ...
}: {
  imports = [
    ../default.nix
    ./hardware-configuration.nix
  ];
  nix.settings = {
    trusted-users = ["root" "mobrienv"];
    builders-use-substitutes = true;
    # extra-substituters = [
    #   "https://anyrun.nixos.org"
    # ];
    # extra-trusted-public-keys = [
    #   "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    # ];
  };
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  virtualisation.docker.enable = true;

  programs.kdeconnect = {
    enable = true;
    package = pkgs.valent;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # TODO: refactor since this will be shared across hosts
  environment.pathsToLink = ["/share/fish"];
  users.users.mobrienv = {
    isNormalUser = true;
    home = "/home/mobrienv";
    extraGroups = ["docker" "wheel"];
    shell = pkgs.fish;
    hashedPasswordFile = config.age.secrets.password.path;
    openssh.authorizedKeys.keys = [];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.kernelModules = ["amdgpu"];

  networking = {
    hostName = "moss";
    networkmanager.enable = true;
    interfaces."enp14s0".wakeOnLan.enable = true;
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  services.displayManager.sddm.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Optional: Enable the Hyprland helper services (these come from the Hyprland NixOS module)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-hyprland];

  # Optional: If you want to use native Wayland for Qt applications
  qt.platformTheme = "qt5ct";
  qt.style = "adwaita";

  # Ensure Wayland is used
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1"; # If you have issues with cursor rendering
  };

  services.printing.enable = true;
  hardware.pulseaudio.enable = false;
  security.sudo.wheelNeedsPassword = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.nix-ld.enable = true;
  programs.fish = {
    enable = true;
  };
  programs.firefox.enable = true;
  environment.systemPackages = with pkgs; [
    alejandra
    nix-prefetch-scripts
    nixpkgs-fmt
    nix-index
    lgtv
    gcc
    zig
    vim
    wget
    wayland
    xdg-utils
    glib
    gnome3.adwaita-icon-theme
    swaylock
    swayidle
    dnsutils
    usbutils
  ];

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.blueman.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
    };
  };
  services.tailscale.enable = true;

  programs.steam = {
    enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  services.tailscale.enable = true;

  services.sunshine = {
    enable = true;
    capSysAdmin = true;
  };

  networking.firewall.enable = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };

  fileSystems."/mnt/network" = {
    device = "unraid.local:/mnt/user/network";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "hard" "intr" "rw"];
  };

  services.flatpak.enable = true;

  system.stateVersion = "24.05"; # Did you read the comment?
}
