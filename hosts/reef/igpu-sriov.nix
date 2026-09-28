{ lib, pkgs, ... }:
{
  # Keep Intel's physical GPU on reef for Jellyfin; expose only one VF to Omarchy.
  # Raptor Lake requires explicit opt-in to the stock xe driver.
  boot.kernelParams = lib.mkAfter [
    "i915.force_probe=!a780"
    "xe.force_probe=a780"
    "xe.max_vfs=1"
  ];
  boot.initrd.kernelModules = lib.mkAfter [ "xe" ];

  # Omarchy uses this unit instead of libvirt's automatic startup. Its persistent
  # XML stays Virtio-only, so GPU failure never makes the recovery domain invalid.
  systemd.services.omarchy-gpu-start = {
    description = "Start Omarchy with shared Intel VF, or Virtio recovery fallback";
    wantedBy = [ "multi-user.target" ];
    after = [ "libvirtd.service" "network-online.target" ];
    requires = [ "libvirtd.service" ];
    wants = [ "network-online.target" ];
    environment = {
      VIRSH = "${pkgs.libvirt}/bin/virsh";
      MODPROBE = "${pkgs.kmod}/bin/modprobe";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "omarchy-gpu-start";
      StateDirectoryMode = "0700";
      TimeoutStartSec = 180;
      ExecStart = "${pkgs.python3}/bin/python3 ${./omarchy-gpu-start.py}";
    };
  };
}
