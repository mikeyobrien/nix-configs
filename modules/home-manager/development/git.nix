# ABOUTME: Git version control configuration module
# ABOUTME: Manages git settings, aliases, and conditional includes

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.development.git;
in {
  options.modules.development.git = {
    enable = mkEnableOption "Git configuration";
    
    userName = mkOption {
      type = types.str;
      default = "Mikey O'Brien";
      description = "Default git user name";
    };
    
    userEmail = mkOption {
      type = types.str;
      default = "me@mikeyobrien.com";
      description = "Default git user email";
    };
    
    editor = mkOption {
      type = types.str;
      default = "vim";
      description = "Default git editor";
    };
    
    extraAliases = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional git aliases";
    };
    
    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional git configuration";
    };
  };
  
  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = cfg.userName;
      userEmail = cfg.userEmail;
      
      includes = [
        {
          condition = "gitdir:~/code/";
          contents = {
            user = {
              name = "Mikey O'Brien";
              email = "me@mikeyobrien.com";
            };
          };
        }
        {
          condition = "gitdir:/workplace";
          contents = {
            user = {
              name = "Mikey O'Brien";
              email = "mobrienv@amazon.com";
            };
          };
        }
        {
          condition = "gitdir:~/workplace";
          contents = {
            user = {
              name = "Mikey O'Brien";
              email = "mobrienv@amazon.com";
            };
          };
        }
      ];

      extraConfig = {
        safe.directory = ["*"];
        core.editor = cfg.editor;
        color.ui = true;
      } // cfg.extraConfig;
      
      aliases = {
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      } // cfg.extraAliases;
    };
  };
}