# ABOUTME: Unit tests for k3s networking configuration in base VM module
# ABOUTME: Validates firewall rules, k3s ports, and network kernel parameters

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/base-k3s-vm/configuration.nix;
in
[
  {
    name = "Kubernetes API server port 6443 is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 6443 allowedPorts;
    expected = true;
  }
  
  {
    name = "Kubelet API port 10250 is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 10250 allowedPorts;
    expected = true;
  }
  
  {
    name = "etcd client port 2379 is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 2379 allowedPorts;
    expected = true;
  }
  
  {
    name = "etcd peer port 2380 is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedPorts = eval.config.networking.firewall.allowedTCPPorts;
      in
      builtins.elem 2380 allowedPorts;
    expected = true;
  }
  
  {
    name = "NodePort range 30000-32767 is allowed";
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
    name = "Flannel VXLAN UDP port 8472 is allowed";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        allowedUDPPorts = eval.config.networking.firewall.allowedUDPPorts;
      in
      builtins.elem 8472 allowedUDPPorts;
    expected = true;
  }
  
  {
    name = "IPv4 forwarding is enabled for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv4.ip_forward";
    expected = 1;
  }
  
  {
    name = "IPv6 forwarding is enabled for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv6.conf.all.forwarding";
    expected = 1;
  }
  
  {
    name = "Route localnet is enabled for container networking";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv4.conf.all.route_localnet";
    expected = 1;
  }
  
  {
    name = "Network socket backlog is increased";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.core.somaxconn";
    expected = 32768;
  }
  
  {
    name = "Network receive buffer is sized for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.core.rmem_max";
    expected = 134217728;
  }
  
  {
    name = "Network send buffer is sized for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.core.wmem_max";
    expected = 134217728;
  }
  
  {
    name = "Swap is disabled (swappiness = 0)";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."vm.swappiness";
    expected = 0;
  }
  
  {
    name = "Firewall is enabled with k3s ports";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.firewall.enable;
    expected = true;
  }
  
  {
    name = "DHCP is enabled by default";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.useDHCP;
    expected = true;
  }
]