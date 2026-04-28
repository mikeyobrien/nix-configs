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

          # Writable /nix/store overlay so nix-daemon runs and devenv can build
          microvm.writableStoreOverlay = "/nix/.rw-store";

          # Resources (migrated from Arch VM)
          microvm.vcpu = 8;
          microvm.mem = 16384; # 16GB
          microvm.volumes = [
            {
              image = "tidepool-root.img";
              mountPoint = "/";
              size = 262144; # 256GB
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

    dad-openclaw = {
      autostart = true;
      config = {
        pkgs,
        lib,
        ...
      }: {
        system.stateVersion = "25.05";
        networking.hostName = "dad-openclaw";
        networking.firewall.enable = true;
        networking.firewall.allowedTCPPorts = [22];

        systemd.network.enable = true;
        systemd.network.networks."20-lan" = {
          matchConfig.Type = "ether";
          networkConfig = {
            Address = ["192.168.1.12/24"];
            Gateway = "192.168.1.1";
            DNS = ["192.168.1.1"];
            DHCP = "no";
          };
        };

        services.qemuGuest.enable = true;
        services.openssh = {
          enable = true;
          openFirewall = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        services.tailscale = {
          enable = true;
          package = pkgs.unstable.tailscale;
        };

        users.users.dad = {
          isNormalUser = true;
          home = "/home/dad";
          createHome = true;
          shell = pkgs.bashInteractive;
          linger = true;
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHapvH7MvONEfueUfeOSkKHiePO+tE0h5QjvqsFvrf7+ mobrienv@reef"
          ];
        };

        security.sudo = {
          enable = true;
          wheelNeedsPassword = true;
          extraRules = [
            {
              users = ["dad"];
              commands = [
                {
                  command = "/run/current-system/sw/bin/tailscale";
                  options = ["NOPASSWD"];
                }
                {
                  command = "${pkgs.unstable.tailscale}/bin/tailscale";
                  options = ["NOPASSWD"];
                }
              ];
            }
          ];
        };

        systemd.tmpfiles.rules = [
          "d /srv/openclaw-dad 0750 dad dad - -"
          "d /srv/openclaw-dad/workspace 0700 dad dad - -"
          "d /srv/openclaw-dad/data 0700 dad dad - -"
        ];

        environment.systemPackages = with pkgs; [
          curl
          git
          jq
          nodejs_22
          unstable.tailscale
        ];

        zramSwap = {
          enable = true;
          memoryPercent = 25;
        };

        microvm.vcpu = 1;
        microvm.mem = 2304;
        microvm.volumes = [
          {
            image = "dad-openclaw-root.img";
            mountPoint = "/";
            size = 16384; # 16GB
          }
        ];
        microvm.interfaces = [
          {
            id = "vm-dad-openclaw";
            type = "tap";
            mac = "02:00:00:00:00:12";
          }
        ];
      };
    };
  };
}
