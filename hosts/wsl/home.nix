{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    # WSL skips graphical profiles; enable only what is needed.
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  # Focus on CLI tooling suitable for WSL environments.
  modules.core.commonCli.enable = true;

  modules.development = {
    git.enable = true;
    direnv.enable = true;
    uvx.enable = true;
  };

  modules.terminal.tmux = {
    enable = true;
    prefix = lib.mkForce "C-a";
  };

  modules.editors.emacs.enable = true;
}
