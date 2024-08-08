function()
  root_dir = require("lspconfig.server_configurations.jdtls").default_config.root_dir,

  project_name = function(root_dir)
    return root_dir and vim.fs.basename(root_dir)
  end,

  jdtls_config_dir = function(project_name)
    return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/config"
  end,

  jdtls_workspace_dir = function(project_name)
    return vim.fn.stdpath("cache" .. "/jdtls/" .. project_name .. "/workspace"
  end,

  cmd = {
    vim.fn.exepath("jdtls"),
    vim.fn.exepath("jdtls")
  },
end
