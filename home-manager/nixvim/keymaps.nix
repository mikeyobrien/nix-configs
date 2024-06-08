{ ... }: {
  programs.nixvim = {
    keymaps = [
      {
        key = "<C-d>";
        action = "<C-d>zz";
      }
      {
        key = "<C-u>";
        action = "<C-u>zz";
      }
      {
        mode = "n";
        key = "<leader>g";
        action = "<cmd>help<CR>";
      }
      {
        mode = "n";
        key = "<leader>pv";
        action = "<cmd>lua vim.cmd.Ex()<CR>";
      }
      {
        mode = "n";
        key = "<leader>ce";
        action = "<cmd>lua vim.diagnostic.setqflist()<CR>";
      }
    ];
  };
}
