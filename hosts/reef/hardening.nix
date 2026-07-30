{
  # Keep root capacity available for k3s and live VM/MicroVM workloads. This
  # complements (but cannot replace) relocating large live disks off root.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };

  # Retain enough persistent logs for hard-freeze forensics without allowing
  # journals alone to consume the root filesystem.
  services.journald.extraConfig = ''
    SystemMaxUse=4G
    SystemKeepFree=100G
    SystemMaxFileSize=128M
    MaxRetentionSec=14day
  '';
}
