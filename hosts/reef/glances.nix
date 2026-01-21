{ config, pkgs, ... }:

{
  # Glances is enabled in configuration.nix
  # Custom Glances configuration file
  environment.etc."glances/glances.conf" = {
    text = ''
      [network]
      # Hide the loopback interface
      hide=lo
      # Hide docker and virtual interfaces (using regex)
      hide=docker.*,veth.*,br-.*,vm-.*
    '';
    mode = "0644";
  };
}
