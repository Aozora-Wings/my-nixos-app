{ lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dotnetCorePackages,
  pkgs,
  ... }:

let
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
    mainProgram = "watt-toolkit";
    platforms = [ "x86_64-linux" ];
  };
  
in
stdenv.mkDerivation {
  inherit pname version src meta;
  
  nativeBuildInputs = [
    autoPatchelfHook
    dotnet-sdk_9
    pkgs.makeWrapper
  ];
  
  buildInputs = [
    dotnet-runtime_9
    pkgs.lttng-ust  # 添加这个！！！
    pkgs.icu74
    pkgs.openssl
    pkgs.zlib
    pkgs.fontconfig.lib
    pkgs.nss_latest
    pkgs.xorg.libX11
    pkgs.xorg.libICE
    pkgs.xorg.libSM
  ];
  
  # 添加自动补丁的库搜索路径
  preFixup = ''
    autoPatchelfLibs+=(${pkgs.lttng-ust}/lib)
  '';
  
  unpackPhase = ''
    mkdir temp
    tar -xzf $src -C temp
    mv temp/* .
  '';
  
  installPhase = ''
    runHook preInstall
    
    # 复制所有文件到输出目录
    mkdir -p $out/bin
    cp -r . $out/bin
    
    # 创建启动脚本
    cat > $out/bin/watt-toolkit <<EOF
#!/bin/sh
export DOTNET_ROOT="${dotnet-sdk_9}"
export PATH="${dotnet-sdk_9}/bin:\$PATH"
export LD_LIBRARY_PATH=\
${dotnet-runtime_9}/lib:\
${pkgs.lttng-ust}/lib:\
${pkgs.icu74}/lib:\
${pkgs.openssl}/lib:\
${pkgs.zlib}/lib:\
${pkgs.fontconfig.lib}/lib:\
${pkgs.nss_latest}/lib:\
${pkgs.xorg.libX11}/lib:\
${pkgs.xorg.libICE}/lib:\
${pkgs.xorg.libSM}/lib:\
\$LD_LIBRARY_PATH
    
exec ${dotnet-sdk_9}/bin/dotnet "$out/assemblies/Steam++.dll" "\$@"
EOF
    
    chmod +x $out/bin/watt-toolkit
    
    # 创建桌面文件（如果存在图标）
    if [ -f "$out/Icons/Watt-Toolkit.png" ]; then
      mkdir -p $out/share/applications
      cat > $out/share/applications/watt-toolkit.desktop <<EOF
[Desktop Entry]
Type=Application
Name=WattToolkit
Comment=Steam Tools
Exec=$out/bin/watt-toolkit
Icon=$out/Icons/Watt-Toolkit.png
Categories=Utility;
EOF
      chmod 644 $out/share/applications/watt-toolkit.desktop
    fi
    
    runHook postInstall
  '';
}