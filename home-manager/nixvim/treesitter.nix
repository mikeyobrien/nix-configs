{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;

    # Installing the lazy way. Was not working when using nixvim.plugins
    plugins.lazy.plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
    ];
  };
}
