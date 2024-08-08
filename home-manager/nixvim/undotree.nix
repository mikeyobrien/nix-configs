{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.undotree;
      }
    ];
    keymaps = [
      {
        mode = "n";
        key = "<leader>u";
        action = "<cmd>lua vim.cmd.UndotreeToggle<CR>";
      }
    ];
  };
}
