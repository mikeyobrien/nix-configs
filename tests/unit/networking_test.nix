# ABOUTME: Unit tests for networking configuration in base VM module using NixTest
# ABOUTME: Validates firewall rules, network settings, and port configurations

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/base-k3s-vm/configuration.nix;
in
[
  {
    name = "Firewall is enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.firewall.enable;
    expected = true;
  }
  
  {
    name = "SSH service is enabled (implies port 22 open)";
    actual = nixtest.checkServiceEnabled "sshd" modulePath;
    expected = true;
  }
  
  {
    name = "SSH port 22 is configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        ports = eval.config.services.openssh.ports;
      in
      builtins.elem 22 ports;
    expected = true;
  }
  
  {
    name = "systemd-resolved is enabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.resolved.enable;
    expected = true;
  }
  
  {
    name = "IPv4 forwarding is enabled for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv4.ip_forward" or 0;
    expected = 1;
  }
  
  {
    name = "IPv6 forwarding is enabled for k3s";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv6.conf.all.forwarding" or 0;
    expected = 1;
  }
  
  {
    name = "Network receive buffer size is adequate";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        rmemMax = eval.config.boot.kernel.sysctl."net.core.rmem_max" or 212992;
      in
      rmemMax >= 134217728;
    expected = true;
  }
  
  {
    name = "Network send buffer size is adequate";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        wmemMax = eval.config.boot.kernel.sysctl."net.core.wmem_max" or 212992;
      in
      wmemMax >= 134217728;
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
  
  {
    name = "Network namespace sharing is enabled for containers";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.boot.kernel.sysctl."net.ipv4.conf.all.route_localnet" or 0;
    expected = 1;
  }
]