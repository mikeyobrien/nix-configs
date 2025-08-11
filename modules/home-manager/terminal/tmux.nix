# ABOUTME: Tmux terminal multiplexer configuration module
# ABOUTME: Provides session management and window splitting capabilities

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.terminal.tmux;
in {
  options.modules.terminal.tmux = {
    enable = mkEnableOption "tmux terminal multiplexer";
    
    prefix = mkOption {
      type = types.str;
      default = "C-a";
      description = "Tmux prefix key";
    };
    
    enableVimNavigation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable vim-style navigation between tmux panes";
    };
    
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional tmux configuration";
    };
  };
  
  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      terminal = "screen-256color";
      escapeTime = 0;
      prefix = cfg.prefix;
      keyMode = "vi";
      baseIndex = 1;
      aggressiveResize = true;
      
      plugins = with pkgs; [
        {
          plugin = tmuxPlugins.yank;
          extraConfig = ''
            set -g @yank_selection 'primary'
            bind-key -T copy-mode-vi 'v' send -X begin-selection
            bind-key -T copy-mode-vi 'r' send -X rectangle-toggle
            bind-key -T copy-mode-vi 'y' send -X copy-pipe-and-cancel
            bind Enter copy-mode
          '';
        }
        tmuxPlugins.power-theme
      ] ++ (optional cfg.enableVimNavigation tmuxPlugins.vim-tmux-navigator);
      
      extraConfig = ''
        ${if builtins.pathExists ../../home-manager/tmux.conf
          then builtins.readFile ../../home-manager/tmux.conf
          else ""}
        ${cfg.extraConfig}
      '';
    };
  };
}