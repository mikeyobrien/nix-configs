# ABOUTME: Unit tests for coral host configuration - Proxmox k3s control plane node
# ABOUTME: Validates coral-specific settings, network config, and k3s cluster join configuration

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/coral/configuration.nix;
in
[
  {
    name = "Coral configuration evaluates successfully";
    actual = nixtest.checkModuleEvaluates modulePath;
    expected = true;
  }
  
  {
    name = "Hostname is set to coral";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.hostName;
    expected = "coral";
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
    name = "Static IP is configured for coral";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        interfaces = eval.config.networking.interfaces;
      in
      builtins.hasAttr "eth0" interfaces;
    expected = true;
  }
  
  {
    name = "Coral IP address is 10.10.11.101";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        eth0Config = eval.config.networking.interfaces.eth0;
      in
      if builtins.length eth0Config.ipv4.addresses > 0
      then (builtins.head eth0Config.ipv4.addresses).address
      else "";
    expected = "10.10.11.101";
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
    name = "QEMU guest services are enabled for Proxmox VM";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.qemuGuest.enable;
    expected = true;
  }
  
  {
    name = "SPICE agent is enabled for Proxmox";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.spice-vdagentd.enable;
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
    name = "Documentation is disabled for server efficiency";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.documentation.enable;
    expected = false;
  }
  
  {
    name = "Man pages are enabled for troubleshooting";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.documentation.man.enable;
    expected = true;
  }
  
  {
    name = "X11 forwarding is disabled for security";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.openssh.settings.X11Forwarding;
    expected = false;
  }
  
  {
    name = "Connection tracking is optimized for k8s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.netfilter.nf_conntrack_max";
    expected = 131072;
  }
  
  {
    name = "KVM Intel module is loaded";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      builtins.elem "kvm-intel" eval.config.boot.kernelModules;
    expected = true;
  }
  
  {
    name = "Virtio modules are loaded for Proxmox";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        modules = eval.config.boot.kernelModules;
      in
      builtins.elem "virtio_net" modules && builtins.elem "virtio_blk" modules;
    expected = true;
  }
  
  {
    name = "Intel microcode updates are enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.hardware.cpu.intel.updateMicrocode;
    expected = true;
  }
  
  {
    name = "Power management is configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.powerManagement.enable;
    expected = true;
  }
  
  {
    name = "CPU frequency governor is set to ondemand";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.powerManagement.cpuFreqGovernor;
    expected = "ondemand";
  }
  
  {
    name = "Aggressive garbage collection is enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.nix.gc.dates;
    expected = "daily";
  }
]