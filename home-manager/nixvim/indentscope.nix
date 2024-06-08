{pkgs, ...}: {
  programs.nixvim = {
    plugins.lazy.enable = true;
    plugins.lazy.plugins = with pkgs.vimPlugins; [
      {
        pkg = mini-indentscope;
      }
    ];
  };
}
