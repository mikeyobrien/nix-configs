{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.modules.uvx;
in {
  options.modules.uvx = {
    enable = mkEnableOption "Enable UVX with FHS environment";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Create an FHS environment for UVX
      (pkgs.buildFHSUserEnv {
        name = "uvx-env";
        targetPkgs = pkgs: with pkgs; [
          python3
          python3Packages.pip
          python3Packages.setuptools
          python3Packages.wheel
          stdenv.cc.cc.lib  # For libstdc++
          zlib
          openssl
          # Add other libraries that might be needed
        ];
        profile = ''
          # Set up Python environment
          export PYTHONPATH=$HOME/.local/lib/python3.10/site-packages:$PYTHONPATH
          export PATH=$HOME/.local/bin:$PATH
          
          # Install UVX if not already installed
          if ! command -v uvx &> /dev/null; then
            echo "Installing UVX..."
            pip install --user uvx
          fi
        '';
        runScript = "bash";
      })
      
      # Create a wrapper script for convenience
      (pkgs.writeShellScriptBin "uvx" ''
        exec uvx-env uvx "$@"
      '')
    ];
  };
}
