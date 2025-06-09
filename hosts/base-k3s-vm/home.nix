# ABOUTME: Base home-manager configuration for k3s VM nodes
# ABOUTME: Provides minimal user-level settings for VM users

{ config, pkgs, lib, ... }:

{
  # This is a minimal home configuration that can be imported by specific hosts
  
  # Basic shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      k = "kubectl";
      kgp = "kubectl get pods";
      kgs = "kubectl get svc";
      kgn = "kubectl get nodes";
    };
  };

  # Git configuration (basic)
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # Basic vim configuration
  programs.vim = {
    enable = true;
    settings = {
      number = true;
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
    };
    extraConfig = ''
      set autoindent
      set smartindent
      set ignorecase
      set smartcase
      set hlsearch
      set incsearch
      
      " Enable syntax highlighting
      syntax enable
      
      " Better colors for dark terminals
      set background=dark
    '';
  };

  # Useful shell tools
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    eza
    duf
  ];

  # Session variables
  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less";
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}