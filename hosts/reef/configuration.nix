{ config, pkgs, outputs, ... }:

{  
  imports =
    [ 
      ../default.nix
      ./hardware-configuration.nix
      ./guacamole.nix
      ./k3s.nix
      ./microvm.nix 
      ./roon-server.nix
      ./glances.nix
      #./ups.nix
      # TODO: Unable to initialize capture methodAdd Cachix
    ];
  
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
      outputs.overlays.modifications
      outputs.overlays.additions
      outputs.overlays.unstable-packages
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "mobrienv"];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [
    "nvidia" "i915" "nvidia_modeset" "nvidia_drm" 
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1b21:0612,10de:2204
    options kvm_intel nested=1
    options vfio_iommu_type1 allow_unsafe_interrupts=1
  '';

  # Enable Graphics
  hardware.graphics = {
    enable = true;
  };

  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
    displayManager.gdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "mobrienv";
    desktopManager.gnome.enable = true;
  };

  # Auto-login workaround
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  nixpkgs.config.nvidia.acceptLicense = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    open = true; # Use open source kernel modules for RTX/Turing+ GPUs
  };

  networking.hostName = "reef"; # Define your hostname.
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = ["enp5s0" "vm-*"];
    networkConfig = {
      Bridge = "br0";
    };
  };

  systemd.network.netdevs."br0" = {
    netdevConfig = {
      Name = "br0";
      Kind = "bridge";
    };
  };

  systemd.network.networks."10-lan-bridge" = {
    matchConfig.Name = "br0";
    networkConfig = {
      Address = ["10.10.11.39/23"];
      Gateway = "10.10.10.1";
      DNS = ["10.10.10.1"];
    };
    linkConfig.RequiredForOnline = "routable";
  };

  environment.gnome.excludePackages = (with pkgs; [
    gnome-photos
    gnome-tour
  ]) ++ (with pkgs; [
    cheese # webcam tool
    gnome-music
    epiphany # web browser
    geary # email reader
    gnome-characters
    tali # poker game
    iagno # go game
    hitori # sudoku game
    atomix # puzzle game
    yelp # Help view
    gnome-contacts
    gnome-initial-setup
  ]);

  programs.dconf.enable = true;
  networking = {
    bridges = {
      br0 = {
        interfaces = [ "enp5s0" ];
      };
    };
    interfaces = {
      br0.useDHCP = false;
      enp5s0.useDHCP = false;
    };
  };
  
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  ## Define a user account. Don't forget to set a password with ‘passwd’.
  programs.fish.enable = true;
  programs.zsh.enable = true;
  users.users.mobrienv = {
    isNormalUser = true;
    home = "/home/mobrienv";
    extraGroups = ["docker" "wheel" "libvirtd" "kvm" "qemu" "input"];
    shell = pkgs.fish;
    hashedPasswordFile = config.age.secrets.password.path;
    openssh.authorizedKeys.keys = [];
  };

  environment.systemPackages = with pkgs; [
    # amazon-q  # Temporarily commented out due to build issues
    gcc
    vim 
    wget
    curl
    git
    pciutils
    usbutils
    tcpdump
    argocd
    terraform
    tailscale

    gnome-tweaks
    adwaita-icon-theme 
    mutter
  ];
  
  # Glances configuration with NVIDIA GPU support
  services.glances.enable = true;

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Enable subnet routing and exit node capabilities
    extraUpFlags = [
      "--ssh"
    ];
  };
  networking.firewall.enable = false;

  security.sudo.wheelNeedsPassword = false;
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = ["mobrienv"];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd
        ];
      };
      swtpm.enable = true;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # NFS client configuration
  services.rpcbind.enable = true;  # Required for NFS

  # NFS mount commented out as we now use local NVMe drive for /mnt/data
  fileSystems."/mnt/media" = {
    device = "10.10.10.8:/mnt/user/media";
    fsType = "nfs";
    options = [ "defaults" "x-systemd.automount" "noatime" ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  system.stateVersion = "24.11";
}

