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
  pname = "verysync";
  version = "2.17.0";
  src = {
    x86_64-linux = fetchurl {
      #url = "https://github.com/ppy/osu/releases/download/${version}/osu.AppImage";
      url = "https://dl-cn.verysync.com/releases/v2.17.0/verysync-linux-amd64-v2.17.0.tar.gz";
      sha256 = "sha256-zNHGTm87uWpxhwtogbOR3EsC+SkYDyh0hW3+WI2iHxQ=";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "verysync for Nixos";
    homepage = "https://www.verysync.com/";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "verysync";
    platforms = [ "x86_64-linux" ];
  };

  #passthru.updateScript = ./update-bin.sh;
    runtimeDependencies = map lib.getLib [
  ];
      needlib =  with pkgs; [
#        libdrm
#        e2fsprogs
#        p11-kit
#        alsa-lib
#        glib
#        libglvnd
#        libgpg-error
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
    mkdir temp
    tar -xf $src -C temp
  mkdir -p $out/usr/bin/
  mkdir -p $out/share/applications
  mv temp/${pname}-linux-amd64-v${version}/verysync $out/usr/bin/verysync
 rm -rf temp
  '';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
    installPhase = ''
    runHook preInstall
cat > $out/share/applications/verysync.desktop <<EOF
[Desktop Entry]
Comment=verysync
Comment[zh_CN]=微力同步
Exec=$out/usr/bin/verysync
Name=verysync
Name[zh_CN]=微力同步
Type=Application
Terminal=false
Categories=Network
EOF
runHook postInstall
'';
}