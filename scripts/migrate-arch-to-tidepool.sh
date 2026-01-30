#!/usr/bin/env bash
# migrate-arch-to-tidepool.sh
#
# Migrates user config from the Arch VM (user: arch) to tidepool microVM (user: mobrienv).
# Two phases:
#   archive  - SSH to arch, tar up relevant home dir files, copy to local staging
#   deploy   - SSH to tidepool, push staged archive, extract with correct paths
#
# Usage:
#   ./migrate-arch-to-tidepool.sh archive   # Run from any machine with SSH to arch
#   ./migrate-arch-to-tidepool.sh deploy    # Run from any machine with SSH to tidepool
#   ./migrate-arch-to-tidepool.sh sync-code # Sync code repos from arch to reef

set -euo pipefail

ARCH_HOST="arch"
TIDEPOOL_HOST="tidepool"
STAGING_DIR="${HOME}/.cache/tidepool-migration"
ARCHIVE_NAME="arch-home-migration.tar.gz"
ARCH_USER="arch"
TIDEPOOL_USER="mobrienv"

# Files and directories to migrate (relative to home dir)
MIGRATE_PATHS=(
  # SSH keys and config
  .ssh/github_rsa
  .ssh/id_ed25519
  .ssh/id_ed25519.pub
  .ssh/authorized_keys
  .ssh/config
  .ssh/known_hosts
  .ssh/agent/

  # Claude Code
  .claude/settings.json
  .claude/settings.local.json
  .claude/mcp.json
  .claude/CLAUDE.md
  .claude/.credentials.json
  .claude/commands/
  .claude/hooks/
  .claude/skills/
  .claude/agents/
  .claude.json

  # App configs
  .config/gh/hosts.yml
  .config/argocd/config
  .config/rclone/rclone.conf
  .config/gcloud/
  .config/pushover/credentials
  .config/atuin/config.toml

  # Dev tooling
  .gitconfig
  .npmrc
  .kube/config
  .cargo/config.toml
  .cargo/env
  .fly/

  # Misc
  .rustup/settings.toml
)

log() { echo "[migrate] $*"; }
warn() { echo "[migrate] WARNING: $*" >&2; }
die() { echo "[migrate] ERROR: $*" >&2; exit 1; }

