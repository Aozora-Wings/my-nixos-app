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
    pkgs.lttng-ust
    pkgs.icu74
    pkgs.openssl
    pkgs.zlib
    pkgs.fontconfig.lib
    pkgs.nss_latest
    pkgs.xorg.libX11
    pkgs.xorg.libICE
    pkgs.xorg.libSM
  ];
  
  # 设置自动补丁排除列表，避免修补 .NET 运行时的文件
  dontAutoPatchelf = true;
  
  unpackPhase = ''
    mkdir -p $out
    tar -xzf $src -C $out
  '';
  
  # 手动设置 run-time dependencies
  installPhase = ''
    runHook preInstall
    
    # 复制所有文件到输出目录
    mkdir -p $out/bin
    cp -r . $out/bin
    
    # 为应用程序文件设置 RPATH
    find $out/bin -type f -executable -name "*.so" -exec patchelf --add-rpath "${lib.makeLibraryPath buildInputs}" {} \;
    
    # 创建启动脚本 - 使用更简单的方法
    cat > $out/bin/watt-toolkit <<'EOF'
#!/bin/sh
export DOTNET_ROOT="${dotnet-sdk_9}"
export PATH="${dotnet-sdk_9}/bin:$PATH"
export LD_LIBRARY_PATH="\
${pkgs.lttng-ust}/lib:\
${pkgs.icu74}/lib:\
${pkgs.openssl}/lib:\
${pkgs.zlib}/lib:\
${pkgs.fontconfig.lib}/lib:\
${pkgs.nss_latest}/lib:\
${pkgs.xorg.libX11}/lib:\
${pkgs.xorg.libICE}/lib:\
${pkgs.xorg.libSM}/lib:\
''${LD_LIBRARY_PATH:-}"
    
exec "${dotnet-sdk_9}/bin/dotnet" "$out/bin/assemblies/Steam++.dll" "$@"
EOF
    
    # 替换启动脚本中的变量
    substituteInPlace $out/bin/watt-toolkit \
      --replace '${dotnet-sdk_9}' "${dotnet-sdk_9}" \
      --replace '$out' "$out"
    
    chmod +x $out/bin/watt-toolkit
    
    # 创建桌面文件（如果存在图标）
    if [ -f "$out/bin/Icons/Watt-Toolkit.png" ]; then
      mkdir -p $out/share/applications
      cat > $out/share/applications/watt-toolkit.desktop <<EOF
[Desktop Entry]
Type=Application
Name=WattToolkit
Comment=Steam Tools
Exec=$out/bin/watt-toolkit
Icon=$out/bin/Icons/Watt-Toolkit.png
Categories=Utility;
EOF
      chmod 644 $out/share/applications/watt-toolkit.desktop
    fi
    
    runHook postInstall
  '';
}