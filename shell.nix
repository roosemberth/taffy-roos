{ pkgs ? import <nixpkgs> {} }:
let
  all-hies = import (fetchTarball "https://github.com/infinisil/all-hies/tarball/master") {};
  hie = all-hies.latest;
  project = pkgs.callPackage ./default.nix {};
in pkgs.mkShell {
  inputsFrom = [ project.env ];
  buildInputs = [ hie ];
}
