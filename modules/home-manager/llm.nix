
{ config, lib, pkgs, unstable, ... }:

with lib;

let
  cfg = config.modules.llm;
  pyWithLlm = unstable.python311.withPackages (ps: with ps; [
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
  options.modules.llm = {
    enable = mkEnableOption "LLM tools and configurations";
  };

  config = mkIf cfg.enable {
    home.packages = [
      llm-with-plugins
    ];
  };
}
