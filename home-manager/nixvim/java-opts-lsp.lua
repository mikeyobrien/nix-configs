function()
  return {
    root_dir = require("lspconfig.server_configurations.jdtls").default_config.root_dir,

    project_name = function(root_dir)
      return root_dir and vim.fs.basename(root_dir)
    end,

    jdtls_config_dir = function(project_name)
      return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/config"
    end,

    jdtls_workspace_dir = function(project_name)
      return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
    end,

    cmd = {
      vim.fn.exepath("jdtls"),
      vim.fn.exepath("jdtls")
    },
    full_cmd = function(opts)
      local fname = vim.api.nvim_buf_get_name(0)
      local root_dir = opts.root_dir(fname)
      local project_name = opts.project_name(root_dir)
      local cmd = vim.deepcopy(opts.cmd)
      if project_name then
        vim.list_extend(cmd, {
          "-configuration",
          opts.jdtls_config_dir(project_name),
          "-data",
          opts.jdtls_workspace_dir(project_name),
        })
      end
      return cmd
    end,
  }
end
