{ user, outputs, ... }: {
  imports = [
    ../../home-manager/home.nix
    # Add CLI developer profile for this host
    outputs.homeManagerModules.profiles.cli-developer
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  # Driftwood is a development machine with CLI focus.
  # The cli-developer profile already layers git, direnv, tmux, and neovim.
}
