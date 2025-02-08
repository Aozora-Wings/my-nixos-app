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
  pname = "1panel";
  version = "v1.10.11-lts";
  src = {
    x86_64-linux = fetchurl {
      #url = "https://github.com/ppy/osu/releases/download/${version}/osu.AppImage";
      url = "https://resource.fit2cloud.com/${pname}/package/stable/${version}/release/${pname}-${version}-linux-amd64.tar.gz";
      sha256 = "sha256-sS/de/kVEJuSaPQdlsxNeKhXFbxafRplKEzxPFnwrJg=";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "1panel for Nixos";
    homepage = "https://www.verysync.com/";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "1panel";
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
  mkdir -p $out/usr/1panel/bin/
  mkdir -p $out/share/applications
  mv temp/${pname}-${version}-linux-amd64/1panel $out/usr/1panel/bin/1panel
 rm -rf temp
  '';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
    installPhase = ''
    runHook preInstall
    sed -i 's|/usr/local/bin/1pctl|/run/1panel/bin/1pctl|g' $out/usr/1panel/bin/1panel
'';
}