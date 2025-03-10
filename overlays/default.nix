# This file defines overlays
{inputs, ...}: {
  additions = final: _prev: import ../pkgs final.pkgs;

  # this will replace the package referenced at pkg.<package>
  modifications = final: prev: {
    neovim = inputs.neovim-nightly-overlay.packages.${final.system}.default;
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
