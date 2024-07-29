# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  ...
}: 

{
  imports = [
    ../default.nix
    ./hardware-configuration.nix
  ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_25;
  };
  hardware.nvidia-container-toolkit.enable = true;

  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "i915.enable_guc=2"
  ];
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda"; # or "nodev" for efi only

  networking.hostName = "driftwood"; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # workaround for autologin issue https://nixos.wiki/wiki/GNOME
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  

  ## Weird issue where i686 was trying to be built: https://github.com/NixOS/nixpkgs/issues/241539
  hardware.opengl.extraPackages32 = pkgs.lib.mkForce [ pkgs.linuxPackages_latest.nvidia_x11.lib32 ];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  services.xserver.videoDrivers = ["nvidia"];
  services.xserver.xkb.layout = "us";
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

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

  ## Define a user account. Don't forget to set a password with ‘passwd’.
  programs.fish.enable = true;
  programs.zsh.enable = true;
  users.users.mobrienv = {
    isNormalUser = true;
    home = "/home/mobrienv";
    extraGroups = ["docker" "wheel"];
    shell = pkgs.fish;
    hashedPasswordFile = config.age.secrets.password.path;
    openssh.authorizedKeys.keys = [];
  };

  security.sudo.wheelNeedsPassword = false;

  services = {
    syncthing = {
      enable = true;
      user = "mobrienv";
      dataDir = "/home/mobrienv/"; # Default folder for new synced folders
      configDir = "/home/mobrienv/.config/syncthing"; # Folder for Syncthing's settings and keys
    };
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    zlib
    libgcc
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    python3
    socat
    pipx
    gcc
    clang

    cudatoolkit
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;

  networking.firewall.enable = false;
  services.qemuGuest.enable = true;

  age.secrets.influxdb_token.file = ../secrets/influxdb_token.age;
  services.telegraf = {
    enable = true;
    extraConfig = { 
      outputs.influxdb_v2 = {
        urls = ["http://influxdb.home.arpa"];
        token = "$INFLUXDB_TOKEN"; 
        organization = "default";
        bucket = "moss";
      };
      
      inputs.nvidia_smi = {
        bin_path = "/run/current-system/sw/bin/nvidia-smi";
      };
    };
  };
  systemd.services.telegraf = {
    serviceConfig = {
      EnvironmentFile = config.age.secrets.influxdb_token.path;
    };
  };

  fileSystems."/mnt/unraid" = {
    device = "unraid.local:/mnt/user/nixos";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "hard" "intr" "rw"];
  };

  fileSystems."/mnt/data" = {
    device = "unraid.local:/mnt/user/data";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "hard" "intr" "rw"];
  };

  fileSystems."/mnt/media" = {
    device = "unraid.local:/mnt/user/media";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "hard" "intr" "rw"];
  };

 fileSystems."/mnt/appdata" = {
    device = "unraid.local:/mnt/user/appdata";
    fsType = "nfs";
    options = ["x-systemd.automount" "noauto" "hard" "intr" "rw"];
  };

  system.stateVersion = "24.05"; # Did you read the comment?
}
