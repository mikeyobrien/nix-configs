{ config, lib, pkgs, inputs, outputs, ... }:
{
  # ---------------------------------------------------------------------------
  # Media stack: *arr suite + Sabnzbd + Jellyfin on the local XFS array.
  # These disks were the Unraid VM array (now retired); library is preserved
  # in-place at /mnt/array/<disk>/media. No reformat/migration performed.
  #
  # Additive mounts only -- does not touch /mnt/data or /mnt/synology/*
  # The legacy Unraid NFS share at /mnt/media was removed (unraid retired).
  #
  # Write access for the media services is granted at the filesystem layer
  # (setgid + group/world-writable library dirs), NOT via per-service group
  # options, which vary across modules and are not all supported (prowlarr).
  # ---------------------------------------------------------------------------

  fileSystems."/mnt/array/sdc1" = {
    device = "/dev/disk/by-uuid/5e723a8f-757e-4de3-8555-2a050eede7f3";
    fsType = "xfs";
    options = [ "nofail" "noatime" "x-systemd.device-timeout=10" ];
  };

  fileSystems."/mnt/array/sdd1" = {
    device = "/dev/disk/by-uuid/5ace78d6-8a06-40c7-845b-4d48cfb82ca9";
    fsType = "xfs";
    options = [ "nofail" "noatime" "x-systemd.device-timeout=10" ];
  };

  # Existing standalone SSD filesystems, preserved in-place (2026-10-23).
  # Mount the top-level subvolume explicitly; do not pool or reformat them.
  fileSystems."/mnt/storage/ssd-2tb" = {
    device = "/dev/disk/by-uuid/1da513ea-88ad-43d8-bbd4-8608ca7baf68";
    fsType = "btrfs";
    options = [ "nofail" "noatime" "subvolid=5" "x-systemd.device-timeout=10" ];
  };

  fileSystems."/mnt/storage/ssd-1tb" = {
    device = "/dev/disk/by-uuid/67fd254f-6381-4369-850e-bae7f3c8de4a";
    fsType = "btrfs";
    options = [ "nofail" "noatime" "subvolid=5" "x-systemd.device-timeout=10" ];
  };

  # Keep legacy model paths stable after moving weights to the SATA SSD.
  # Explicit dependency prevents binding an empty directory on the root disk.
  fileSystems."/home/mobrienv/club-3090/models-cache" = {
    device = "/mnt/storage/ssd-2tb/reef/models/club-3090-cache";
    fsType = "none";
    options = [
      "bind"
      "nofail"
      "x-systemd.requires-mounts-for=/mnt/storage/ssd-2tb"
      "x-systemd.before=docker.service"
    ];
  };

  # Intel VA-API media driver for iGPU transcode (UHD 770). The RTX 3090s stay
  # exclusively on vLLM/llama workloads -- NVENC must not be relied upon.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  services.prowlarr.enable = true; # indexer aggregation (port 9696)
  services.sonarr.enable = true; # TV (8989)
  services.radarr.enable = true; # Movies (7878)
  services.bazarr.enable = true; # subtitles (6767)
  services.sabnzbd.enable = true; # usenet download client (8080)
  services.jellyfin.enable = true; # media server (8096)

  # iGPU /dev/dri access for Jellyfin hardware transcode
  users.users.jellyfin.extraGroups = [ "video" "render" ];

  # Convention: media roots live at /mnt/array/<disk>/media on each array
  # member. Configure root folders on the *arrs against those paths.
}
