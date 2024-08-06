# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  ...
}: 

let
  dockerCertsDir = "/etc/docker/certs";
  clientCertsDir = "/etc/docker/client-certs";
in
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
    package = pkgs.docker_26;
    enableNvidia = true;
    daemon.settings = {
      hosts = [
        "tcp://0.0.0.0:2375"
      ];
      tls = true;
      tlscacert = "${dockerCertsDir}/ca.pem";
      tlscert = "${dockerCertsDir}/server-cert.pem";
      tlskey = "${dockerCertsDir}/server-key.pem";
      tlsverify = true;
    };
  };

  # Generate Docker TLS certificates
  system.activationScripts.dockerTLSCerts = ''
    mkdir -p ${dockerCertsDir} ${clientCertsDir}
    if [ ! -f ${dockerCertsDir}/ca.pem ]; then
      ${pkgs.openssl}/bin/openssl genrsa -out ${dockerCertsDir}/ca-key.pem 4096
      ${pkgs.openssl}/bin/openssl req -new -x509 -days 365 -key ${dockerCertsDir}/ca-key.pem -sha256 -out ${dockerCertsDir}/ca.pem -subj "/CN=dockerCA"
      ${pkgs.openssl}/bin/openssl genrsa -out ${dockerCertsDir}/server-key.pem 4096
      ${pkgs.openssl}/bin/openssl req -subj "/CN=$HOSTNAME" -sha256 -new -key ${dockerCertsDir}/server-key.pem -out ${dockerCertsDir}/server.csr
      ${pkgs.openssl}/bin/openssl x509 -req -days 365 -sha256 -in ${dockerCertsDir}/server.csr -CA ${dockerCertsDir}/ca.pem -CAkey ${dockerCertsDir}/ca-key.pem -CAcreateserial -out ${dockerCertsDir}/server-cert.pem
      chmod 0400 ${dockerCertsDir}/ca-key.pem ${dockerCertsDir}/server-key.pem
      chmod 0444 ${dockerCertsDir}/ca.pem ${dockerCertsDir}/server-cert.pem
    fi
    if [ ! -f ${clientCertsDir}/key.pem ]; then
      ${pkgs.openssl}/bin/openssl genrsa -out ${clientCertsDir}/key.pem 4096
      ${pkgs.openssl}/bin/openssl req -subj '/CN=client' -new -key ${clientCertsDir}/key.pem -out ${clientCertsDir}/client.csr
      ${pkgs.openssl}/bin/openssl x509 -req -days 365 -sha256 -in ${clientCertsDir}/client.csr -CA ${dockerCertsDir}/ca.pem -CAkey ${dockerCertsDir}/ca-key.pem -CAcreateserial -out ${clientCertsDir}/cert.pem
      cp ${dockerCertsDir}/ca.pem ${clientCertsDir}/ca.pem
      chmod 0400 ${clientCertsDir}/key.pem
      chmod 0444 ${clientCertsDir}/cert.pem ${clientCertsDir}/ca.pem
    fi
  '';
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
  #hardware.opengl.extraPackages32 = pkgs.lib.mkForce [ pkgs.linuxPackages_latest.nvidia_x11.lib32 ];
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
  services.ttyd = {
    enable = true;
    writeable = true;
  };

  age.secrets.influxdb_token.file = ../../secrets/influxdb_token.age;
  services.telegraf = {
    enable = true;
    extraConfig = { 
      outputs.influxdb_v2 = {
        urls = ["http://influxdb.home.arpa"];
        token = "$INFLUXDB_TOKEN"; 
        organization = "default";
        bucket = "${config.networking.hostName}";
      };
      
      inputs.docker = {
        endpoint = "unix:///var/run/docker.sock";
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
  users.users.telegraf = {
    extraGroups = [ "docker" ];
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

  fileSystems."/mnt/ssd" = {   
    device = "/dev/disk/by-uuid/033381e5-0f59-4451-b34a-eb3da13caaef";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };
  services.fstrim.enable = true;

  system.stateVersion = "24.05"; # Did you read the comment?
}
