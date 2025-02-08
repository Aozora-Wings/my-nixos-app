{ fetchurl }:

{
  version = "0.0.21";
  src = fetchurl {
    url = "https://dl.discordapp.net/apps/linux/0.0.21/discord-0.0.21.tar.gz";
    sha256 = "18rmw979vg8lxxvagji6sim2s5yyfq91lfabsz1wzbniqfr98ci8";
  };
}
