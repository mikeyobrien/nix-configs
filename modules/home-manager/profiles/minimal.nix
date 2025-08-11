# ABOUTME: Example minimal profile - just the base without any extras
# ABOUTME: Useful for servers or containers where you want explicit control

{ ... }:

{
  # This profile adds nothing - you get only what's in base home.nix:
  # - Essential packages (fd, ripgrep, tree, jq, bat, htop, fzf)
  # - Fish shell with prompt
  # - That's it!
  
  # You can then add only what you need:
  # modules.development.git.enable = true;
  # modules.terminal.tmux.enable = true;
}
