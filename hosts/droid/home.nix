{
  user,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [../../home-manager/home.nix];
  editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = true;
  };

  home.activation = {
    copyFont = let
      font_src = "${pkgs.nerdfonts.override {fonts = ["FiraCode"];}}/share/fonts/truetype/NerdFonts/FiraCodeNerdFontMono-Regular.ttf";
      font_dst = "${config.home.homeDirectory}/.termux/font.ttf";
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        ( test ! -e "${font_dst}" || test $(sha1sum "${font_src}"|cut -d' ' -f1 ) != $(sha1sum "${font_dst}" |cut -d' ' -f1)) && $DRY_RUN_CMD install $VERBOSE_ARG -D "${font_src}" "${font_dst}"
      '';
  };
}
