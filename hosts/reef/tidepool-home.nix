{
  user,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/profiles/cli-developer.nix
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  modules.development.uvx.enable = true;
  llm-tools.enable = true;

  home.packages = with pkgs; [nodejs];
}
