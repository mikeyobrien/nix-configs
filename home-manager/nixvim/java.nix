{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.nvim-lspconfig;
        opts = {
          servers = {
            jdtls = {};
          };
          setup = {
            jdtls.__raw = ''function() return true end,'';
          };
        };
      }
      {
        pkg = pkgs.vimPlugins.nvim-jdtls;
        dependencies = with pkgs.vimPlugins; [
          cmp-nvim-lsp
        ];
        opts = {
          root_dir.__raw = ''require("lspconfig.server_configurations.jdtls").default_config.root_dir'';
          project_name.__raw = ''function(project_name)
              return root_dir and vim.fs.basename(root_dir)
            end'';
          jdtls_config_dir = ''function(project_name)
              return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/config"
            end'';
          jdtls_workspace_dir.__raw = ''function(project_name)
            return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
          end'';
          cmd.__raw =  ''{
            vim.fn.exepath("jdtls"),
          }'';
          full_cmd = ''function(opts)
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
          end'';
        };
        config = builtins.readFile ./java-lsp.lua;
      }
    ];
  };

  # install lombok
  # install java-debug-adapter and java-test
  home.packages = with pkgs; [
    lombok
    vscode-extensions.vscjava.vscode-java-debug
    vscode-extensions.vscjava.vscode-java-test
  ];
}
