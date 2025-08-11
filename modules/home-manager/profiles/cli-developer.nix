# ABOUTME: Profile for CLI-focused developers
# ABOUTME: Includes common development tools without GUI applications

{ config, lib, pkgs, ... }:

{
  # Common CLI tools beyond essentials
  modules.core.commonCli.enable = true;
  
  # Development environment
  modules.development = {
    git.enable = true;
    direnv.enable = true;
    languages.enable = true;
    tools.enable = true;
  };
  
  # Terminal multiplexer (choose one or both)
  modules.terminal.tmux.enable = true;
  
  # Editor (neovim is a good CLI default)
  modules.editors.neovim.enable = true;
}