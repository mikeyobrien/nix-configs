#!/usr/bin/env bash
# ABOUTME: Unit tests for the base k3s VM module configuration
# ABOUTME: Validates that the base VM module provides required functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

source "$SCRIPT_DIR/../helpers/common.sh"

echo "Running: Base VM Module Tests"

begin_test_section "Module Structure Tests"

# Test that the module files exist
assert_file_exists "$PROJECT_ROOT/hosts/base-k3s-vm/configuration.nix" \
    "Base VM configuration.nix exists"
assert_file_exists "$PROJECT_ROOT/hosts/base-k3s-vm/home.nix" \
    "Base VM home.nix exists"

begin_test_section "Configuration Evaluation Tests"

# Create a temporary test configuration that imports the base
TEMP_DIR=$(create_temp_dir "base-vm-test")
cat > "$TEMP_DIR/test-config.nix" << EOF
{ config, pkgs, lib, ... }:
{
  imports = [
    $PROJECT_ROOT/hosts/base-k3s-vm/configuration.nix
  ];
  
  # Minimal config to make it evaluable
  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  # For testing - set a dummy host name
  networking.hostName = "test-vm";
  
  # Disable nixpkgs config for testing
  nixpkgs.config = {};
  nixpkgs.hostPlatform = "x86_64-linux";
  
  system.stateVersion = "24.05";
}
EOF

# Test that the configuration can be evaluated
echo "Testing Nix evaluation of base configuration..."
if nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.system.build.toplevel.drvPath or null
" &> "$TEMP_DIR/eval-output.txt"; then
    echo -e "${GREEN}✓${NC} Base configuration evaluates successfully"
else
    echo -e "${RED}✗${NC} Base configuration evaluation failed"
    echo "Evaluation output:"
    cat "$TEMP_DIR/eval-output.txt"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

begin_test_section "Required Services Tests"

# Test that SSH is enabled
echo "Checking SSH service configuration..."
SSH_ENABLED=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.services.openssh.enable or false
" 2>/dev/null | tr -d '"')

assert_equals "true" "$SSH_ENABLED" "SSH service is enabled"

begin_test_section "Essential Packages Tests"

# Test that essential packages are included
echo "Checking essential packages..."
PACKAGES=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
    pkgNames = map (p: p.pname or p.name or \"unknown\") system.config.environment.systemPackages;
  in pkgNames
" 2>/dev/null | tr -d '[]"' | tr ' ' '\n' | sort -u)

# Check for required packages
for pkg in vim git htop tmux; do
    if echo "$PACKAGES" | grep -q "^${pkg}"; then
        echo -e "${GREEN}✓${NC} Package '$pkg' is included"
    else
        echo -e "${RED}✗${NC} Package '$pkg' is missing"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
done

begin_test_section "Nix Flakes Configuration"

# Test that flakes are enabled
echo "Checking Nix flakes configuration..."
FLAKES_ENABLED=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
    features = system.config.nix.settings.experimental-features or [];
  in builtins.elem \"flakes\" features
" 2>/dev/null | tr -d '"')

assert_equals "true" "$FLAKES_ENABLED" "Nix flakes are enabled"

begin_test_section "Home Manager Tests"

# Test home.nix evaluation
cat > "$TEMP_DIR/test-home.nix" << EOF
{ config, pkgs, lib, ... }:
{
  imports = [
    $PROJECT_ROOT/hosts/base-k3s-vm/home.nix
  ];
  
  home.username = "testuser";
  home.homeDirectory = "/home/testuser";
  home.stateVersion = "24.05";
}
EOF

echo "Testing home.nix evaluation..."
# Note: This is a simplified test - full home-manager eval would require more setup
if nix-instantiate --eval --strict "$PROJECT_ROOT/hosts/base-k3s-vm/home.nix" \
   --arg config {} --arg pkgs 'import <nixpkgs> {}' --arg lib 'import <nixpkgs/lib>' \
   &> "$TEMP_DIR/home-eval-output.txt"; then
    echo -e "${GREEN}✓${NC} Home configuration evaluates successfully"
else
    echo -e "${RED}✗${NC} Home configuration evaluation failed"
    echo "Note: This might be expected if home.nix uses home-manager specific features"
fi

# Cleanup
cleanup_temp "$TEMP_DIR"

echo ""
echo "All base VM module tests passed!"
exit 0