{user, ...}: {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
}
