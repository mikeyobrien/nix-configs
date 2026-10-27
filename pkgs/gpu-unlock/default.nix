{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  kernel,
  kernelModuleMakeFlags,
  python3,
  zstd,
}:
# Zagitta/gpu-unlock: a pre-driver kernel module that raises the FP16/BF16/TF32
# tensor issue rate of GA102 cards to the professional rate. The firmware it
# loads is generated at build time from the pinned NVIDIA 610.43.03 driver; the
# running driver version does not matter. One output carries both the module
# (lib/modules, for boot.extraModulePackages) and the firmware (lib/firmware,
# for hardware.firmware), so the initrd closure finds it through MODULE_FIRMWARE.
let
  nv = "610.43.03";
  nvSource = fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
    hash = "sha256-fhGJI8eiPtw2EU1jJzpG4+BOmvmGlaQiA+esLf6fwdw=";
  };
  nvInstaller = fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/${nv}/NVIDIA-Linux-x86_64-${nv}-no-compat32.run";
    hash = "sha256-4IRFHbcwpt8p09dPZVdJxNI248lF99lLUgXoQxj+L5A=";
  };
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "gpu-unlock";
    version = "1.1.0-unstable-2026-10-26";
    name = "${finalAttrs.pname}-${finalAttrs.version}-${kernel.version}";

    src = fetchFromGitHub {
      owner = "Zagitta";
      repo = "gpu-unlock";
      rev = "6081407b312aa3139a2bed62bdda354f4ffddc1d";
      hash = "sha256-6FbsBw20/+MRP676qur+C4glwrKmqlNi3xwAzB82zoA=";
    };

    nativeBuildInputs = kernel.moduleBuildDependencies ++ [python3 zstd];
    hardeningDisable = ["pic"];

    buildPhase = ''
      runHook preBuild
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M="$PWD/kernel/gpu_unlock" -j"$NIX_BUILD_CORES" \
        ${lib.escapeShellArgs kernelModuleMakeFlags} modules
      mkdir nv
      tar -xf ${nvSource} -C nv
      python3 firmware/extract_gsp.py ${nvInstaller} assets
      python3 firmware/extract_boot_assets.py nv/NVIDIA-kernel-module-source-${nv} assets
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 -t "$out/lib/modules/${kernel.modDirVersion}/extra" kernel/gpu_unlock/gpu_unlock.ko
      make ASSETS="$PWD/assets" DESTDIR="$out" FWDIR=/lib/firmware/gpu-unlock/${nv} \
        LICENSEDIR=/share/licenses install-firmware
      runHook postInstall
    '';

    meta = {
      description = "Unlock the professional FP16/BF16 tensor issue rate on consumer Ampere cards";
      homepage = "https://github.com/Zagitta/gpu-unlock";
      license = with lib.licenses; [gpl2Only unfree];
      platforms = ["x86_64-linux"];
    };
  })
