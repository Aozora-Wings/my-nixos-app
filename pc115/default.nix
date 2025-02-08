{ lib,
  stdenv,
  fetchurl,
  fetchzip,
  autoPatchelfHook,
  dotnet-sdk_8,
  pkgs,
  systemd,
  nixUnstable,
  commonLibs,
  ...}: #参数列表

let
  #unstable = import (builtins.fetchTarball "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz") { config = { allowUnfree = true; }; };
  #unstable=https://nixos.org/channels/nixos-unstable
  pname = "115Browser";
  version = "35.3.0.2";
  src = {
    x86_64-linux = fetchurl {
      #url = "https://github.com/ppy/osu/releases/download/${version}/osu.AppImage";
      url = "https://down.115.com/client/115pc/lin/115br_v${version}.deb";
      sha256 = "sha256-R8rn8q637KcXiKFdEI89t4iX248EIkQwzLdlkmmHSJ8=";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "115 Browser for Nixos";
    homepage = "https://115.com/";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
      unfreeRedistributable # osu-framework contains libbass.so in repository
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "115.sh";
    platforms = [ "x86_64-linux" ];
  };

  #passthru.updateScript = ./update-bin.sh;
    runtimeDependencies = map lib.getLib [
  ];
      needlib =  with pkgs; [
    libdrm
    e2fsprogs
    p11-kit
    alsa-lib
    glib
    libglvnd
    libgpg-error
    dbus
    atk
    at-spi2-core
    cups
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXrandr
    mesa
    libxkbcommon
    pango
    cairo
    libidn2
    ];
in
stdenv.mkDerivation {
  #passthru
  inherit pname version src meta ;
    nativeBuildInputs = [
      autoPatchelfHook
      pkgs.dpkg
    # makeBinaryWrapper not support shell wrapper specifically for `NIXOS_OZONE_WL`.
  ];
  #构建时所需要的依赖

    buildInputs = commonLibs ++ needlib;
 #运行时所需要的依赖
    runtimeDependencies = map lib.getLib [
  ];
  #解压缩
unpackPhase = ''
  echo "115 unpackPhase installings...."
  mkdir temp
  dpkg-deb -R $src temp
#  ls -l temp
#  mkdir temp2
#  tar -xJf temp/data.tar.xz -C temp2
#  tar -xf temp2/data.tar -C temp2
  mkdir -p $out/
  cp -rT temp/usr $out
'';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
installPhase = ''
  runHook preInstall

  sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=sh $out/local/115Browser/115.sh|g" $out/share/applications/115Browser.desktop
  sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/local/115Browser/res/115Browser.png|g" $out/share/applications/115Browser.desktop
  sed -i "s|export LD_LIBRARY_PATH=/usr/local/115Browser:$LD_LIBRARY_PATH|export LD_LIBRARY_PATH=$out/local/115Browser:$LD_LIBRARY_PATH|g" $out/local/115Browser/115.sh
  sed -i "s|APP_DIR=/usr/local/115Browser|APP_DIR=$out/local/115Browser|g" $out/local/115Browser/115.sh
  chmod +x $out/local/115Browser/115.sh
  chmod +x $out/local/115Browser/115.115Browser
  mkdir -p $out/bin
  ln -s $out/local/115Browser/115.sh $out/bin/115.sh

  runHook postInstall
'';
}