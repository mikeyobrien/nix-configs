#!/usr/bin/env bash
# ABOUTME: Unit tests for networking configuration in base VM module
# ABOUTME: Validates firewall rules, network settings, and port configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

source "$SCRIPT_DIR/../helpers/common.sh"

echo "Running: Networking Configuration Tests"

# Create a temporary test configuration
TEMP_DIR=$(create_temp_dir "networking-test")
cat > "$TEMP_DIR/test-config.nix" << EOF
{ config, pkgs, lib, ... }:
{
  imports = [
    $PROJECT_ROOT/hosts/base-k3s-vm/configuration.nix
  ];
  
  # Required for evaluation
  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  networking.hostName = "test-vm";
  nixpkgs.config = {};
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "24.05";
}
EOF

begin_test_section "Firewall Configuration Tests"

# Test that firewall is enabled
echo "Checking firewall status..."
FIREWALL_ENABLED=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.networking.firewall.enable or false
" 2>/dev/null | tr -d '"')

assert_equals "true" "$FIREWALL_ENABLED" "Firewall is enabled"

# Test SSH port is open (automatically opened when SSH is enabled)
echo "Checking SSH port configuration..."
SSH_PORT=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.services.openssh.ports or [22]
" 2>/dev/null | tr -d '[]')

if [[ "$SSH_PORT" =~ "22" ]]; then
    echo -e "${GREEN}✓${NC} SSH port 22 is configured"
else
    echo -e "${RED}✗${NC} SSH port configuration incorrect: $SSH_PORT"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

begin_test_section "DNS Configuration Tests"

# Test systemd-resolved is enabled
echo "Checking DNS resolver configuration..."
RESOLVED_ENABLED=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.services.resolved.enable or false
" 2>/dev/null | tr -d '"')

assert_equals "true" "$RESOLVED_ENABLED" "systemd-resolved is enabled"

begin_test_section "Network Kernel Parameters"

# Test IP forwarding is enabled (required for k3s)
echo "Checking IP forwarding settings..."
IPV4_FORWARD=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.boot.kernel.sysctl.\"net.ipv4.ip_forward\" or 0
" 2>/dev/null | tr -d '"')

assert_equals "1" "$IPV4_FORWARD" "IPv4 forwarding is enabled"

IPV6_FORWARD=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.boot.kernel.sysctl.\"net.ipv6.conf.all.forwarding\" or 0
" 2>/dev/null | tr -d '"')

assert_equals "1" "$IPV6_FORWARD" "IPv6 forwarding is enabled"

# Test network buffer sizes
echo "Checking network buffer sizes..."
RMEM_MAX=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.boot.kernel.sysctl.\"net.core.rmem_max\" or 0
" 2>/dev/null | tr -d '"')

if [[ "$RMEM_MAX" -ge 134217728 ]]; then
    echo -e "${GREEN}✓${NC} Network receive buffer size is adequate: $RMEM_MAX"
else
    echo -e "${RED}✗${NC} Network receive buffer too small: $RMEM_MAX"
    cleanup_temp "$TEMP_DIR"
    exit 1
fi

begin_test_section "Default Network Settings"

# Test that DHCP is default (can be overridden)
echo "Checking default network configuration..."
DHCP_DEFAULT=$(nix-instantiate --eval --strict -E "
  let
    nixpkgs = (builtins.getFlake \"$PROJECT_ROOT\").inputs.nixpkgs;
    system = nixpkgs.lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [ $TEMP_DIR/test-config.nix ];
    };
  in system.config.networking.useDHCP or false
" 2>/dev/null | tr -d '"')

assert_equals "true" "$DHCP_DEFAULT" "DHCP is enabled by default"

# Cleanup
cleanup_temp "$TEMP_DIR"

echo ""
echo "All networking configuration tests passed!"
exit 0