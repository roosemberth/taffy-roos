{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage ./default.nix {
  pkgs = pkgs // {
    haskellPackages = pkgs.haskellPackages.override {
      overrides = self: super: {
        taffybar = (pkgs.haskell.lib.overrideSrc super.taffybar ({
          version = "3.2.1-git";
          src = ../taffybar;
        })).overrideDerivation(old: {
          propagatedBuildInputs = old.propagatedBuildInputs ++ [ self.xdg-desktop-entry ];
        });
      };
    };
  };
}
