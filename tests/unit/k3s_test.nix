# ABOUTME: Unit tests for k3s service configuration in base VM module
# ABOUTME: Validates k3s service setup, configuration, and dependencies

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/base-k3s-vm/configuration.nix;
in
[
  {
    name = "K3s service is configurable";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      builtins.hasAttr "k3s" eval.config.services;
    expected = true;
  }
  
  {
    name = "K3s service is disabled by default";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.enable;
    expected = false;
  }
  
  {
    name = "K3s role is set to server";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.role;
    expected = "server";
  }
  
  {
    name = "K3s data directory is configured via extraFlags";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        extraFlags = eval.config.services.k3s.extraFlags;
      in
      builtins.elem "--data-dir=/var/lib/k3s" extraFlags;
    expected = true;
  }
  
  {
    name = "K3s cluster init is disabled by default";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.clusterInit;
    expected = false;
  }
  
  {
    name = "K3s has traefik disabled in extraFlags";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        extraFlags = eval.config.services.k3s.extraFlags;
      in
      builtins.elem "--disable=traefik" extraFlags;
    expected = true;
  }
  
  {
    name = "K3s has servicelb disabled in extraFlags";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        extraFlags = eval.config.services.k3s.extraFlags;
      in
      builtins.elem "--disable=servicelb" extraFlags;
    expected = true;
  }
  
  {
    name = "K3s cluster CIDR is configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        extraFlags = eval.config.services.k3s.extraFlags;
      in
      builtins.elem "--cluster-cidr=10.42.0.0/16" extraFlags;
    expected = true;
  }
  
  {
    name = "K3s service CIDR is configured";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        extraFlags = eval.config.services.k3s.extraFlags;
      in
      builtins.elem "--service-cidr=10.43.0.0/16" extraFlags;
    expected = true;
  }
  
  {
    name = "Kubectl package is included";
    actual = builtins.elem "kubectl" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "Kubernetes Helm package is included";
    actual = builtins.elem "kubernetes-helm" (nixtest.getSystemPackages modulePath);
    expected = true;
  }
  
  {
    name = "K3s data directory tmpfile rule exists";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        tmpfilesRules = eval.config.systemd.tmpfiles.rules;
      in
      builtins.elem "d /var/lib/k3s 0755 root root -" tmpfilesRules;
    expected = true;
  }
  
  {
    name = "K3s server directory tmpfile rule exists";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
        tmpfilesRules = eval.config.systemd.tmpfiles.rules;
      in
      builtins.elem "d /var/lib/k3s/server 0755 root root -" tmpfilesRules;
    expected = true;
  }
  
  {
    name = "Token file is configured to use agenix secret";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.tokenFile;
    expected = "/run/secrets/k3s_secret";
  }
  
  {
    name = "Token file is not null";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      eval.config.services.k3s.tokenFile != null;
    expected = true;
  }
  
  {
    name = "Server address configuration is available";
    actual = 
      let
        eval = nixtest.evalTestConfig modulePath [];
      in
      builtins.hasAttr "serverAddr" eval.config.services.k3s;
    expected = true;
  }
]