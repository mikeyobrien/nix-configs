{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;
    plugins.lazy.plugins = [
      {
        pkg = pkgs.vimPlugins.nvim-lspconfig;
      }
      {
        pkg = pkgs.vimPlugins.nvim-jdtls;
        opts = ''
          
        ''
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
