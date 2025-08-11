# ABOUTME: Neovim editor configuration module
# ABOUTME: Provides a full-featured Neovim setup with LSP support

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.editors.neovim;
in {
  options.modules.editors.neovim = {
    enable = mkEnableOption "Neovim editor";
    
    defaultEditor = mkOption {
      type = types.bool;
      default = true;
      description = "Set Neovim as the default editor";
    };
    
    viAlias = mkOption {
      type = types.bool;
      default = true;
      description = "Create vi alias for Neovim";
    };
    
    vimAlias = mkOption {
      type = types.bool;
      default = true;
      description = "Create vim alias for Neovim";
    };
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages available to Neovim";
    };
  };
  
  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      package = pkgs.neovim;
      defaultEditor = cfg.defaultEditor;
      viAlias = cfg.viAlias;
      vimAlias = cfg.vimAlias;
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

      extraPackages = with pkgs; [
        lua51Packages.lua
        lua51Packages.luarocks
        lua-language-server
        stylua
        black
        cargo
      ] ++ cfg.extraPackages;
    };
  };
}