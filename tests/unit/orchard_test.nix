# ABOUTME: Unit tests for orchard host configuration - Mac Studio k3s control plane node
# ABOUTME: Validates orchard-specific settings, network config, and k3s cluster join configuration

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/orchard/configuration.nix;
in
[
  {
    name = "Orchard configuration evaluates successfully";
    actual = nixtest.checkModuleEvaluates modulePath;
    expected = true;
  }
  
  {
    name = "Hostname is set to orchard";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.hostName;
    expected = "orchard";
  }
  
  {
    name = "K3s service is enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.enable;
    expected = true;
  }
  
  {
    name = "K3s is configured to join reef cluster";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.serverAddr;
    expected = "https://10.10.11.39:6443";
  }
  
  {
    name = "K3s cluster init is disabled (joining node)";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.clusterInit;
    expected = false;
  }
  
  {
    name = "Static IP is configured for orchard";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        interfaces = eval.config.networking.interfaces;
      in
      builtins.hasAttr "eth0" interfaces;
    expected = true;
  }
  
  {
    name = "Orchard IP address is 10.10.11.100";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        eth0Config = eval.config.networking.interfaces.eth0;
      in
      if builtins.length eth0Config.ipv4.addresses > 0
      then (builtins.head eth0Config.ipv4.addresses).address
      else "";
    expected = "10.10.11.100";
  }
  
  {
    name = "Network prefix length is /23";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        eth0Config = eval.config.networking.interfaces.eth0;
      in
      if builtins.length eth0Config.ipv4.addresses > 0
      then (builtins.head eth0Config.ipv4.addresses).prefixLength
      else 0;
    expected = 23;
  }
  
  {
    name = "DHCP is disabled for static IP";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.useDHCP;
    expected = false;
  }
  
  {
    name = "Default gateway is configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.defaultGateway.address;
    expected = "10.10.10.1";
  }
  
  {
    name = "DNS nameservers are configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      builtins.length eval.config.networking.nameservers > 0;
    expected = true;
  }
  
  {
    name = "Firewall allows k3s API port 6443";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 6443 allowedPorts;
    expected = true;
  }
  
  {
    name = "Firewall allows SSH port 22";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 22 allowedPorts;
    expected = true;
  }
  
  {
    name = "NodePort range is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        portRanges = eval.config.networking.firewall.allowedTCPPortRanges;
        nodePortRange = { from = 30000; to = 32767; };
      in
      builtins.elem nodePortRange portRanges;
    expected = true;
  }
  
  {
    name = "QEMU guest services are enabled for VM";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.qemuGuest.enable;
    expected = true;
  }
  
  {
    name = "Timezone is set to America/Los_Angeles";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.time.timeZone;
    expected = "America/Los_Angeles";
  }
  
  {
    name = "System state version is set";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.system.stateVersion;
    expected = "24.05";
  }
  
  {
    name = "Development documentation is enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.documentation.dev.enable;
    expected = true;
  }
  
  {
    name = "X11 forwarding is enabled for development";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.openssh.settings.X11Forwarding;
    expected = true;
  }
  
  {
    name = "VM-specific kernel parameter is set";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."vm.max_map_count";
    expected = 262144;
  }
  
  {
    name = "qemu-utils package is included";
    actual = builtins.elem "qemu-utils" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
]