cmd_archive() {
  log "Phase 1: Archive config from ${ARCH_HOST}"
  mkdir -p "$STAGING_DIR"

  # Build the find list on the remote, only including files that exist
  log "Collecting files from ${ARCH_HOST}..."
  local paths_arg=""
  for p in "${MIGRATE_PATHS[@]}"; do
    paths_arg+="\"$p\" "
  done

  # Create archive on arch, streaming back to local staging
  ssh "$ARCH_HOST" "bash -s" <<'REMOTE_SCRIPT' > "${STAGING_DIR}/${ARCHIVE_NAME}"
set -euo pipefail
cd "$HOME"

PATHS=(
  .ssh/github_rsa
  .ssh/id_ed25519
  .ssh/id_ed25519.pub
  .ssh/authorized_keys
  .ssh/config
  .ssh/known_hosts
  .ssh/agent/
  .claude/settings.json
  .claude/settings.local.json
  .claude/mcp.json
  .claude/CLAUDE.md
  .claude/.credentials.json
  .claude/commands/
  .claude/hooks/
  .claude/skills/
  .claude/agents/
  .claude.json
  .config/gh/hosts.yml
  .config/argocd/config
  .config/rclone/rclone.conf
  .config/gcloud/
  .config/pushover/credentials
  .config/atuin/config.toml
  .gitconfig
  .npmrc
  .kube/config
  .cargo/config.toml
  .cargo/env
  .fly/
  .rustup/settings.toml
)

EXISTING=()
for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    EXISTING+=("$p")
  fi
done

if [ ${#EXISTING[@]} -eq 0 ]; then
  echo "No files found to archive" >&2
  exit 1
fi

echo "Archiving ${#EXISTING[@]} paths" >&2
tar czf - "${EXISTING[@]}"
REMOTE_SCRIPT

  local size
  size=$(du -h "${STAGING_DIR}/${ARCHIVE_NAME}" | cut -f1)
  log "Archive created: ${STAGING_DIR}/${ARCHIVE_NAME} (${size})"
  log ""
  log "Archive contents:"
  tar tzf "${STAGING_DIR}/${ARCHIVE_NAME}" | head -40
  local total
  total=$(tar tzf "${STAGING_DIR}/${ARCHIVE_NAME}" | wc -l)
  log "... ${total} files total"
  log ""
  log "Next: run '$0 deploy' after tidepool is booted"
}

cmd_deploy() {
  log "Phase 2: Deploy config to ${TIDEPOOL_HOST}"

  local archive="${STAGING_DIR}/${ARCHIVE_NAME}"
  [ -f "$archive" ] || die "Archive not found at ${archive}. Run '$0 archive' first."

  # Verify tidepool is reachable
  log "Checking connectivity to ${TIDEPOOL_HOST}..."
  ssh -o ConnectTimeout=5 "$TIDEPOOL_HOST" 'echo ok' >/dev/null 2>&1 \
    || die "Cannot SSH to ${TIDEPOOL_HOST}. Is it booted and on the network/tailnet?"

  log "Deploying archive to ${TIDEPOOL_HOST}..."

  # Upload archive
  scp "$archive" "${TIDEPOOL_HOST}:/tmp/${ARCHIVE_NAME}"

  # Extract and fix paths on tidepool
  ssh "$TIDEPOOL_HOST" "bash -s" <<REMOTE_DEPLOY
set -euo pipefail

cd "\$HOME"
echo "Extracting archive..."
tar xzf "/tmp/${ARCHIVE_NAME}"
rm "/tmp/${ARCHIVE_NAME}"

# Fix SSH permissions
chmod 700 "\$HOME/.ssh" 2>/dev/null || true
chmod 600 "\$HOME/.ssh/github_rsa" 2>/dev/null || true
chmod 600 "\$HOME/.ssh/id_ed25519" 2>/dev/null || true
chmod 600 "\$HOME/.ssh/authorized_keys" 2>/dev/null || true
chmod 644 "\$HOME/.ssh/id_ed25519.pub" 2>/dev/null || true
chmod 600 "\$HOME/.ssh/config" 2>/dev/null || true
chmod 600 "\$HOME/.kube/config" 2>/dev/null || true

# Fix paths: /home/arch -> /home/${TIDEPOOL_USER}
echo "Fixing paths from /home/${ARCH_USER} -> /home/${TIDEPOOL_USER}..."
for f in .ssh/config .npmrc .claude/mcp.json .claude/CLAUDE.md .claude/settings.local.json; do
  if [ -f "\$f" ]; then
    sed -i "s|/home/${ARCH_USER}|/home/${TIDEPOOL_USER}|g" "\$f"
  fi
done

# Update SSH config hostnames for tidepool context
if [ -f .ssh/config ]; then
  echo "Note: Review ~/.ssh/config - host entries may need updating for tidepool network"
fi

# Update .claude/CLAUDE.md OS reference
if [ -f .claude/CLAUDE.md ]; then
  sed -i 's/OS: Linux (Arch-based)/OS: Linux (NixOS - tidepool microVM)/g' .claude/CLAUDE.md
fi

# Update .npmrc prefix path
if [ -f .npmrc ]; then
  sed -i "s|prefix=.*|prefix=/home/${TIDEPOOL_USER}/.npm-global|" .npmrc
fi

echo "Done. Files deployed to \$HOME"
echo ""
echo "Post-deploy checklist:"
echo "  1. ssh-add ~/.ssh/github_rsa"
echo "  2. gh auth status           # verify GitHub auth"
echo "  3. npm install -g @anthropic-ai/claude-code"
echo "  4. claude config set apiKey <key>"
echo "  5. Review ~/.claude/mcp.json for path correctness"
echo "  6. Review ~/.ssh/config for correct hostnames"
REMOTE_DEPLOY

  log "Deploy complete."
}

cmd_sync_code() {
  log "Syncing code repos from ${ARCH_HOST} to reef"
  log ""
  log "This rsyncs /home/${ARCH_USER}/code/ on arch to /home/${TIDEPOOL_USER}/code/ on reef."
  log "The tidepool VM mounts reef's /home/${TIDEPOOL_USER}/code via virtiofs."
  log ""

  # Get list of repos on arch
  log "Repos on arch:"
  ssh "$ARCH_HOST" 'bash -c "ls -d ~/code/*/"' 2>&1

  read -rp "Proceed with sync? [y/N] " confirm
  [[ "$confirm" =~ ^[yY] ]] || { log "Aborted."; exit 0; }

  # rsync from arch to reef's code directory
  # Using ssh proxy: arch -> local -> reef would be slow
  # Better: rsync directly from arch to reef if arch can reach reef
  log "Syncing via rsync (arch -> reef)..."
  ssh "$ARCH_HOST" "bash -c 'rsync -avz --progress ~/code/ ${TIDEPOOL_USER}@192.168.1.2:/home/${TIDEPOOL_USER}/code/'" 2>&1 \
    || {
      warn "Direct arch->reef rsync failed. Trying two-hop sync..."
      log "Pulling from arch to local staging, then pushing to reef."
      mkdir -p "${STAGING_DIR}/code"
      rsync -avz --progress "${ARCH_HOST}:code/" "${STAGING_DIR}/code/"
      log "Now push to reef (requires SSH access to reef)..."
      rsync -avz --progress "${STAGING_DIR}/code/" "reef:/home/${TIDEPOOL_USER}/code/"
    }

  log "Code sync complete."
}

case "${1:-help}" in
  archive)
    cmd_archive
    ;;
  deploy)
    cmd_deploy
    ;;
  sync-code)
    cmd_sync_code
    ;;
  help|--help|-h)
    echo "Usage: $0 {archive|deploy|sync-code}"
    echo ""
    echo "  archive    - Create archive of config files from Arch VM"
    echo "  deploy     - Deploy archived config to tidepool VM"
    echo "  sync-code  - Sync code repos from Arch to reef (tidepool's virtiofs source)"
    echo ""
    echo "Workflow:"
    echo "  1. Boot tidepool:  sudo nixos-rebuild switch --flake .#reef"
    echo "  2. Archive:        $0 archive"
    echo "  3. Sync code:      $0 sync-code"
    echo "  4. Join tailnet:   ssh mobrienv@192.168.1.9 'sudo tailscale up --ssh'"
    echo "  5. Deploy config:  $0 deploy"
    echo "  6. Install tools:  ssh tidepool 'npm i -g @anthropic-ai/claude-code'"
    ;;
  *)
    die "Unknown command: $1. Use '$0 help' for usage."
    ;;
esac
