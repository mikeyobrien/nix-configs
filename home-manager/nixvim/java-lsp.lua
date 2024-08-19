function(_, opts)
  local bundles = {}
  local cmp_lsp = require("cmp_nvim_lsp")


  local function attach_jdtls()
    local fname = vim.api.nvim_buf_get_name(0)
    local config = {
      cmd = opts.full_cmd(opts),
      root_dir = opts.root_dir(fname),
      init_options = {
        bundles = bundles,
      },
      settings = opts.settings,
      capabilities = cmp_lsp.default_capabilities(),
    }

    require("jdtls").start_or_attach(config)
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "java" },
    callback = attach_jdtls,
  })

  attach_jdtls()
end
