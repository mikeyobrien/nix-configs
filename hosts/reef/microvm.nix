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
            extraGroups = ["wheel" "docker"];
            initialPassword = "changeme";
            linger = true;
          };

          security.sudo.wheelNeedsPassword = false;
          services.openssh.enable = true;

          # Prevent systemd from killing background processes when sessions end
          services.logind.killUserProcesses = false;

          # Raise kernel-wide and per-process resource limits for dev workloads
          boot.kernel.sysctl."fs.file-max" = 2097152;
          systemd.extraConfig = ''
            DefaultLimitNOFILE=1048576
            DefaultLimitNPROC=65536
            DefaultTasksMax=65536
          '';
          systemd.user.extraConfig = ''
            DefaultLimitNOFILE=1048576
            DefaultLimitNPROC=65536
            DefaultTasksMax=65536
          '';

          # XFCE desktop (headless VM — no display manager, accessed via xrdp only)
          services.xserver.enable = true;
          services.xserver.dpi = 192;
          services.xserver.desktopManager.xfce.enable = true;
          services.xserver.displayManager.lightdm.enable = lib.mkForce false;
          services.displayManager.enable = lib.mkForce false;

          # xrdp for remote desktop access
          services.xrdp.enable = true;
          services.xrdp.defaultWindowManager = "startxfce4";
          services.xrdp.openFirewall = true;

          services.tailscale = {
            enable = true;
            package = pkgs.tailscale;
            extraUpFlags = ["--ssh"];
          };

          virtualisation.docker.enable = true;

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
            cmake
            glibc.bin
            nodejs_22
            pnpm
            gh
            rsync
            tailscale
            unzip
            unstable.bun
          ];

          # Home Manager
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
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
