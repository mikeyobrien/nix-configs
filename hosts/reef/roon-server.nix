{ config, lib, pkgs, ... }:

{
  services.roon-server = {
    enable = true;
    openFirewall = true;
    # Optional: Specify a different data directory if needed
    # dataDir = "/path/to/roon/data";
  };
}
