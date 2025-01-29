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
    ];
  };

  hardware.opengl.driSupport32Bit = true;
  hardware.nvidia-container-toolkit.enable = true;
  environment.systemPackages = with pkgs; [ runc ];
}
