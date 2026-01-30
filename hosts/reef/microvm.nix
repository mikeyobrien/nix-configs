{
  config,
  lib,
  pkgs,
  user,
  inputs,
  outputs,
  ...
}: {
  microvm.vms = {
    tidepool = {
      autostart = true;
      config = let
        inherit inputs outputs user;
      in
        {
          config,
          pkgs,
          lib,
          ...
        }: {
          imports = [
            inputs.home-manager.nixosModules.home-manager
          ];

          system.stateVersion = "24.11";
          networking.hostName = "tidepool";
          networking.firewall.enable = false;

          nix.settings = {
            experimental-features = ["nix-command" "flakes"];
            trusted-users = ["root" user];
          };

          programs.fish.enable = true;
          users.users.${user} = {
            isNormalUser = true;
            home = "/home/${user}";
            shell = pkgs.fish;
            extraGroups = ["wheel"];
            initialPassword = "changeme";
          };

          security.sudo.wheelNeedsPassword = false;
          services.openssh.enable = true;

          services.tailscale = {
            enable = true;
            extraUpFlags = ["--ssh"];
          };

          programs.nix-ld.enable = true;
          programs.nix-ld.libraries = with pkgs; [
            stdenv.cc.cc.lib
            zlib
          ];

          environment.systemPackages = with pkgs; [
            vim
            curl
            git
            htop
            gcc
            gnumake
            nodejs
            gh
            rsync
          ];

          # Home Manager
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = ./tidepool-home.nix;
          home-manager.extraSpecialArgs = {
            currentSystem = "x86_64-linux";
            inherit user inputs outputs;
            isDarwin = false;
            isWsl = false;
          };

          # Shares
          microvm.shares = [
            {
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              tag = "ro-store";
              proto = "virtiofs";
            }
            {
              source = "/home/${user}/code";
              mountPoint = "/home/${user}/code";
              tag = "code";
              proto = "virtiofs";
            }
          ];

          # Resources (migrated from Arch VM)
          microvm.vcpu = 8;
          microvm.mem = 16384; # 16GB
          microvm.volumes = [
            {
              image = "tidepool-root.img";
              mountPoint = "/";
              size = 65536; # 64GB
            }
          ];

          # Network configuration
          microvm.interfaces = [
            {
              id = "vm-tidepool";
              type = "tap";
              mac = "02:00:00:00:00:01";
            }
          ];
          systemd.network.enable = true;
          systemd.network.networks."20-lan" = {
            matchConfig.Type = "ether";
            networkConfig = {
              Address = ["192.168.1.9/24"];
              Gateway = "192.168.1.1";
              DNS = ["192.168.1.1"];
              DHCP = "no";
            };
          };
        };
    };
  };
}
