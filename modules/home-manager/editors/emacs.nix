# Emacs is my main driver. I'm the author of Doom Emacs
# https://github.com/doomemacs. This module sets it up to meet my particular
# Doomy needs.

{ lib, config, pkgs, inputs, ... }:

with lib;
let cfg = config.modules.editors.emacs;
    emacs = with pkgs; (emacsPackagesFor
      #(if config.modules.desktop.type == "wayland"
      emacs-pgtk
      # else emacs-git)).emacsWithPackages (epkgs: with epkgs; [
      #   treesit-grammars.with-all-grammars
      #   vterm
      #   mu4e ]);
      );
in {
  options.modules.editors.emacs = {
    enable = lib.mkEnableOption "Emacs";
    # doom = rec {
    #   enable = mkBoolOpt false;
    #   forgeUrl = mkOpt types.str "https://github.com";
    #   repoUrl = mkOpt types.str "${forgeUrl}/doomemacs/doomemacs";
    #   configRepoUrl = mkOpt types.str "${forgeUrl}/hlissner/.doom.d";
    # };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      inputs.emacs-overlay.overlays.default
    ];

    home.packages = with pkgs; [
      ## Emacs itself
      binutils            # native-comp needs 'as', provided by this
      emacs-pgtk               # HEAD + native-comp
      (pkgs.nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })

      ## Doom dependencies
      git
      ripgrep
      gnutls              # for TLS connectivity

      ## Optional dependencies
      fd                  # faster projectile indexing
      imagemagick         # for image-dired
      zstd                # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
      # :tools editorconfig
      editorconfig-core-c # per-project style config
      # :tools lookup & :lang org +roam
      sqlite
      # :lang cc
      clang-tools
      # :lang latex & :lang org (latex previews)
      texlive.combined.scheme-medium
      # :lang beancount
      beancount
      fava
      # :lang nix
      age
    ];
  };
}
