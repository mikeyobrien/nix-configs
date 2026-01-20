# ABOUTME: Unit tests for the base k3s VM module configuration using NixTest
# ABOUTME: Validates that the base VM module provides required functionality

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/base-k3s-vm/configuration.nix;
in
[
  {
    name = "Base VM configuration evaluates successfully";
    actual = nixtest.checkModuleEvaluates modulePath;
    expected = true;
  }
  
  {
    name = "SSH service is enabled";
    actual = nixtest.checkServiceEnabled "sshd" modulePath;
    expected = true;
  }
  
  {
    name = "Essential package vim is included";
    actual = builtins.elem "vim" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package git is included";
    actual = builtins.elem "git" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package htop is included";
    actual = builtins.elem "htop" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package tmux is included";
    actual = builtins.elem "tmux" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package curl is included";
    actual = builtins.elem "curl" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package wget is included";
    actual = builtins.elem "wget" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package tree is included";
    actual = builtins.elem "tree" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Essential package jq is included";
    actual = builtins.elem "jq" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Network diagnostic tool bind (dnsutils) is included";
    actual = builtins.elem "bind" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Network tool netcat-gnu is included";
    actual = builtins.elem "netcat-gnu" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Monitoring tool iotop is included";
    actual = builtins.elem "iotop" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Monitoring tool ncdu is included";
    actual = builtins.elem "ncdu" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Firewall is enabled by default";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.networking.firewall.enable;
    expected = true;
  }
  
  {
    name = "SSH root login is disabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.openssh.settings.PermitRootLogin;
    expected = "no";
  }
  
  {
    name = "SSH password authentication is disabled";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.openssh.settings.PasswordAuthentication;
    expected = false;
  }
]