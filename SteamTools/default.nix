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
export DOTNET_ROOT="${dotnet-sdk_9}"
export PATH="${dotnet-sdk_9}/bin:\$PATH"
export LD_LIBRARY_PATH=\
${dotnet-runtime_9}/lib:\
${pkgs.icu74}/lib:\
${pkgs.openssl}/lib:\
${pkgs.zlib}/lib:\
${pkgs.fontconfig.lib}/lib:\
${pkgs.nss_latest}/lib:\
${pkgs.xorg.libX11}/lib:\
${pkgs.xorg.libICE}/lib:\
${pkgs.xorg.libSM}/lib:\
\$LD_LIBRARY_PATH
    
dotnet "$out/assemblies/Steam++.dll"
EOF
chmod +x $out/bin/WattToolkit.sh
    # 创建桌面文件（如果存在图标）
    if [ -f "$out/Icons/Watt-Toolkit.png" ]; then
      mkdir -p $out/share/applications
      cat > $out/share/applications/WattToolkit.desktop <<EOF
[Desktop Entry]
Type=Application
Name=WattToolkit
Comment=Steam Tools
Exec=$out/bin/WattToolkit.sh
Icon=$out/Icons/Watt-Toolkit.png
Categories=Utility;
EOF
chmod 755 $out/share/applications/WattToolkit.desktop
    fi

    
runHook postInstall
'';
}