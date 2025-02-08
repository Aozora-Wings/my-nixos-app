#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnugrep
set -eou pipefail;
url=$(curl -sI "https://discordapp.com/api/download/stable?platform=linux&format=tar.gz" | grep -oP 'location: \K\S+')
version=${url##https://dl*.discordapp.net/apps/linux/}
version=${version%%/*.tar.gz}
oldver=$(sed -ne 's/.*version = "\([^"]*\)".*/\1/p' override.nix)
if [[ ! "$oldver" ]] || [[ ! "$version" ]] || [[ "$oldver" != "$version" ]]; then
    echo "{ fetchurl }:

{
  version = \"$version\";
  src = fetchurl {
    url = \"$url\";
    sha256 = \"$(nix-prefetch-url $url)\";
  };
}" >override.nix
fi
