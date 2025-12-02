{ lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dotnetCorePackages,  # 添加这个参数
  pkgs,
  ... }:

let
  # 使用 .NET 9
  dotnet-sdk_9 = dotnetCorePackages.sdk_9_0;
  dotnet-runtime_9 = dotnetCorePackages.runtime_9_0;
  
  pname = "WattToolkit";
  version = "3.0.0-rc.16";
  
  src = fetchurl {
    url = "https://github.com/BeyondDimension/SteamTools/releases/download/${version}/Steam++_v${version}_linux_x64.tgz";
    sha256 = "0chx4x01zvdlq5mn2skym4q0rllh5fmcr6cknchqqg863y13yjcr";
  };
  
  meta = {
    description = "Steam Tools";
    homepage = "https://steampp.net";
    license = with lib.licenses; [ mit cc-by-nc-40 ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "WattToolkit.sh";
    platforms = [ "x86_64-linux" ];
  };
  
in
stdenv.mkDerivation {
  inherit pname version src meta;
  
  nativeBuildInputs = [
    autoPatchelfHook
    dotnet-sdk_9        # 改为 .NET 9
    pkgs.makeWrapper
  ];
  
  buildInputs = [
    dotnet-runtime_9    # 改为 .NET 9
    pkgs.icu74
    pkgs.openssl
    pkgs.zlib
    pkgs.fontconfig.lib
    pkgs.nss_latest
    pkgs.xorg.libX11
    pkgs.xorg.libICE
    pkgs.xorg.libSM
  ];
  
  #解压缩
    unpackPhase = ''
    echo "Watt Toolkit unpackPhase installings...."
    mkdir temp
    tar -xzf $src -C temp
    mv temp/* .
  '';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
  dontPatchELF = true;
  dontStrip = true;
    installPhase = ''
    runHook preInstall
    echo "Watt Toolkit installPhase installings...."
    mkdir -p $out/bin
    cp -r . $out/bin
    
    # 创建启动脚本
    cat > $out/bin/WattToolkit.sh <<EOF
#!/bin/sh
unset SSL_DIR
echo 'exporting sh_local'
export sh_local=/bin/sh
echo $sh_local
export PATH=${pkgs.nss_latest}:$PATH
export LD_LIBRARY_PATH=${pkgs.dotnet-runtime_9}/:${dotnet-sdk_9}/sdk:${pkgs.gcc.cc.lib}/lib:${libX11}/lib:${libice}/lib:${libsm}/lib:${fontconfig}/lib:$out/bin/native/linux-x64/:$LD_LIBRARY_PATH
export DOTNET_ROOT="${dotnet-sdk_9}"
#getcap /run/wrappers/bin/dotnet
dotnet "$out/bin/assemblies/Steam++.dll"
EOF
chmod +x $out/bin/WattToolkit.sh
wrapProgram $out/bin/WattToolkit.sh \
    --prefix PATH : ${dotnet-sdk_9}/sdk:${pkgs.dotnet-runtime_9}/bin:${pkgs.nss.tools}/bin:${pkgs.libcap}/bin
    chmod 755 $out/bin/WattToolkit.sh
    chmod -R 755 $out/bin/assemblies/
    mkdir -p $out/share/applications
    echo "create desktop file"
    cat > $out/share/applications/WattToolkit.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=$out/bin/WattToolkit.sh
Name=WattToolkit
Icon=$out/bin/Icons/Watt-Toolkit.png
EOF

    chmod 755 $out/share/applications/WattToolkit.desktop
runHook postInstall
'';
}