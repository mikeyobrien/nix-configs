# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular Nix configuration repository supporting NixOS, Darwin (macOS), WSL, and Nix-on-Droid. The architecture emphasizes composability through a minimal base configuration that hosts extend additively.

## Key Commands

### Building and Activating Configurations

```bash
# NixOS systems
sudo nixos-rebuild switch --flake .#<hostname>
sudo nixos-rebuild test --flake .#<hostname>    # Test without switching
sudo nixos-rebuild build --flake .#<hostname>   # Build without activating

# Home Manager (standalone)
nix build .#homeConfigurations.<hostname>.activationPackage
./result/activate
# Or with home-manager installed:
home-manager switch --flake .#<hostname>
home-manager switch --flake .#<hostname> -b backup  # Backup conflicting files

# Darwin (macOS)
darwin-rebuild switch --flake .#rainforest

# Always use experimental features flag if needed:
nix --extra-experimental-features "nix-command flakes" build ...

# Allow unfree packages when needed:
NIXPKGS_ALLOW_UNFREE=1 nix build ... --impure
```

### Development Commands

```bash
# Format all Nix files (uses alejandra)
nix fmt

# Update flake inputs
nix flake update
nix flake lock --update-input <input-name>

# Check flake
nix flake check
nix flake show

# Search packages
nix search nixpkgs <package>

# Test module changes safely
nix build .#homeConfigurations.<host>.activationPackage --dry-run
```

## Architecture Patterns

### Module System

All modules follow this pattern under the `modules.*` namespace:

```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.modules.<category>.<modulename>;
in {
  options.modules.<category>.<modulename> = {
    enable = mkEnableOption "description";
    # Additional options...
  };
  
  config = mkIf cfg.enable {
    # Implementation
  };
}
```

Module categories:
- `modules.core.*` - Essential packages (essential, commonCli, fonts, packages)
- `modules.development.*` - Dev tools (git, direnv, gpg, languages, tools, uvx)
- `modules.editors.*` - Editors (neovim, emacs, nixvim)
- `modules.shells.*` - Shells (bash, fish, prompts)
- `modules.terminal.*` - Terminal tools (alacritty, tmux, zellij)
- `modules.profiles.*` - Pre-configured combinations

### Host Configuration Pattern

```nix
{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix  # Minimal base (essential packages + fish)
    # Optionally add profiles:
    # ../../modules/home-manager/profiles/cli-developer.nix
  ];
  
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  
  # Enable modules additively
  modules.core.commonCli.enable = true;
  modules.development.git.enable = true;
  
  # Override defaults with mkForce
  modules.shells.fish.enable = lib.mkForce false;
}
```

### Adding New Components

**New Host:**
1. Create `hosts/<hostname>/home.nix` following the pattern above
2. Add to `flake.nix`:
   ```nix
   homeConfigurations.<hostname> = home-manager.lib.homeManagerConfiguration {
     pkgs = nixpkgs.legacyPackages.x86_64-linux;
     extraSpecialArgs = { inherit inputs outputs; };
     modules = [(import ./hosts/<hostname>/home.nix { user = "<username>"; lib = nixpkgs.lib; })];
   };
   ```

**New Module:**
1. Create `modules/home-manager/<category>/<modulename>.nix`
2. Import in `modules/home-manager/<category>/default.nix`
3. Ensure category is imported in `modules/home-manager/default.nix`

## Important Conventions

1. **File Headers**: Every Nix file should start with:
   ```nix
   # ABOUTME: Brief description of what this file does
   # ABOUTME: Second line if needed
   ```

2. **Minimal Base**: The base configuration (`home-manager/home.nix`) only includes:
   - Essential packages (`modules.core.essential`)
   - Fish shell with prompts
   - Basic Home Manager setup

3. **Additive Composition**: Hosts build on top of the minimal base by enabling additional modules or importing profiles.

4. **Profile Usage**: Use profiles for common configurations:
   - `cli-developer`: Development tools without GUI
   - `desktop-user`: GUI applications
   - `full-developer`: Complete development environment

5. **Platform Detection**: Use provided flags:
   - `isDarwin` for macOS-specific config
   - `isWsl` for WSL-specific config

## Known Issues and Workarounds

1. **devenv**: Currently disabled in `modules/home-manager/development/tools.nix` and `modules/home-manager/core/packages.nix` due to build issues

2. **WSL**: May require multiple retries during initial setup

3. **File Conflicts**: Use `home-manager switch -b backup` to automatically backup conflicting files

## Testing Workflow

Before pushing changes:
1. Build the configuration: `nix build .#homeConfigurations.<host>.activationPackage`
2. Test on relevant hosts
3. Run formatter: `nix fmt`
4. Verify no module conflicts with dry-run

## Module Interactions

- Base provides minimal environment
- Profiles combine multiple modules
- Hosts can override any default with `lib.mkForce`
- Modules are independent and can be enabled individually
- Some modules have interdependencies (documented in their files)