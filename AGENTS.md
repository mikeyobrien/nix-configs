# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix`: single entrypoint composing hosts, images, overlays, and formatters.
- `hosts/`: per-host NixOS, Darwin, and Home Manager configs; mirrors production layouts.
- `modules/`: shareable `nixos/` and `home-manager/` modules consumed by the flake outputs.
- `overlays/`, `pkgs/`, `lib/`: package overlays, custom derivations, and helper libraries reused across hosts.
- `tests/`: unit, integration, validation, health, and e2e suites; see `tests/helpers` for common utilities.
- `scripts/`: provisioning and build helpers for VMs and clusters; run from repo root.
- `secrets/`: Age-encrypted blobs managed with agenix—never store plaintext secrets.

## Build, Test, and Development Commands
- `nix flake check`: evaluate the flake, run linting, and catch schema drifts early.
- `nix build .#images.orchard`: produce the Orchard VM image under `./result` for manual testing.
- `nix build .#homeConfigurations.rainforest.activationPackage && ./result/activate`: build and activate the Rainforest Home Manager profile.
- `sudo nixos-rebuild switch --flake .#reef` or `just switch-reef`: apply the Reef host configuration locally.
- `./tests/run-all.sh [-v]`: execute the full shell test suite; use `-v` for verbose logs.
- `./tests/unit/test-framework-example.sh`: run a focused example test when iterating locally.

## Coding Style & Naming Conventions
- Nix code uses 2-space indentation and logically sorted attributes; format with `nix fmt` (Alejandra).
- Shell scripts target `bash`, start with `set -euo pipefail`, live in kebab-case filenames, and keep the executable bit set.
- Hosts, modules, and packages use lowercase-kebab names (e.g., `orchard`, `base-k3s-vm`); avoid camelCase introductions.

## Testing Guidelines
- Favor behavior-focused shell tests built on `tests/helpers`; supplement with Nix expressions where necessary.
- Name shell suites `test-*.sh` or `*_test.sh`; Nix specs end with `_test.nix` to stay discoverable.
- Run `./tests/run-all.sh` and `nix flake check` before committing; capture failing command output in PR discussions.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat(k3s): enable longhorn prereqs`) or concise action verbs (`Add`, `Refactor`).
- Keep changes atomic, referencing affected hosts/modules and explaining why adjustments are needed.
- Pull requests include a summary, impacted components, linked issues, key command outputs, and screenshots/log snippets for regressions.

## Security & Configuration Tips
- Manage secrets exclusively with agenix under `secrets/<name>.age`; edit using `agenix -e` and avoid intermediate plaintext files.
- Prefer dry-run and sandboxed Nix commands when validating changes to prevent accidental system drift.
- Lean on flake outputs for Home Manager and NixOS activation to preserve reproducibility across environments.
