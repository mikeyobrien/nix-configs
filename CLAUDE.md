# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview
- Modular Nix configuration repository covering NixOS, macOS (nix-darwin), WSL, Nix-on-Droid, and microVM environments.
- Hosts currently managed: moss, wsl, rhizome, driftwood, reef, rainforest, studio, coral, g14, droid.
- Home Manager delivers user profiles; agenix handles secrets; `just` scripts wrap frequent workflows.

## Key Commands
### System & Home Management
```bash
sudo nixos-rebuild switch --flake .#<hostname>         # NixOS switch
sudo nixos-rebuild test --flake .#<hostname>           # NixOS dry run
sudo nixos-rebuild build --flake .#<hostname>          # Build only

darwin-rebuild switch --flake .#rainforest             # macOS switch

nix build .#homeConfigurations.<host>.activationPackage
./result/activate                                      # Apply Home Manager build
home-manager switch --flake .#<host> [-b backup]       # Alternative HM apply

nix build .#images.<image>                             # Build VM images
```

### Development Flow
```bash
nix fmt                                                # Format Nix files (alejandra)
nix flake check                                        # Evaluate flake + checks
nix flake update                                       # Refresh all inputs
nix flake lock --update-input <name>                   # Update specific input
nix search nixpkgs <package>                           # Package search
nix build .#homeConfigurations.<host>.activationPackage --dry-run
```

### Just Commands
```bash
just switch-driftwood
just switch-reef
```

## Architecture
### Directory Structure
- `hosts/`: Host-specific NixOS, Darwin, WSL, and Droid configs (`configuration.nix`, `home.nix`).
- `home-manager/`: Shared base and helper modules (`home.nix`, `llm.nix`).
- `modules/`: Reusable NixOS and Home Manager modules grouped by domain.
- `pkgs/`: Custom derivations; `overlays/`: package overlays.
- `lib/`: Helper functions such as `mkSystem.nix`.
- `scripts/`, `tests/`, `monitoring/`, `microvms/`: Operational tooling.
- `secrets/`: Age-encrypted blobs managed with agenix.

### Module System Pattern
```nix
{ config, lib, pkgs, ... }:
with lib;
let cfg = config.modules.<category>.<name>;
in {
  options.modules.<category>.<name> = {
    enable = mkEnableOption "description";
    # additional options ...
  };

  config = mkIf cfg.enable {
    # implementation
  };
}
```

Module categories include:
- `modules.core.*` – essential packages, CLI tooling, fonts.
- `modules.development.*` – language tooling, git, direnv, uvx.
- `modules.editors.*` – editor-related modules (neovim, emacs).
- `modules.shells.*` – shell defaults, prompts.
- `modules.terminal.*` – tmux, zellij, terminal utilities.
- `modules.profiles.*` – opinionated bundles such as `cli-developer`.
- `modules.llm` – LLM tooling shared across hosts.

### Host Configuration Pattern
```nix
{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    # optional profiles, e.g. outputs.homeManagerModules.profiles.cli-developer
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}"; # override for darwin with mkForce
  };

  modules.core.commonCli.enable = true;
  modules.development.git.enable = true;
  modules.shells.fish.enable = lib.mkForce false; # example override
}
```

### Host Types
- **Standard NixOS**: moss, rhizome, reef, driftwood.
- **Servers / MicroVM**: reef hosts virtualization helpers, dev microVM profile under `microvms/`.
- **WSL**: Tailored Home Manager tweaks for Windows Subsystem.
- **Darwin**: rainforest, studio use nix-darwin with Home Manager.
- **Android**: Nix-on-Droid configuration under `hosts/droid/`.

## Composition Guidelines
- Base `home-manager/home.nix` remains intentionally minimal: essential packages plus fish/prompt defaults.
- Hosts enable additional modules or profiles explicitly; prefer additive composition over bespoke configs.
- Use `lib.mkForce` sparingly for host-specific overrides.
- Profiles bundle common stacks (`cli-developer`, `desktop-user`, etc.).

## Testing & Workflow Notes
1. Build target configuration: `nix build .#homeConfigurations.<host>.activationPackage`.
2. Apply or test on relevant hosts (e.g., `sudo nixos-rebuild test`).
3. Run formatters (`nix fmt`) before commit.
4. Dry-run risky changes (`--dry-run`, `home-manager switch -b backup`).

## Known Issues & Workarounds
- `devenv` builds can fail; module kept disabled until flake channel resolves.
- WSL setup occasionally needs multiple activation attempts; rerun `nixos-rebuild` if first run flakes.
- Use `home-manager switch -b backup` when touching dotfiles to keep automatic backups.

## Git Workflow
This repository uses a local-first git workflow without PRs:
1. Create feature branches for development work.
2. When ready to merge:
   - Rebase the feature branch onto `main`.
   - Squash commits into a single descriptive commit (interactive rebase or soft reset both fine).
   - Merge directly into `main` (`--ff-only`) and delete the feature branch.

Example:
```bash
# Create feature branch
git checkout -b my-feature

# ... make changes and commits ...

# Prepare to merge
git checkout my-feature
# Option A: interactive rebase
git rebase -i main
# Option B: soft reset approach
git reset --soft main
git commit -m "Comprehensive commit message

Detailed description of all changes..."

# Fast-forward merge
git checkout main
git merge my-feature --ff-only

git branch -d my-feature
```

## Secrets & Security
- Manage secrets exclusively via agenix; edit with `agenix -e` and keep blobs in `secrets/*.age`.
- Avoid storing plaintext secrets or bypassing commit hooks.

## macOS Fish Shell Note
On Darwin systems, set fish as the default shell using the system-wide path:
```bash
chsh -s /run/current-system/sw/bin/fish
```
