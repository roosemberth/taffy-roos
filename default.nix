{ pkgs ? import <nixpkgs> {} }:
let
  haskellPackages = pkgs.haskellPackages.override { 
    overrides = self: super: {
      taffybar = pkgs.haskell.lib.appendPatch super.taffybar
        ./0001-MPRIS2-Add-fallback-mechanism-when-the-default-icon-.patch;
    };
  };
  drv = haskellPackages.callCabal2nix "taffy-roos" ./. {};
in drv.overrideDerivation(self: {
  nativeBuildInputs = self.nativeBuildInputs ++ [ pkgs.wrapGAppsHook ];
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix GDK_PIXBUF_MODULE_FILE : "$(echo ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/*/loaders.cache)"
    )
  '';
})
