{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    # WSL doesn't use profiles - we manually add what we need
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  
  # WSL gets minimal base (essential packages + fish shell)
  # Now we add only what makes sense for WSL:
  
  # Common CLI tools for development
  modules.core.commonCli.enable = true;
  
  # Development essentials
  modules.development = {
    git.enable = true;
    direnv.enable = true;
    uvx.enable = true;
  };
  
  # Terminal multiplexer (no GUI terminal needed)
  modules.terminal.tmux = {
    enable = true;
    prefix = lib.mkForce "C-a";
  };
  
  # Editors
  modules.editors.emacs.enable = true;
  
  # Nixvim configuration
  modules.editors.nixvim = {
    enable = false;
    lazyPlugins.copilot.enable = true;
  };
}
