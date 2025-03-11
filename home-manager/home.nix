{
  config,
  pkgs,
  lib,
  inputs,
  outputs,
  user,
  ...
}: 

{
  imports = [
    (import ./nixvim {inherit config lib inputs pkgs;})
    (import ./llm.nix)
  ];
  nixpkgs.overlays = [
      outputs.overlays.modifications
      outputs.overlays.additions
      outputs.overlays.unstable-packages
  ];

  home.packages = [
    (pkgs.nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono"];})
    pkgs.jq
    pkgs.fd
    pkgs.ripgrep
    pkgs.cachix
    pkgs.babashka
    pkgs.expect
    pkgs.htop
    pkgs.ripgrep
    pkgs.fzf
    pkgs.bat
    pkgs.nix-direnv
    pkgs.yadm
    pkgs.grc
    pkgs.tree-sitter
    pkgs.xsv
    pkgs.nodejs
    pkgs.pass
    pkgs.ispell
    pkgs.tree
    pkgs.lazygit
    pkgs.glow
    pkgs.just

    pkgs.nil
    pkgs.devenv
  ];

  llm-tools.enable = true;

  programs.neovim = {
    enable = true;
    package = pkgs.neovim;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    
    extraWrapperArgs = [
      "--suffix"
      "LIBRARY_PATH"
      ":"
      "''${lib.makeLibraryPath [ pkgs.stdenv.cc.cc pkgs.zlib ]}"
      "--suffix"
      "PKG_CONFIG_PATH"
      ":"
      "''${lib.makeSearchPathOutput "dev" "lib/pkgconfig" [ pkgs.stdenv.cc.cc pkgs.zlib ]}"
    ];

    extraPackages = [
      pkgs.lua51Packages.lua
      pkgs.lua51Packages.luarocks
      pkgs.lua-language-server
      pkgs.stylua
      pkgs.black
      pkgs.cargo
    ];
  };

  programs.direnv.enable = true;
  programs.gpg.enable = true;

  programs.starship = {
    enable = true;
    settings = {
      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) ";
      };
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font.size = 14;
      font.normal.family = "JetBrainsMono Nerd Font";
      keyboard.bindings = [
        {
          key = "K";
          mods = "Command";
          chars = "ClearHistory";
        }
        {
          key = "V";
          mods = "Command";
          action = "Paste";
        }
        {
          key = "C";
          mods = "Command";
          action = "Copy";
        }
        {
          key = "Key0";
          mods = "Command";
          action = "ResetFontSize";
        }
        {
          key = "Equals";
          mods = "Command";
          action = "IncreaseFontSize";
        }
        {
          key = "Minus";
          mods = "Command";
          action = "DecreaseFontSize";
        }
        {
          key = "N";
          mods = "Shift|Control";
          action = "CreateNewWindow";
        }
      ];
    };
  };

  programs.bash = {
    enable = false;
    shellOptions = [];
    historyControl = ["ignoredups" "ignorespace"];

    shellAliases = {
      bbka = lib.getExe pkgs.babashka;
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
    };
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      bbka = lib.getExe pkgs.babashka;
      python = "python3";
      ga = "git add";
      gd = "git diff";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
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
      tn = "tmux new-session -s";
      ta = "tmux attach -t";
      tl = "tmux list-sessions";
      tk = "tmux kill-session -t";
      kgp = "kubectl get pods";
      aas = "argocd app sync";
      ntfycmd = "curl -d \"success\" https://ntfy.mikeyobrien.com/testing || curl -d \"failure\" https://ntfy.mikeyobrien.com/testing";
      #emacs = "${pkgs.emacs-git}/Applications/Emacs.app/Contents/MacOS/Emacs";
    };
    # This is necessary to run mason downloaded LSPs
    # https://www.reddit.com/r/NixOS/comments/13uc87h/comment/kgraua7/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
      (builtins.readFile ./fish.config)
      "set -g SHELL ${pkgs.fish}/bin/fish"
      "set -gx PATH $PATH $HOME/bin"
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

  programs.zellij = {
    enable = true;
    #enableFishIntegration = true;
    settings = {
      theme = "gruvbox-dark";
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    escapeTime = 0;
    prefix = "C-a";
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
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.power-theme
    ];
    extraConfig = builtins.readFile ./tmux.conf;
  };

  programs.git = {
    enable = true;
    userName = "Mikey O'Brien";
    userEmail = "me@mikeyobrien.com";
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
      core.editor = "vim";
      color.ui = true;
    };
    aliases = {
      prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      root = "rev-parse --show-toplevel";
    };
  };

  programs.home-manager.enable = true;
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
