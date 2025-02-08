{ alsa-lib
, cups
, dpkg
, fetchurl
, gjs
, glib
, gtk3
, lib
, libayatana-appindicator
, libdrm
, libgcrypt
, libkrb5
, mesa # for libgbm
, nss
, xorg
, systemd
, stdenv
, vips
, at-spi2-core
, autoPatchelfHook
, wrapGAppsHook
, makeWrapper
, libpulseaudio
, libglvnd
}:

let
  sources = import ./sources.nix;
  srcs = {
    x86_64-linux = fetchurl {
      url = "https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${sources.version}_${sources.urlhash}_amd64_01.deb";
      hash = sources.amd64_hash;
    };
    aarch64-linux = fetchurl {
      url = "https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_${sources.version}_${sources.urlhash}_arm64_01.deb";
      hash = sources.arm64_hash;
    };
  };
  src = srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "qq";
  version = builtins.toString sources.version + "_" + builtins.toString sources.urlhash;
  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    # makeBinaryWrapper not support shell wrapper specifically for `NIXOS_OZONE_WL`.
    (wrapGAppsHook.override { inherit makeWrapper; })
    dpkg
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cups
    glib
    gtk3
    libdrm
    libgcrypt
    libkrb5
    mesa
    nss
    vips
    xorg.libXdamage
    libpulseaudio
    libglvnd
  ];

  runtimeDependencies = map lib.getLib [
    systemd
  ];
# postInstall = ''

#   wrapProgram $out/bin/qq \
#     --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd ]}
# '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r opt $out/opt
    cp -r usr/share $out/share
    substituteInPlace $out/share/applications/qq.desktop \
      --replace "/opt/QQ/qq" "$out/bin/qq" \
      --replace "/usr/share" "$out/share"
    ln -s $out/opt/QQ/qq $out/bin/qq

    # Remove bundled libraries
    rm -r $out/opt/QQ/resources/app/sharp-lib

    # https://aur.archlinux.org/cgit/aur.git/commit/?h=linuxqq&id=f7644776ee62fa20e5eb30d0b1ba832513c77793
    rm -r $out/opt/QQ/resources/app/libssh2.so.1

    # https://github.com/microcai/gentoo-zh/commit/06ad5e702327adfe5604c276635ae8a373f7d29e
    ln -s ${libayatana-appindicator}/lib/libayatana-appindicator3.so \
      $out/opt/QQ/libappindicator3.so

    ln -s ${libglvnd}/lib/libGL.so.1 \
      $out/opt/QQ/libGL.so.1
    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : "${lib.makeBinPath [ gjs ]}"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
    )
  '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    homepage = "https://im.qq.com/linuxqq/";
    description = "Messaging app";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ fee1-dead ];
  };
}