function()
  local cmp = require('cmp')
  local cmp_lsp = require("cmp_nvim_lsp")
  local capabilities = vim.tbl_deep_extend(
        "force",
        {},
        vim.lsp.protocol.make_client_capabilities(),
        cmp_lsp.default_capabilities())

  require("fidget").setup({})

  local cmp_select = { behavior = cmp.SelectBehavior.Select }

  require'lspconfig'.tsserver.setup{}

  cmp.setup({
    snippet = {
      expand = function(args)
        require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
      ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
      ["<C-Space>"] = cmp.mapping.complete(),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp', keyword_length = 1 },
      { name = 'buffer', keyword_length = 2 },
      { name = "copilot", group_index = 2 },
      { name = 'luasnip' }, -- For luasnip users.
    })
  })

  vim.diagnostic.config({
    -- update_in_insert = true,
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
  })
end
