{ pkgs ? import <nixpkgs> {} }:
pkgs.haskellPackages.callCabal2nix "taffy-roos" ./. {}