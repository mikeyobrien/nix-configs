{ config, lib, pkgs, outputs, ... }:

{  
  imports =
    [ 
      ../default.nix
      ./hardware-configuration.nix
      ./guacamole.nix
      ./k3s.nix
      ./microvm.nix
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
    substituters = [
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1b21:0612 
    options kvm_intel nested=1
    options vfio_iommu_type1 allow_unsafe_interrupts=1
  '';

  # Enable Graphics
  hardware.graphics = {
    enable = true;
  };

  nixpkgs.config.nvidia.acceptLicense = true;
  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
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
    extraGroups = ["docker" "wheel" "libvirtd" "kvm" "qemu" "networkmanager" ];
    shell = pkgs.fish;
    hashedPasswordFile = config.age.secrets.password.path;
    openssh.authorizedKeys.keys = [];
  };

  environment.systemPackages = with pkgs; [
    gcc
    vim 
    wget
    curl
    git
    xfce.thunar
    xfce.xfce4-terminal
    pciutils
    usbutils
    tcpdump
    argocd
    terraform
  ];

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;
  networking.firewall.enable = false;

  security.sudo.wheelNeedsPassword = false;

  programs.virt-manager.enable = true;
  virtualisation = { 
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [(pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd];
        };
      };    
    };
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  programs.nix-ld.enable = false;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    libnvidia-container
  ];

  # NFS client configuration
  services.rpcbind.enable = true;  # Required for NFS
  fileSystems."/mnt/data" = {
    device = "10.10.10.8:/mnt/user/data";
    fsType = "nfs";
    options = [ "defaults" "x-systemd.automount" "noatime" ];
  };

  services.sunshine = {
    package = pkgs.unstable.sunshine;
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };


  system.stateVersion = "24.11";
}

