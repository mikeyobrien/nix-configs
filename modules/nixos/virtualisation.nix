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
    boot.kernelParams = ["amd_iommu=on"]; # Use "amd_iommu=on" for AMD CPUs
  };
}
