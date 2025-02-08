{ pkgs ? import <nixpkgs> { } }:

pkgs.kbd.overrideAttrs (drv: {
  patches = (drv.patches or []) ++ [
    ./search-paths.patch
  ];
})
