{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: {
  imports = [
    ../default.nix
    ./hardware-configuration.nix
    ./k3s.nix
    ./microvm.nix
    #./ups.nix
    # TODO: Unable to initialize capture methodAdd Cachix
  ];

  nixpkgs.config.allowUnfree = true;
  # libolm is upstream-archived; needed for Matrix E2EE via matrix-nio
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];
  nixpkgs.overlays = [
    outputs.overlays.modifications
    outputs.overlays.additions
    outputs.overlays.unstable-packages
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "mobrienv"];
  };

  # Increase nix-daemon file descriptor limit for large builds (microVM chroot sandboxing)
  systemd.services.nix-daemon.serviceConfig.LimitNOFILE = 1048576;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "fs.file-max" = lib.mkForce 2097152;
  };

  boot.kernelParams = ["intel_iommu=on" "iommu=pt"];
  boot.initrd.kernelModules = [
    "nvidia"
    "i915"
    "nvidia_modeset"
    "nvidia_drm"
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1b21:0612,10de:2204
    options kvm_intel nested=1
    options vfio_iommu_type1 allow_unsafe_interrupts=1
  '';

  # Enable Graphics
  hardware.graphics = {
    enable = true;
  };

  services.xserver = {
    enable = true;
    videoDrivers = ["nvidia"];
    displayManager.gdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "mobrienv";
    desktopManager.gnome.enable = true;
  };

  # Auto-login workaround
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  nixpkgs.config.nvidia.acceptLicense = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    # nixos-25.05's nvidiaPackages.latest pins to 570.x; vLLM nightly's CUDA 13
    # runtime requires driver >=580. Pull 595.58.03 from unstable but rebuild
    # the kernel module against this host's kernel.
    package = (pkgs.unstable.linuxKernel.packagesFor config.boot.kernelPackages.kernel).nvidiaPackages.production;
    open = true; # Use open source kernel modules for RTX/Turing+ GPUs
  };

  networking.hostName = "reef"; # Define your hostname.
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = ["enp5s0" "vm-*"];
    networkConfig = {
      Bridge = "br0";
    };
  };

  systemd.network.netdevs."br0" = {
    netdevConfig = {
      Name = "br0";
      Kind = "bridge";
    };
  };

  systemd.network.networks."10-lan-bridge" = {
    matchConfig.Name = "br0";
    networkConfig = {
      Address = ["192.168.1.2/24"];
      Gateway = "192.168.1.1";
      DNS = ["192.168.1.1"];
    };
    linkConfig.RequiredForOnline = "routable";
  };

  environment.gnome.excludePackages =
    (with pkgs; [
      gnome-photos
      gnome-tour
    ])
    ++ (with pkgs; [
      cheese # webcam tool
      gnome-music
      epiphany # web browser
      geary # email reader
      gnome-characters
      tali # poker game
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
      yelp # Help view
      gnome-contacts
      gnome-initial-setup
    ]);

  programs.dconf.enable = true;
  networking = {
    bridges = {
      br0 = {
        interfaces = ["enp5s0"];
      };
    };
    interfaces = {
      br0.useDHCP = false;
      enp5s0.useDHCP = false;
    };
  };

  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  ## Define a user account. Don't forget to set a password with ‘passwd’.
  programs.fish.enable = true;
  programs.zsh.enable = true;
  users.users.mobrienv = {
    isNormalUser = true;
    home = "/home/mobrienv";
    extraGroups = ["docker" "wheel" "libvirtd" "kvm" "qemu" "input"];
    shell = pkgs.zsh;
    hashedPasswordFile = config.age.secrets.password.path;
    openssh.authorizedKeys.keys = [];
  };

  environment.systemPackages = with pkgs; [
    # amazon-q  # Temporarily commented out due to build issues
    gcc
    vim
    wget
    curl
    git
    pciutils
    usbutils
    tcpdump
    argocd
    terraform
    pkgs.unstable.tailscale
    gh

    gnome-tweaks
    adwaita-icon-theme
    mutter
  ];

  # Glances configuration with NVIDIA GPU support
  services.glances.enable = false;

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    package = pkgs.unstable.tailscale;
    useRoutingFeatures = "both"; # Enable subnet routing and exit node capabilities
    extraUpFlags = [
      "--ssh"
    ];
  };
  networking.firewall.enable = false;

  security.sudo.wheelNeedsPassword = false;
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = ["mobrienv"];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd
        ];
      };
      swtpm.enable = true;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;

  # Set GPU power limits on boot (default 420W → 220W per card)
  # Lowered from 275W to 220W after two unexplained hard reboots during
  # vLLM TP=2 dual-3090 sustained load (no kernel logs, no Xid, no OOM —
  # signature of PSU sag / undervoltage trip). 220W matches the upstream
  # qwen36-vllm-setup repo's recommended GPU_POWER_LIMIT for stacked 3090s.
  systemd.services.nvidia-power-limit = let
    smi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  in {
    description = "Set NVIDIA GPU power limits (220W each)";
    after = ["nvidia-persistenced.service"];
    wantedBy = ["multi-user.target"];
    before = ["llama-server.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${smi} -i 0 -pl 220"
        "${smi} -i 1 -pl 220"
      ];
    };
  };

  # llama.cpp: Qwen3.6-35B-A3B UD-Q8_K_XL on dual 3090, 262K q8 KV (:8001)
  systemd.services.llama-server = {
    description = "llama.cpp Qwen3.6-35B-A3B Q8_K_XL (dual 3090, 262K :8001)";
    after = ["network.target"];
    conflicts = [ "dflash-server.service" ];
    # Manual-start; dflash-server is the boot default. Bring this up with
    #   sudo systemctl stop dflash-server && sudo systemctl start llama-server
    # when you want the 35B Q8 instead.
    environment = {
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
      IDLE_TIMEOUT = "86400";
    };
    serviceConfig = {
      Type = "simple";
      User = "mobrienv";
      ExecStart = "/run/current-system/sw/bin/bash /home/mobrienv/run-llm.sh 3.6-q8";
      ExecStop = "/run/current-system/sw/bin/bash /home/mobrienv/run-llm.sh stop";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # vLLM: Qwen3.6-27B FP8 full-context serving, dual 3090 (:8000)
  # Calls run-systemd.sh which exports pinned /nix/store paths (CUDA toolkit,
  # cudnn, nccl, gcc-lib, zlib, python) plus TRITON_LIBCUDA_PATH and the
  # LIBRARY_PATH stub-dir workaround. Bypasses nix-shell at runtime to avoid
  # binary-cache misses + CUDA 12.8 cicc segfault during nccl rebuild.
  # Runtime model/precision/context knobs live in /home/mobrienv/qwen36-vllm-setup.
  # GC roots for the pinned paths live in /nix/var/nix/gcroots/per-user/mobrienv/.
  systemd.services.dflash-server = {
    description = "vLLM Qwen3.6-27B FP8 full-context (dual 3090, 262144 ctx, :8000)";
    after = [ "network.target" "nvidia-power-limit.service" ];
    conflicts = [ "llama-server.service" ];
    wantedBy = [ ];   # manual-start; replaced by qwen36-dual-3090 docker stack on :8010

    serviceConfig = {
      Type = "simple";
      User = "mobrienv";
      ExecStart = "/home/mobrienv/qwen36-vllm-setup/run-systemd.sh";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 60;
      KillMode = "control-group";
    };
  };

  # Hermes Agent - local AI agent with hardened systemd service
  services.hermes-agent = {
    enable = false; # decommission runtime on reef; keep Hermes files/config around
    # Override the package to include matrix-nio[e2e] (upstream excludes it from
    # [all] because python-olm builds are broken on macOS — fine on Linux).
    package = let
      # Build env with matrix-nio + e2e deps + brotli, then scrub aiohttp out
      # of the site-packages so Hermes's own aiohttp (3.13.3) is the only one
      # on sys.path. Two aiohttp versions in PYTHONPATH + venv site-packages
      # results in the .so coming from one while HAS_BROTLI is computed from
      # the other — breaks brotli decompression on Cloudflare-fronted Matrix.
      matrixPyEnvRaw = pkgs.python311.withPackages (ps:
        # No E2EE on reef: python-olm + brotlicffi both pull nixpkgs cffi 1.17.1
        # which ABI-conflicts with Hermes's own cffi 2.0.0. Google brotli is
        # pure C and conflict-free; sitecustomize below patches aiohttp 3.13.3
        # to call google brotli's Decompressor.process() with one arg.
        [ ps.matrix-nio ps.brotli ]);
      # aiohttp 3.13.3 (bundled in Hermes's own venv) calls
      # brotli.Decompressor().decompress(data, max_length) — but neither
      # google-brotli nor brotlicffi support max_length. Patch
      # BrotliDecompressor.decompress_sync at Python startup to drop the arg.
      brotliFixSitecustomize = pkgs.writeText "sitecustomize.py" ''
        try:
            from aiohttp.compression_utils import BrotliDecompressor
            def _patched_decompress_sync(self, data, max_length=0):
                if hasattr(self._obj, "decompress"):
                    return self._obj.decompress(data)
                return self._obj.process(data)
            BrotliDecompressor.decompress_sync = _patched_decompress_sync
        except Exception as _e:
            import sys
            print("sitecustomize brotli patch failed:", _e, file=sys.stderr)
      '';
      matrixPyEnv = pkgs.runCommand "matrix-py-env-compat" { } ''
        # Exclude any package Hermes's own venv already has that would ABI-
        # conflict: aiohttp (version skew + brotli), pycryptodome/Crypto, cffi,
        # cryptography. Those get picked up from Hermes's venv on sys.path.
        OUTSP="$out/lib/python3.11/site-packages"
        mkdir -p "$OUTSP"
        for f in ${matrixPyEnvRaw}/lib/python3.11/site-packages/*; do
          name=$(basename "$f")
          case "$name" in
            aiohttp|aiohttp-*) continue ;;
            Crypto|pycryptodome-*) continue ;;
            cffi|cffi-*|_cffi_backend*) continue ;;
            cryptography|cryptography-*) continue ;;
          esac
          ln -s "$f" "$OUTSP/$name"
        done
        install -m 0644 ${brotliFixSitecustomize} "$OUTSP/sitecustomize.py"
      '';
      origHermes = inputs.hermes-agent.packages.${pkgs.system}.default;
    in pkgs.symlinkJoin {
      name = "hermes-agent-with-matrix";
      paths = [ origHermes ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in hermes hermes-agent hermes-acp; do
          if [ -L "$out/bin/$bin" ]; then
            target=$(readlink -f "$out/bin/$bin")
            rm "$out/bin/$bin"
            makeWrapper "$target" "$out/bin/$bin" \
              --prefix PYTHONPATH : "${matrixPyEnv}/lib/python3.11/site-packages"
          fi
        done
      '';
    };
    settings = {
      model = {
        base_url = "http://127.0.0.1:8002/v1";
        default = "gemma-4-26b";
      };
      max_turns = 150;
      toolsets = ["all"];
      terminal = {
        backend = "local";
        timeout = 300;
      };
      compression = {
        enabled = true;
        threshold = 0.7;
        summary_model = "gemma-4-26b";
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      display = {
        compact = false;
        personality = "concise";
      };
      discord = {
        require_mention = true;
      };
    };
    environment = {
      MATRIX_HOMESERVER = "https://matrix.mobrienv.dev";
      MATRIX_USER_ID = "@nalani:matrix.mobrienv.dev";
      # NOTE: MATRIX_ACCESS_TOKEN is a secret — belongs in the agenix-encrypted
      # hermes-env.age file. Add this line to it via `agenix -e secrets/hermes-env.age`:
      #   MATRIX_ACCESS_TOKEN=<token>
      # Until then, the token is expected to be in hermes-env.age already.
    };
    environmentFiles = [
      config.age.secrets.hermes-env.path
    ];
    user = "mobrienv";
    group = "users";
    createUser = false;
    addToSystemPackages = true;
  };

  # Relax sandbox since running as user, but only when Hermes is enabled.
  systemd.services.hermes-agent = lib.mkIf config.services.hermes-agent.enable {
    serviceConfig = {
      ProtectSystem = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      NoNewPrivileges = lib.mkForce false;
      ReadWritePaths = lib.mkForce [];
    };
  };

  age.secrets.hermes-env = {
    file = ../../secrets/hermes-env.age;
    owner = "mobrienv";
    group = "users";
    mode = "0400";
  };

  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Local NVMe data drive for Immich photos/videos
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/101cbd70-c8a7-41b0-985f-8fc8e3d55486";
    fsType = "ext4";
  };

  # NFS client configuration
  services.rpcbind.enable = true; # Required for NFS

  fileSystems."/mnt/media" = {
    device = "192.168.1.8:/mnt/user/media";
    fsType = "nfs";
    options = ["defaults" "x-systemd.automount" "noatime"];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Enable nix-ld for dynamically linked binaries
  programs.nix-ld.enable = true;

  system.stateVersion = "24.11";
}
