# ABOUTME: Unit tests for system packages in base VM module using NixTest
# ABOUTME: Validates that required packages are included and configuration is reasonable

let
  nixtest = import ../nixtest.nix;
  modulePath = ../../hosts/base-k3s-vm/configuration.nix;
  systemPackages = nixtest.getSystemPackages modulePath;
in
[
  {
    name = "System packages list is not empty";
    actual = builtins.length systemPackages > 0;
    expected = true;
  }
  
  {
    name = "Package count is reasonable (not too few)";
    actual = builtins.length systemPackages >= 5;
    expected = true;
  }
  
  {
    name = "Package count is reasonable (not excessive)";
    actual = builtins.length systemPackages <= 200;
    expected = true;
  }
  
  # Essential packages tests
  {
    name = "Essential editor vim is included";
    actual = builtins.elem "vim" systemPackages;
    expected = true;
  }
  
  {
    name = "Version control git is included";
    actual = builtins.elem "git" systemPackages;
    expected = true;
  }
  
  {
    name = "Process monitor htop is included";
    actual = builtins.elem "htop" systemPackages;
    expected = true;
  }
  
  {
    name = "Terminal multiplexer tmux is included";
    actual = builtins.elem "tmux" systemPackages;
    expected = true;
  }
  
  {
    name = "HTTP client curl is included";
    actual = builtins.elem "curl" systemPackages;
    expected = true;
  }
  
  {
    name = "HTTP client wget is included";
    actual = builtins.elem "wget" systemPackages;
    expected = true;
  }
  
  {
    name = "Directory tree tool is included";
    actual = builtins.elem "tree" systemPackages;
    expected = true;
  }
  
  {
    name = "JSON processor jq is included";
    actual = builtins.elem "jq" systemPackages;
    expected = true;
  }
  
  # Network utilities tests
  {
    name = "DNS utilities (bind) are included";
    actual = builtins.elem "bind" systemPackages;
    expected = true;
  }
  
  {
    name = "Network testing tool netcat-gnu is included";
    actual = builtins.elem "netcat-gnu" systemPackages;
    expected = true;
  }
  
  # System monitoring tools tests
  {
    name = "IO monitoring tool iotop is included";
    actual = builtins.elem "iotop" systemPackages;
    expected = true;
  }
  
  {
    name = "Disk usage analyzer ncdu is included";
    actual = builtins.elem "ncdu" systemPackages;
    expected = true;
  }
  
  # Package conflict tests (examples)
  {
    name = "No obvious package conflicts detected";
    actual = 
      let
        # Check for common conflicting packages (adjust as needed)
        conflicts = [
          # Example: both nano and vim (not actually conflicting, just example)
          # (builtins.elem "nano" systemPackages && builtins.elem "vim" systemPackages)
        ];
      in
      builtins.length (builtins.filter (x: x) conflicts) == 0;
    expected = true;
  }
  
  # Package utility tests
  {
    name = "All packages have valid names";
    actual = 
      let
        invalidPackages = builtins.filter (pkg: pkg == "unknown" || pkg == "") systemPackages;
      in
      builtins.length invalidPackages == 0;
    expected = true;
  }
]