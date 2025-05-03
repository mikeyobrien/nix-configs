{ config, pkgs, user, ... }: 
{
  system.stateVersion = "24.11";
  networking.firewall.enable = false;
  programs.fish.enable = true;
  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    initialPassword = "changeme";
  };
  
  security.sudo.wheelNeedsPassword = false;
  services.openssh.enable = true;
  environment.systemPackages = with pkgs; [
    vim
    curl
    git
    htop
  ];
  
  microvm.shares = [{
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
    tag = "ro-store";
    proto = "virtiofs";
  }];
  
  microvm.vcpu = 2;
  microvm.mem = 4096;
  microvm.volumes = [
    {
      image = "bastion-root.img";
      mountPoint = "/";
      size = 10240; # 10GB
    }
  ];
  
  # Network configuration
  microvm.interfaces = [
    {
      id = "vm-bastion";
      type = "tap";
      mac = "02:00:00:00:00:01";
    }
  ];
  systemd.network.enable = true;
  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = ["10.10.10.4/23"];
      Gateway = "10.10.10.1";
      DNS = ["10.10.10.1"];
      DHCP = "no";
    };
  };
}
