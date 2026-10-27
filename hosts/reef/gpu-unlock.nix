{
  config,
  ...
}: let
  gpuUnlock = config.boot.kernelPackages.callPackage ../../pkgs/gpu-unlock {};
in {
  # gpu-unlock (2026-10-27): both RTX 3090s get the professional FP16/BF16/TF32
  # tensor issue rate. The module must run in the initrd before nvidia binds a
  # card: it unlocks, resets the card (FLR) and exits, then the stock nvidia
  # driver binds as usual. The systemd initrd writes boot.initrd.kernelModules
  # to modules-load.d sorted by name, so gpu_unlock loads before nvidia by name,
  # not by list position. No `softdep nvidia pre:` rule: nvidia's own softdep
  # (ecdh_generic,ecdsa_generic) would be replaced, since kmod honours only one.
  # Remove gpu_unlock.targets= (or edit it out in the boot menu) to boot locked.
  # Check: journalctl -k -b | grep gpu_unlock  ("unlocked" per card, before NVRM)
  boot.extraModulePackages = [gpuUnlock];
  hardware.firmware = [gpuUnlock];
  boot.initrd.kernelModules = ["gpu_unlock"];
  boot.kernelParams = ["gpu_unlock.targets=all"];
}
