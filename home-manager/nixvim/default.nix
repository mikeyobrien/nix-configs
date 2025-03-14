{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.editors.nixvim;
in {
  options.editors.nixvim = {
    enable = lib.mkEnableOption "nixvim program";
  };

  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./keymaps.nix
    ./telescope.nix
    ./lsp.nix
    ./lazy.nix
    ./conform.nix
    ./trouble.nix
    ./copilot.nix
    ./lualine.nix
    ./harpoon.nix
    ./treesitter.nix
    ./lazygit.nix
    #./indentscope.nix
    #./java.nix
  ];

  config = lib.mkIf cfg.enable {
    home.shellAliases.v = "nvim";
    programs.nixvim = {
      enable = true;

      colorschemes.tokyonight.enable = true;
      colorschemes.tokyonight.settings.integrations.treesitter = true;
      defaultEditor = true;
      luaLoader.enable = true;

      viAlias = true;
      vimAlias = true;
      globals.mapleader = " ";

      clipboard.providers.wl-copy.enable = true;
      clipboard.register = "unnamedplus";

      opts = {
        timeoutlen = 500;
        number = true;
        relativenumber = true;
        signcolumn = "yes";
        ignorecase = true;
        smartcase = true;
        undofile = true;
        undodir.__raw = "vim.fn.expand(\"~/.config/nvim/undodir\")";

        # Tab defaults (might get overwritten by an LSP server)
        tabstop = 2;
        shiftwidth = 2;
        softtabstop = 2;
        expandtab = true;
        smarttab = true;

        ruler = true;
        scrolloff = 5;
      };

      # LSP servers are configured at nix build time, contrary to using mason
      plugins.lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          lua-ls.enable = true;
        };
      };

      extraConfigLuaPost = ''
        -- For configurations that i'm testing before adding to nixVim
        local file_path = vim.fn.stdpath("config") .. "/extraConfig.lua"
        local config_file = io.open(file_path, "r")
        if config_file then
          dofile(file_path)
          vim.g.extra_config_loaded = true
        else
          vim.g.extra_config_loaded = false
        end
      '';
    };
  };
}
