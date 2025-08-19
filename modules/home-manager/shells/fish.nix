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
        "# Add Nix profile paths"
        "if test -e $HOME/.nix-profile/bin"
        "  fish_add_path --prepend $HOME/.nix-profile/bin"
        "end"
        "set -gx PATH $PATH $HOME/bin"
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
      nodejs
    ];
  };
}