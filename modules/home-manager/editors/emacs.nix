# ABOUTME: Emacs editor configuration with Darwin-specific builds
# ABOUTME: Uses emacs30 on Darwin and emacs30-pgtk on Linux

{ lib, config, pkgs, inputs, ... }:

with lib;
let 
  cfg = config.modules.editors.emacs;
  
  # Select the appropriate Emacs package based on the system
  emacsPackage = if pkgs.stdenv.isDarwin 
    then pkgs.emacs30
    else pkgs.emacs30-pgtk;
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

    # Add shell alias for macOS to use the app bundle
    programs.fish.shellAliases = mkIf pkgs.stdenv.isDarwin {
      emacs = "${emacsPackage}/Applications/Emacs.app/Contents/MacOS/Emacs";
    };

    home.packages = with pkgs; [
      ## Emacs itself
      binutils            # native-comp needs 'as', provided by this
      emacsPackage        # Platform-specific Emacs build
      (pkgs.nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
    ] ++ lib.optionals (!pkgs.stdenv.isDarwin) [
      grip                # Not available on macOS
    ] ++ [
      ## Doom dependencies
      git
      ripgrep
      gnutls              # for TLS connectivity
      (emacsPackagesFor emacsPackage).pdf-tools
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
