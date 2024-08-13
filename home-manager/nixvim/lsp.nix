{pkgs, ...}: {
  home.packages = [
    pkgs.nodePackages.typescript-language-server
  ];

  programs.nixvim = {
    plugins.lazy.enable = true;
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.nvim-lspconfig;
        dependencies = with pkgs.vimPlugins; [
          mason-nvim
          mason-lspconfig-nvim
          cmp-nvim-lsp
          cmp-buffer
          cmp-path
          cmp-cmdline
          nvim-cmp
          luasnip
          cmp_luasnip
          fidget-nvim
        ];
        config = builtins.readFile ./lua/lsp.lua;
      }
    ];

    autoCmd = [{
      event = "LspAttach";
      callback = {
        __raw = ''function(e)
            local opts = { buffer = e.buf }
            vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
            vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
            vim.keymap.set("n", "<leader>cws", function() vim.lsp.buf.workspace_symbol() end, opts)
            vim.keymap.set("n", "<leader>cd", function() vim.diagnostic.open_float() end, opts)
            vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, opts)
            vim.keymap.set("n", "<leader>cr", function() vim.lsp.buf.references() end, opts)
            vim.keymap.set("n", "<leader>crn", function() vim.lsp.buf.rename() end, opts)
            vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
            vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
            vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
          end
        '';
      };
    }];
  };
}
