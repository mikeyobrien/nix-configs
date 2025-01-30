#!/usr/bin/env nix-shell

{ pkgs ? import <nixpkgs> { } }:

(
  let base = pkgs.appimageTools.defaultFhsEnvArgs; in
  pkgs.buildFHSEnv (base // {
    name = "FHS";
    targetPkgs = pkgs: (with pkgs; [
      gcc glibc zlib
      aider-chat
      playwright
    ]);
    runScript = "fish";
    extraOutputsToInstall = [ "dev" ];
  })
).env
