{pkgs, ...}
: {
  programs.nixvim = {
    enable = true;
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.neotest;
        dependencies = [
          pkgs.vimPlugins.plenary-nvim
          pkgs.vimPlugins.nvim-treesitter
          pkgs.vimPlugins.neotest-plenary
          pkgs.vimPlugins.neotest-jest
        ];
        config = ''
          function()
            local neotest = require("neotest")
            neotest.setup({
              adapters = {
                require("neotest-vitest"),
                require("neotest-jest")({
                  jestCommand = "npm test --"
                  jestConfigFile = "custom.jest.config.ts",
                  env = { CI = "true" },
                  cwd = function(path)
                    return vim.fn.getcwd()
                  end,
                }),
              }
            })
          end
        '';
      }
    ];
  };
}
