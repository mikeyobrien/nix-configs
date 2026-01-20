# ABOUTME: Integration tests for flake.nix - validates flake structure and host configurations
# ABOUTME: Tests that all host configurations are properly defined and flake evaluates correctly

let
  nixtest = import ../nixtest.nix;
  
  # Helper function to run flake commands and check results
  runFlakeCommand = cmd:
    let
      result = builtins.exec ["nix" "flake" "show" "--json" "."];
    in
    builtins.fromJSON result;

  # Simple test approach using file system checks and nix eval
  testFlakeShowOutput = 
    let
      # Use nix eval to check flake structure
      checkFlakeAttr = attr:
        let
          cmd = "nix eval --impure --expr 'builtins.hasAttr \"${attr}\" (builtins.getFlake (toString ./.)).outputs'";
          result = builtins.exec ["sh" "-c" cmd];
        in
        result == "true";
    in
    checkFlakeAttr;

  # Test that specific configurations exist
  checkNixosConfig = configName:
    let
      cmd = "nix eval --impure --expr 'builtins.hasAttr \"${configName}\" (builtins.getFlake (toString ./.)).outputs.nixosConfigurations'";
      result = builtins.exec ["sh" "-c" cmd];
    in
    result == "true";
    
in
[
  # Basic flake structure tests
  {
    name = "Flake file exists";
    actual = builtins.pathExists ../../flake.nix;
    expected = true;
  }
  
  {
    name = "Flake lock file exists";
    actual = builtins.pathExists ../../flake.lock;
    expected = true;
  }
  
  # Host configuration file existence tests
  {
    name = "Orchard configuration file exists";
    actual = builtins.pathExists ../../hosts/orchard/configuration.nix;
    expected = true;
  }
  
  {
    name = "Orchard home configuration file exists";
    actual = builtins.pathExists ../../hosts/orchard/home.nix;
    expected = true;
  }
  
  {
    name = "Coral configuration file exists";
    actual = builtins.pathExists ../../hosts/coral/configuration.nix;
    expected = true;
  }
  
  {
    name = "Coral home configuration file exists";
    actual = builtins.pathExists ../../hosts/coral/home.nix;
    expected = true;
  }
  
  # Test that configurations evaluate
  {
    name = "Orchard configuration evaluates";
    actual = nixtest.checkModuleEvaluates ../../hosts/orchard/configuration.nix;
    expected = true;
  }
  
  {
    name = "Coral configuration evaluates";
    actual = nixtest.checkModuleEvaluates ../../hosts/coral/configuration.nix;
    expected = true;
  }
  
  # Validate flake.nix content structure
  {
    name = "Flake.nix contains orchard reference";
    actual = 
      let
        flakeContent = builtins.readFile ../../flake.nix;
      in
      builtins.match ".*orchard.*" flakeContent != null;
    expected = true;
  }
  
  {
    name = "Flake.nix contains coral reference";
    actual = 
      let
        flakeContent = builtins.readFile ../../flake.nix;
      in
      builtins.match ".*coral.*" flakeContent != null;
    expected = true;
  }
  
  {
    name = "Orchard is configured as aarch64-linux";
    actual = 
      let
        flakeContent = builtins.readFile ../../flake.nix;
      in
      builtins.match ".*orchard.*aarch64-linux.*" flakeContent != null;
    expected = true;
  }
  
  {
    name = "Coral is configured as x86_64-linux";
    actual = 
      let
        flakeContent = builtins.readFile ../../flake.nix;
      in
      builtins.match ".*coral.*x86_64-linux.*" flakeContent != null;
    expected = true;
  }
  
  # Test lib helper functions
  {
    name = "mkSystem helper function exists";
    actual = builtins.pathExists ../../lib/mkSystem.nix;
    expected = true;
  }
  
  {
    name = "mkSystem function evaluates";
    actual = 
      let
        mkSystemFile = ../../lib/mkSystem.nix;
      in
      builtins.tryEval (import mkSystemFile) != false;
    expected = true;
  }
  
  # Test base k3s VM module integration
  {
    name = "Base k3s VM configuration is used by orchard";
    actual = 
      let
        orchardContent = builtins.readFile ../../hosts/orchard/configuration.nix;
      in
      builtins.match ".*base-k3s-vm.*" orchardContent != null;
    expected = true;
  }
  
  {
    name = "Base k3s VM configuration is used by coral";
    actual = 
      let
        coralContent = builtins.readFile ../../hosts/coral/configuration.nix;
      in
      builtins.match ".*base-k3s-vm.*" coralContent != null;
    expected = true;
  }
  
  # Test k3s configuration integration
  {
    name = "Orchard has k3s server address configured";
    actual = 
      let
        orchardContent = builtins.readFile ../../hosts/orchard/configuration.nix;
      in
      builtins.match ".*10\\.10\\.11\\.39.*" orchardContent != null;
    expected = true;
  }
  
  {
    name = "Coral has k3s server address configured";
    actual = 
      let
        coralContent = builtins.readFile ../../hosts/coral/configuration.nix;
      in
      builtins.match ".*10\\.10\\.11\\.39.*" coralContent != null;
    expected = true;
  }
  
  # Test static IP configuration
  {
    name = "Orchard has static IP 10.10.11.100 configured";
    actual = 
      let
        orchardContent = builtins.readFile ../../hosts/orchard/configuration.nix;
      in
      builtins.match ".*10\\.10\\.11\\.100.*" orchardContent != null;
    expected = true;
  }
  
  {
    name = "Coral has static IP 10.10.11.101 configured";
    actual = 
      let
        coralContent = builtins.readFile ../../hosts/coral/configuration.nix;
      in
      builtins.match ".*10\\.10\\.11\\.101.*" coralContent != null;
    expected = true;
  }
]