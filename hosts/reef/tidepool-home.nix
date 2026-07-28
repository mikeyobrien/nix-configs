{
  user,
  config,
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

  modules.development.uv.enable = true;
  modules.development.uvx.enable = true;
  modules.development.languages.enableNodejs = false;
  llm-tools.enable = true;

  home.sessionPath = ["$HOME/.npm-global/bin"];

  home.packages = with pkgs; [nodejs_22 google-chrome python3];

  # OpenClaw is managed outside Nix (npm + OpenClaw CLI).
}
