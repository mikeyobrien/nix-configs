{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.virtualisation;
in {
  options.virtualisation = {
    enable = lib.mkEnableOption "virtualisation";
    username = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "The username of the user that will be added to the libvirtd group.";
    };
    iommuParam = lib.mkOption {};
      type = lib.types.str;
      default = "amd_iommu=on";
      description = "The kernal param to use for PCI passthrough one of amd_iommu=on or intel_iommu=on";
    };
  };
  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.qemu.package = pkgs.qemu_kvm;

    # Add yourself to the libvirtd group
    users.users.${cfg.username}.extraGroups = ["libvirtd"];

    # Install necessary packages
    environment.systemPackages = with pkgs; [
      virt-manager
      qemu
      OVMF
    ];

    # Enable IOMMU (if you plan to use PCI passthrough)
    boot.kernelParams = [cfg.kernalParams]; # Use "amd_iommu=on" for AMD CPUs
  };
}
