# https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/cluster/k3s/README.md
{
  config,
  pkgs,
  ...
}: {
  services.k3s = {
    enable = true;
    role = "server";
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

  environment.systemPackages = with pkgs; [ 
    kubectl
    kubernetes-helm
    kubeseal
    kustomize
    kompose
    runc
    openiscsi
  ];
}
