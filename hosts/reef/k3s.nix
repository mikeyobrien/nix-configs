# https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/README.md
{
  config,
  pkgs,
  ...
}: {
  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.unstable.k3s;
    tokenFile = config.age.secrets.k3s_secret.path;
    clusterInit = true;
    extraFlags = toString [
      "--disable=traefik"
      "--write-kubeconfig-mode=660"
      "--write-kubeconfig-group=users"
    ];
  };

  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };

  hardware = {
    nvidia-container-toolkit.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  # Longhorn prerequisites
  services.openiscsi = {
    enable = true;
    name = "iqn.2023-01.dev.mobrienv:${config.networking.hostName}";
  };

  # Enable NFS client for Longhorn disaster recovery support
  services.nfs.server = {
    enable = true;
    enableNFSv4 = true;
  };

  # Create the default Longhorn data directory
  systemd.tmpfiles.rules = [
    "d /var/lib/longhorn 0755 root root -"
  ];

  # Kernel modules required by Longhorn
  boot.kernelModules = [
    "iscsi_tcp"    # iSCSI support
    "nfs"          # NFS support
  ];

  # System settings for better performance with Longhorn
  boot.kernel.sysctl = {
    # Increase maximum number of file handles
    "fs.file-max" = 100000;
    # Increase memory map limits
    "vm.max_map_count" = 262144;
  };

  # Firewall rules for Longhorn (if firewall is enabled)
  networking.firewall.allowedTCPPorts = [
    8443          # Longhorn UI/API
    9500          # Longhorn CSI
    31999         # Backup store port
  ];

  environment.systemPackages = with pkgs; [ 
    kubectl
    kubernetes-helm
    kubeseal
    kustomize
    kompose
    runc
    openiscsi
    nfs-utils      # For NFS client support
    util-linux     # For tools like blkid, lsblk
    e2fsprogs      # For ext4 filesystem tools
    xfsprogs       # For XFS filesystem tools
    jq             # Used by some Longhorn scripts
    iscsi-initiator-utils # Additional iSCSI tools
  ];
}
