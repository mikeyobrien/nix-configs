{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;
    # Installing the lazy way. Was not working when using only nixvim.plugins
    #plugins.lazy.plugins = with pkgs.vimPlugins; [
    #  nvim-treesitter.withAllGrammars
    #];

    plugins.treesitter = {
      enable = true;
      package = pkgs.unstable.vimPlugins.nvim-treesitter;
      nixGrammars = true;
      nixvimInjections = true;
    };
  };
}
