{ config, pkgs, ... }:

{
  # Enable Glances service
  services.glances = {
    enable = true;
    # Set web interface to true if you want to access Glances via web browser
    webInterface = true;
    # Default port is 61208
    port = 61208;
  };

  # Create a custom Glances configuration file
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
