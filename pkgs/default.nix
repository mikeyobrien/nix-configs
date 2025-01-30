pkgs: {
  lgtv = pkgs.callPackage ./lgwebosremote {};
  aider-chat = pkgs.python3Packages.callPackage ./aider-chat {};
}
