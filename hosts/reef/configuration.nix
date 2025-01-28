{ config, lib, pkgs, ... }:

{
  imports =
    [ 
      ../default.nix
      ./hardware-configuration.nix
      ./guacamole.nix
      # TODO: Add Cachix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

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
  '';

  services.xserver.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  services.displayManager.sddm.enable = true;
  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "mobrienv";
  };
  services.desktopManager.plasma6.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  networking.hostName = "reef"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking = {
    bridges = {
      br0 = {
        interfaces = [ "enp5s0" ];
      };
    };
    interfaces = {
      br0.useDHCP = true;
      enp5s0.useDHCP = false;
    };
  };
  
  time.timeZone = "Americas/Chicago";

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
    vim 
    wget
    curl
    git
    pciutils
    usbutils
    tcpdump
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

  system.stateVersion = "24.11";
}

