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
    ./ups.nix
    ./media.nix
    # TODO: Unable to initialize capture methodAdd Cachix
  ];

  nixpkgs.config.allowUnfree = true;
  # libolm is upstream-archived; needed for Matrix E2EE via matrix-nio
  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
  nixpkgs.overlays = [
    outputs.overlays.modifications
    outputs.overlays.additions
    outputs.overlays.unstable-packages
  ];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "mobrienv"];
    # Cap build parallelism: unbounded builds starve the vLLM workers on :8010,
    # whose engine dies on shm_broadcast timeout when CPU/RAM are exhausted.
    max-jobs = 4;
    cores = 4;
  };

  # Increase nix-daemon file descriptor limit for large builds (microVM chroot sandboxing)
  systemd.services.nix-daemon.serviceConfig.LimitNOFILE = 1048576;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
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
    # Both RTX 3090s (10de:2204) are host vLLM devices. Do not bind them to
    # vfio-pci; doing so races the NVIDIA driver during initrd activation.
    options kvm_intel nested=1
    options vfio_iommu_type1 allow_unsafe_interrupts=1
    options netconsole netconsole=6665@192.168.1.2/br0,6666@192.168.1.3/1c:1d:d3:d8:b5:a2
  '';

  # Crash forensics (added 2026-07-06 after silent hard freezes under
  # dual-3090 llama.cpp load — suspected patched-P2P driver hang):
  # stream kernel log to rook (192.168.1.3, run `nc -ulk 6666` there)
  # so a freeze's final messages survive off-box.
  boot.kernelModules = ["netconsole"];
  # iTCO hardware watchdog: systemd feeds it; a 60s kernel hard-freeze
  # force-reboots instead of wedging until manual power-cycle.
  systemd.watchdog = {
    runtimeTime = "60s";
    rebootTime = "120s";
  };

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
    # 2026-07-07: REVERTED the aikitoria 595.58.03-p2p patched open module.
    # It went live (uncommitted) 2026-06-21 and correlates 1:1 with the return
    # of silent hard freezes (Jun 28, Jul 6, Jul 7) after 8 stable weeks on
    # stock; nothing uses GPU P2P anymore (vLLM: NCCL_P2P_DISABLE=1 +
    # --disable-custom-all-reduce; llama.cpp: GGML_CUDA_NO_PEER_COPY build).
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
    description = "Set NVIDIA GPU power limits (160W each)";
    after = ["nvidia-persistenced.service"];
    wantedBy = ["multi-user.target"];
    before = ["club3090-qwen36-docker.service" "qwen36-vllm.service" "llama-server.service" "dflash-server.service" "ornith-server.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${smi} -i 0 -pl 160"
        "${smi} -i 1 -pl 160"
      ];
    };
  };

  # club-3090 Docker stack: Qwen3.6-35B-A3B AutoRound INT4 (:8010).
  # Switched from the 27B AutoRound compose 2026-07-07 (same club-3090 base:
  # pinned vLLM v0.22.0, NCCL_P2P_DISABLE=1 baked in, repo-validated fp8.yml —
  # 262K ctx, MTP intentionally off on this MoE). 27B compose remains on disk
  # for manual rollback (fp8-mtp.yml in the qwen3.6-27b dir).
  # Docker's own restart policy can race the NVIDIA CDI generator during boot,
  # leaving the container exited with "could not select device driver cdi".
  # Start it after CDI and Docker are ready so reef comes back serving.
  systemd.services.club3090-qwen36-docker = {
    description = "club-3090 Qwen3.6-35B-A3B AutoRound Docker vLLM stack (:8010)";
    after = [
      "network-online.target"
      "docker.service"
      "nvidia-container-toolkit-cdi-generator.service"
      "nvidia-power-limit.service"
    ];
    wants = ["network-online.target"];
    requires = [
      "docker.service"
      "nvidia-container-toolkit-cdi-generator.service"
    ];
    wantedBy = []; # manual-start; superseded by llama.cpp containers on :8010 (2026-07-25)
    conflicts = ["qwen36-vllm.service" "llama-server.service" "dflash-server.service" "ornith-server.service"];
    path = [pkgs.docker pkgs.bash pkgs.coreutils];
    environment = {
      NVLINK_MODE = "pcie_p2p";
      NCCL_P2P_LEVEL = "PHB";
      ESTATE_PORT = "8010";
      MAX_NUM_SEQS = "8";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/home/mobrienv/club-3090/models/qwen3.6-35b-a3b/vllm/compose/dual/autoround-int4";
      ExecStart = "${pkgs.docker}/bin/docker compose -f fp8.yml -f docker-compose.override.yml up -d";
      ExecStop = "${pkgs.docker}/bin/docker compose -f fp8.yml -f docker-compose.override.yml stop";
      Restart = "on-failure";
      RestartSec = 15;
      TimeoutStartSec = 120;
      TimeoutStopSec = 60;
    };
  };

  # llama.cpp: Qwen3.6-35B-A3B UD-Q8_K_XL on dual 3090, 262K q8 KV (:8001)
  systemd.services.llama-server = {
    description = "llama.cpp Qwen3.6-35B-A3B Q8_K_XL (dual 3090, 262K :8001)";
    after = ["network.target"];
    conflicts = ["qwen36-vllm.service" "dflash-server.service"];
    # Manual-start; stop any Docker LLM stack on :8010 before starting this
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

  # llama.cpp: Ornith-1.0-35B Q4_K_M on dual 3090, 2x 262K q4_0 KV (:8010)
  # Manual-start since 2026-07-07: boot default on :8010 is the club3090
  # 35B-A3B AutoRound vLLM stack. Start this instead with
  # `systemctl start ornith-server` (conflicts stop the docker stack).
  # start-ornith.sh execs llama-server (sets LD_LIBRARY_PATH itself); systemd
  # tracks that PID and SIGTERM stops it cleanly.
  systemd.services.ornith-server = {
    description = "llama.cpp Ornith-1.0-35B Q4_K_M (dual 3090, 2x262K :8010)";
    after = ["network.target" "nvidia-power-limit.service"];
    wantedBy = [];
    conflicts = ["club3090-qwen36-docker.service" "qwen36-vllm.service" "llama-server.service" "dflash-server.service"];
    environment = {
      LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    };
    serviceConfig = {
      Type = "simple";
      User = "mobrienv";
      ExecStart = "/run/current-system/sw/bin/bash /home/mobrienv/models/ornith/start-ornith.sh";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 60;
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
    after = ["network.target" "nvidia-power-limit.service"];
    conflicts = ["qwen36-vllm.service" "llama-server.service"];
    wantedBy = []; # manual-start; replaced by qwen36-dual-3090 docker stack on :8010

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

  # vLLM 0.23 host-native Qwen3.6-27B service (:8010).
  #
  # This is intentionally more conservative than club-3090's Docker default:
  # no MTP speculation, no prefix caching, generic fp8 KV, and 4096 batched
  # tokens. On reef, the Docker v0.22.0 fp8/MTP path repeatedly wedged with
  # EngineDeadError: sample_tokens timed out; forcing Triton attention exposed
  # separate fp8_e5m2 / fp8e4nv compile failures on Ampere. This host-native
  # venv path passed verify-full and the canonical bench without that failure.
  # Host-native v0.23 AutoRound+MTP was also rejected: ~87/111 TPS, but
  # verify-stress reproduced sample_tokens timeout / EngineDeadError.
  # Keep gpu_memory_utilization at 0.97, not 0.98: 0.98 functionally filled
  # to 240,635 tokens but left only 918 MiB free at the ceiling ladder, below
  # verify-stress's 1 GiB agent-overhead margin.
  systemd.services.qwen36-vllm = let
    cuda = pkgs.cudaPackages.cudatoolkit;
    nvcc = pkgs.cudaPackages.cuda_nvcc;
    qwen36Vllm = pkgs.writeShellScript "qwen36-vllm" ''
      set -euo pipefail

      export CUDA_HOME=${cuda}
      export PATH=${pkgs.bashInteractive}/bin:${pkgs.coreutils}/bin:${nvcc}/bin:${pkgs.gcc}/bin:${pkgs.ninja}/bin:${cuda}/bin:/run/current-system/sw/bin
      export LD_LIBRARY_PATH=${pkgs.gcc.cc.lib}/lib:${cuda}/lib:/run/opengl-driver/lib
      export LIBRARY_PATH=${cuda}/lib:/run/opengl-driver/lib
      export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib

      export VLLM_WORKER_MULTIPROC_METHOD=spawn
      export VLLM_NO_USAGE_STATS=1
      export VLLM_ALLOW_LONG_MAX_MODEL_LEN=1
      unset VLLM_USE_FLASHINFER_SAMPLER || true
      export OMP_NUM_THREADS=1
      export NCCL_CUMEM_ENABLE=0
      export NCCL_P2P_DISABLE=1
      export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512

      cd /home/mobrienv/club-3090
      exec /home/mobrienv/.venvs/qwen-vllm-autoround/bin/vllm serve /home/mobrienv/club-3090/models-cache/cyankiwi-qwen3.6-27b-awq-bf16-int4 \
        --served-model-name qwen3.6-27b-autoround cyankiwi-qwen3.6-27b-awq-bf16-int4 \
        --dtype float16 \
        --tensor-parallel-size 2 \
        --pipeline-parallel-size 1 \
        --max-model-len 262144 \
        --gpu-memory-utilization 0.97 \
        --mm-encoder-tp-mode data \
        --kv-cache-dtype fp8 \
        --max-num-seqs 2 \
        --max-num-batched-tokens 4096 \
        --trust-remote-code \
        --reasoning-parser qwen3 \
        --default-chat-template-kwargs '{"enable_thinking": false}' \
        --enable-auto-tool-choice \
        --tool-call-parser qwen3_coder \
        --enable-chunked-prefill \
        --performance-mode interactivity \
        --override-generation-config '{"temperature":0.6,"top_p":0.95,"top_k":20,"min_p":0.0,"repetition_penalty":1.0}' \
        --disable-custom-all-reduce \
        --host 0.0.0.0 \
        --port 8010
    '';
  in {
    description = "vLLM cyankiwi Qwen3.6-27B AWQ/BF16/INT4 (dual 3090, 262K :8010)";
    after = ["network-online.target" "nvidia-power-limit.service"];
    wants = ["network-online.target"];
    conflicts = ["dflash-server.service" "llama-server.service"];
    wantedBy = []; # manual-start; Docker club-3090 owns :8010 on reef
    startLimitIntervalSec = 900;
    startLimitBurst = 3;

    serviceConfig = {
      Type = "simple";
      User = "mobrienv";
      WorkingDirectory = "/home/mobrienv/club-3090";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/test -x /home/mobrienv/.venvs/qwen-vllm-autoround/bin/vllm"
        "${pkgs.coreutils}/bin/test -d /home/mobrienv/club-3090/models-cache/cyankiwi-qwen3.6-27b-awq-bf16-int4"
      ];
      ExecStart = "${qwen36Vllm}";
      Restart = "always";
      RestartSec = 30;
      TimeoutStopSec = 90;
      KillMode = "control-group";
      LimitNOFILE = 1048576;
    };
  };

  systemd.services.qwen36-vllm-watchdog = {
    description = "Restart the club-3090 vLLM container if the OpenAI endpoint stops answering";
    after = ["club3090-qwen36-docker.service"];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      state="$(${pkgs.systemd}/bin/systemctl show club3090-qwen36-docker.service --property=ActiveState --value || true)"

      case "$state" in
        activating|deactivating)
          exit 0
          ;;
        failed|inactive|"")
          ${pkgs.systemd}/bin/systemctl reset-failed club3090-qwen36-docker.service || true
          ${pkgs.systemd}/bin/systemctl restart club3090-qwen36-docker.service
          exit 0
          ;;
      esac

      active_usec="$(${pkgs.systemd}/bin/systemctl show club3090-qwen36-docker.service --property=ActiveEnterTimestampMonotonic --value || echo 0)"
      read -r uptime _ < /proc/uptime
      uptime_sec="''${uptime%%.*}"
      active_sec="$((active_usec / 1000000))"
      if [ "$active_sec" -gt 0 ] && [ "$((uptime_sec - active_sec))" -lt 600 ]; then
        exit 0
      fi

      if ${pkgs.curl}/bin/curl --noproxy '*' -fsS --max-time 5 http://127.0.0.1:8010/health >/dev/null; then
        exit 0
      fi

      ${pkgs.systemd}/bin/systemctl restart club3090-qwen36-docker.service
    '';
  };

  systemd.timers.qwen36-vllm-watchdog = {
    wantedBy = []; # disabled: restarted the retired vLLM stack against the live llama.cpp :8010 container
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "2min";
      Unit = "qwen36-vllm-watchdog.service";
    };
  };

  # Fail-closed vLLM watchdog (2026-07-27).
  #
  # A confirmed dead EngineCore previously triggered an automatic 18 GiB model
  # reload, immediately before a whole-host lock. Keep the endpoint down instead:
  # confirm failure, stop once, alert Telegram, and require manual recovery.
  environment.etc."local/bin/llm-endpoint-watchdog-stop-alert.sh" = {
    source = ./llm-endpoint-watchdog-stop-alert.sh;
    mode = "0755";
  };

  systemd.services.llm-endpoint-watchdog = {
    description = "Stop and alert when Reef vLLM is confirmed unhealthy";
    after = ["docker.service" "network-online.target"];
    wants = ["network-online.target"];
    path = [pkgs.bash pkgs.docker pkgs.curl pkgs.coreutils pkgs.gnused];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "llm-endpoint-watchdog";
      StateDirectoryMode = "0700";
      ExecStart = "/etc/local/bin/llm-endpoint-watchdog-stop-alert.sh";
    };
  };

  systemd.timers.llm-endpoint-watchdog = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "2min";
      Unit = "llm-endpoint-watchdog.service";
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
        [ps.matrix-nio ps.brotli]);
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
      matrixPyEnv = pkgs.runCommand "matrix-py-env-compat" {} ''
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
    in
      pkgs.symlinkJoin {
        name = "hermes-agent-with-matrix";
        paths = [origHermes];
        buildInputs = [pkgs.makeWrapper];
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

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Local NVMe data drive for Immich photos/videos
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/101cbd70-c8a7-41b0-985f-8fc8e3d55486";
    fsType = "ext4";
  };

  # NFS client configuration
  services.rpcbind.enable = true; # Required for NFS

  # Synology DS218+ NFS exports. These are automounts, not boot-critical
  # mounts: reef/k3s should boot cleanly even when the NAS is unavailable.
  fileSystems."/mnt/synology/backups" = {
    device = "192.168.1.83:/volume1/reef-host-backups";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
      "nofail"
      "noatime"
      "nfsvers=3"
      "proto=tcp"
      "hard"
      "timeo=600"
      "retrans=2"
    ];
  };

  fileSystems."/mnt/synology/media" = {
    device = "192.168.1.83:/volume1/media-archive";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
      "nofail"
      "noatime"
      "nfsvers=3"
      "proto=tcp"
      "hard"
      "timeo=600"
      "retrans=2"
    ];
  };

  fileSystems."/mnt/synology/exports" = {
    device = "192.168.1.83:/volume1/app-exports";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
      "nofail"
      "noatime"
      "nfsvers=3"
      "proto=tcp"
      "hard"
      "timeo=600"
      "retrans=2"
    ];
  };

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
