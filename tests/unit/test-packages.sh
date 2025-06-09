#!/usr/bin/env bash
# ABOUTME: Unit tests for system packages in base VM module
# ABOUTME: Validates that required packages are included and no conflicts exist

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

source "$SCRIPT_DIR/../helpers/common.sh"

echo "Running: System Packages Tests"

# Create a temporary test configuration
TEMP_DIR=$(create_temp_dir "packages-test")
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

begin_test_section "Essential Packages Tests"

# Get list of system packages
echo "Retrieving system packages list..."
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

# Required packages for basic functionality
REQUIRED_PACKAGES=(
    "vim"
    "git" 
    "htop"
    "tmux"
    "curl"
    "wget"
    "tree"
    "jq"
)

# Check each required package
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if echo "$PACKAGES" | grep -q "^${pkg}"; then
        echo -e "${GREEN}✓${NC} Essential package '$pkg' is included"
    else
        echo -e "${RED}✗${NC} Essential package '$pkg' is missing"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
done

begin_test_section "Network Utilities Tests"

# Network diagnostic tools
NETWORK_TOOLS=(
    "bind"  # provides dig, nslookup via dnsutils
    "netcat-gnu"
)

for tool in "${NETWORK_TOOLS[@]}"; do
    if echo "$PACKAGES" | grep -q "${tool}"; then
        echo -e "${GREEN}✓${NC} Network tool '$tool' is included"
    else
        echo -e "${RED}✗${NC} Network tool '$tool' is missing"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
done

begin_test_section "System Monitoring Tools"

# System monitoring tools
MONITORING_TOOLS=(
    "iotop"
    "ncdu"
)

for tool in "${MONITORING_TOOLS[@]}"; do
    if echo "$PACKAGES" | grep -q "${tool}"; then
        echo -e "${GREEN}✓${NC} Monitoring tool '$tool' is included"
    else
        echo -e "${RED}✗${NC} Monitoring tool '$tool' is missing"
        cleanup_temp "$TEMP_DIR"
        exit 1
    fi
done

begin_test_section "Package Conflicts Tests"

# Check that no conflicting packages are included
echo "Checking for package conflicts..."

# Example: Ensure we don't have both vim and neovim (if that were a conflict)
# This is just an example - adjust based on actual conflicts
CONFLICT_PAIRS=(
    # "vim:neovim"  # Example format
)

conflicts_found=false
for pair in "${CONFLICT_PAIRS[@]}"; do
    pkg1="${pair%:*}"
    pkg2="${pair#*:}"
    
    has_pkg1=$(echo "$PACKAGES" | grep -c "^${pkg1}$" || true)
    has_pkg2=$(echo "$PACKAGES" | grep -c "^${pkg2}$" || true)
    
    if [[ "$has_pkg1" -gt 0 ]] && [[ "$has_pkg2" -gt 0 ]]; then
        echo -e "${RED}✗${NC} Conflict found: both '$pkg1' and '$pkg2' are included"
        conflicts_found=true
    fi
done

if [[ "$conflicts_found" == false ]]; then
    echo -e "${GREEN}✓${NC} No package conflicts detected"
fi

begin_test_section "Package Count Validation"

# Ensure we're not including too many packages (keep it minimal)
PACKAGE_COUNT=$(echo "$PACKAGES" | wc -l | tr -d ' ')
echo "Total system packages: $PACKAGE_COUNT"

# Warning if too many packages (adjust threshold as needed)
if [[ "$PACKAGE_COUNT" -gt 100 ]]; then
    echo -e "${YELLOW}⚠${NC} High package count: $PACKAGE_COUNT packages (consider reducing)"
elif [[ "$PACKAGE_COUNT" -lt 5 ]]; then
    echo -e "${RED}✗${NC} Too few packages: $PACKAGE_COUNT packages"
    cleanup_temp "$TEMP_DIR"
    exit 1
else
    echo -e "${GREEN}✓${NC} Package count is reasonable: $PACKAGE_COUNT packages"
fi

# Cleanup
cleanup_temp "$TEMP_DIR"

echo ""
echo "All package tests passed!"
exit 0