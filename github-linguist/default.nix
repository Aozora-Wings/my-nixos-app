{ nixpkgs ? import <nixpkgs> { } }:

with nixpkgs;

let
  gems = import ./gemset.nix;
in
(import (nixpkgs.path + "/pkgs/development/ruby-modules/with-packages") {
  inherit lib stdenv makeWrapper buildRubyGem buildEnv ruby;
  gemConfig = defaultGemConfig;
}).buildGems ((import (nixpkgs.path + "/pkgs/top-level/ruby-packages.nix")) // gems)
