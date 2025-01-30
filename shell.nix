#!/usr/bin/env nix-shell

let
  unstable = import (fetchTarball https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz) { };
in
{ pkgs ? import <nixpkgs> { } }:

(
  let base = pkgs.appimageTools.defaultFhsEnvArgs; in
  pkgs.buildFHSEnv (base // {
    name = "FHS";
    targetPkgs = pkgs: (with pkgs; [
      gcc glibc zlib
      unstable.aider-chat
      playwright
    ]);
    runScript = "fish";
    extraOutputsToInstall = [ "dev" ];
  })
).env
