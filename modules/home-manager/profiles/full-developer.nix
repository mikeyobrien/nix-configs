# ABOUTME: Profile for full-stack developers with GUI and CLI needs
# ABOUTME: Includes all development tools, editors, and productivity features

{ config, lib, pkgs, ... }:

{
  # All CLI tools
  modules.core.commonCli.enable = true;
  
  # Full development stack
  modules.development = {
    enable = true;  # Enables all submodules
    gpg.enable = true;
    uvx.enable = true;
  };
  
  # All terminal tools
  modules.terminal = {
    alacritty.enable = true;
    tmux.enable = true;
    zellij.enable = true;
  };
  
  # Multiple editors for different use cases
  modules.editors = {
    neovim.enable = true;
    emacs.enable = true;
  };
  
  # LLM tools for AI-assisted development
  llm-tools.enable = true;
  
  # Fonts for editors and terminals
  modules.core.fonts.enable = true;
}