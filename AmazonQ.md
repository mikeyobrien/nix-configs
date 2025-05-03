# UVX on NixOS with FHS Environment

## Problem
UVX cannot run directly on NixOS because it's a dynamically linked executable intended for generic Linux environments. NixOS has a different approach to library management and doesn't have the standard `/lib` directory structure that dynamically linked executables expect.

## Solution
We've implemented an FHS (Filesystem Hierarchy Standard) environment for UVX that creates a mini-environment mimicking a traditional Linux filesystem structure.

## Implementation Details

1. Created a new module at `/home/mobrienv/code/nix-configs/modules/home-manager/uvx.nix` that:
   - Sets up an FHS environment with necessary dependencies
   - Creates a wrapper script for easy access to UVX

2. Added the module to the WSL home configuration at `/home/mobrienv/code/nix-configs/hosts/wsl/home.nix`

## Usage

After rebuilding your home configuration, you can use UVX in two ways:

1. Direct FHS environment:
   ```bash
   uvx-env
   # Now you're in the FHS environment
   uvx mcpo --port 8000 -- uvx mcp-server-time --local-timezone=America/New_York
   ```

2. Using the wrapper script (recommended):
   ```bash
   uvx mcpo --port 8000 -- uvx mcp-server-time --local-timezone=America/New_York
   ```

The wrapper script automatically runs UVX commands within the FHS environment.

## Rebuilding

To apply these changes, run:
```bash
nix build homeConfigurations.wsl.activationPackage
./result/activate
```
