# ABOUTME: Fish shell configuration module with plugins and integrations
# ABOUTME: Provides a feature-rich fish shell setup with common developer tools

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.shells.fish;
  commonAliases = config.modules.shells.common.aliases;
in {
  options.modules.shells.fish = {
    enable = mkEnableOption "fish shell configuration";
    
    enableAtuin = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Atuin shell history";
    };
    
    enableZoxide = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Zoxide directory jumper";
    };
    
    extraAliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional fish-specific aliases";
    };
    
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional fish configuration";
    };
  };
  
  config = mkIf cfg.enable {
    # Enable SSH agent with fish shell integration
    services.ssh-agent.enable = true;

    programs.fish = {
      enable = true;
      
      shellAliases = commonAliases // {
        # Docker aliases
        dpss = "docker ps | less -S";
        dc = "docker compose";
        dcu = "docker compose up";
        dcud = "docker compose up -d";
        dcd = "docker compose down";
        dcps = "docker compose ps";
        dclogs = "docker compose logs";
        dcbuild = "docker compose build";
        dcpull = "docker compose pull";
        dcexec = "docker compose exec";
        dcrestart = "docker compose restart";
        
        # Tmux aliases
        tn = "tmux new-session -s";
        ta = "tmux attach -t";
        tl = "tmux list-sessions";
        tk = "tmux kill-session -t";

        # Zellij aliases
        zj = "zellij";
        zja = "zellij attach";
        zjl = "zellij list-sessions";
        zjk = "zellij kill-session";
        zjka = "zellij kill-all-sessions";
        zjd = "zellij delete-session";
        zjda = "zellij delete-all-sessions";
        zje = "zellij edit";
        zjr = "zellij run --";
        zjrf = "zellij run --floating --";
        zjac = "zellij action";

        # Kubernetes aliases
        kgp = "kubectl get pods";
        
        # Other aliases
        aas = "argocd app sync";
        ntfycmd = "curl -d \"success\" https://ntfy.mikeyobrien.com/testing || curl -d \"failure\" https://ntfy.mikeyobrien.com/testing";
      } // cfg.extraAliases;
      
      interactiveShellInit = strings.concatStrings (strings.intersperse "\n" [
        (if builtins.pathExists ../../home-manager/fish.config
         then builtins.readFile ../../home-manager/fish.config
         else "")
        "set -g SHELL ${pkgs.fish}/bin/fish"
        "# Initialize mise (rtx) - must come before nix paths"
        "if type -q mise"
        "  mise activate fish | source"
        "end"
        "# Add Nix profile paths (home-manager handles this automatically)"
        "set -gx PATH $PATH $HOME/bin"
        "fish_add_path $HOME/.local/bin/"
        "# Add npm global bin directory"
        "if test -e $HOME/.npm-global/bin"
        "  fish_add_path $HOME/.npm-global/bin"
        "end"
        "# Add local bin directory"
        "if test -e $HOME/.local/bin"
        "  fish_add_path $HOME/.local/bin"
        "end"
        "# Claude Code aliases (if installed)"
        "if type -q claude"
        "  alias cl='claude'                                           # Start interactive session"
        "  alias clc='claude -c'                                       # Continue previous conversation"
        "  alias clp='claude -p'                                       # Print mode (non-interactive)"
        "  alias clr='claude -r'                                       # Resume session by ID"
        "  alias cls='claude --model sonnet'                           # Use Sonnet model"
        "  alias clo='claude --model opus'                             # Use Opus model"
        "  alias clh='claude --model haiku'                            # Use Haiku model"
        "  alias clv='claude --verbose'                                # Enable verbose output"
        "  alias cly='claude --dangerously-skip-permissions'           # Skip all permission prompts (yolo mode)"
        "  alias clyc='claude -c --dangerously-skip-permissions'       # Continue with skip permissions"
        "end"
        cfg.extraConfig
      ]);
      
      plugins = [
        {
          name = "grc";
          src = pkgs.fishPlugins.grc.src;
        }
        {
          name = "fzf";
          src = pkgs.fishPlugins.fzf-fish.src;
        }
        {
          name = "bass";
          src = pkgs.fishPlugins.bass.src;
        }
      ];
    };
    
    programs.atuin = mkIf cfg.enableAtuin {
      enable = true;
      enableFishIntegration = true;
    };
    
    programs.zoxide = mkIf cfg.enableZoxide {
      enable = true;
      enableFishIntegration = true;
    };
    
    home.packages = with pkgs; [
      babashka
      expect
    ];
  };
}
