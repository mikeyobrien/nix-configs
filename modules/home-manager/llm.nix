{ config, lib, pkgs, ... }:
let
  cfg = config.llm-tools;
  pyWithLlm = pkgs.unstable.python313.withPackages (ps: with ps; [
    llm
    llm-ollama
  ]);
  llm-with-plugins = (
    pkgs.writeShellScriptBin "llm" ''
      exec ${pyWithLlm}/bin/llm "$@"
    ''
  );
in
{
  options.llm-tools = {
    enable = lib.mkEnableOption "LLM tools and configurations";
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      llm-with-plugins
    ];
  };
}
