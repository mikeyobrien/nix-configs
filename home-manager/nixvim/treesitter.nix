{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.nvim-treesitter;
        dependencies = with pkgs.vimPlugins; [
          nvim-treesitter-textobjects
        ];
        opts = {
          highlight = {
            enable = true;
          };
          indent = {
            enable = true;
          };
          ensure_installed = [
            "vim"
            "regex"
            "lua"
            "bash"
            "markdown"
            "markdown_inline"
            "javascript"
            "java"
            "json"
            "diff"
            "tsx"
            "typescript"
            "nix"
            "java"
          ];
        };
      }
    ];
  };
}
