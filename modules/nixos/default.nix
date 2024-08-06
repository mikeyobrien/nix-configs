{inputs, ...}: {
  # List your module files here
  virtualisation = import ./virtualisation.nix;

  proxmox = {config, ...}: {
    imports = [
      inputs.nixos-generators.nixosModules.all-formats
    ];
    nixpkgs.hostPlatform = "x86_64-linux";
    formatConfigs.proxmox = {config, ...}: {
      proxmox.qemuConf.name = "${config.networking.hostName}-nixos-${config.system.nixos.label}";
    };
  };
}
