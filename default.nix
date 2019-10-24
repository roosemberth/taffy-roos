{ pkgs ? import <nixpkgs> {} }:
let
  drv = pkgs.haskellPackages.callCabal2nix "taffy-roos" ./. {};
in drv.overrideDerivation(self: {
  nativeBuildInputs = self.nativeBuildInputs ++ [ pkgs.wrapGAppsHook ];
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix GDK_PIXBUF_MODULE_FILE : "$(echo ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/*/loaders.cache)"
    )
  '';
})
