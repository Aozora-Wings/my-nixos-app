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
  
  # 将 buildInputs 定义在 let 块中，使其在整个作用域中可用
  myBuildInputs = [
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
  
  # 使用 let 块中定义的 myBuildInputs
  buildInputs = myBuildInputs;
  
  # 设置自动补丁排除列表，避免修补 .NET 运行时的文件
  dontAutoPatchelf = true;
  
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
    
    # 为应用程序文件设置 RPATH
    # 直接使用 lib.makeLibraryPath 和 myBuildInputs
    find $out/bin -type f -executable -name "*.so" -exec patchelf --add-rpath "${lib.makeLibraryPath myBuildInputs}" {} \;
    
    # 创建启动脚本
    cat > $out/bin/watt-toolkit <<'EOF'
#!/bin/sh
export DOTNET_ROOT="${DOTNET_ROOT}"
export PATH="${DOTNET_ROOT}/bin:$PATH"
export LD_LIBRARY_PATH="\
${LIB_LTTNG_UST}/lib:\
${LIB_ICU74}/lib:\
${LIB_OPENSSL}/lib:\
${LIB_ZLIB}/lib:\
${LIB_FONTCONFIG}/lib:\
${LIB_NSS}/lib:\
${LIB_X11}/lib:\
${LIB_ICE}/lib:\
${LIB_SM}/lib:\
''${LD_LIBRARY_PATH:-}"
    
exec "$DOTNET_ROOT/bin/dotnet" "$APP_DIR/assemblies/Steam++.dll" "$@"
EOF
    
    # 替换启动脚本中的占位符变量
    substituteInPlace $out/bin/watt-toolkit \
      --replace '${DOTNET_ROOT}' "${dotnet-sdk_9}" \
      --replace '${APP_DIR}' "$out/bin" \
      --replace '${LIB_LTTNG_UST}' "${pkgs.lttng-ust}" \
      --replace '${LIB_ICU74}' "${pkgs.icu74}" \
      --replace '${LIB_OPENSSL}' "${pkgs.openssl}" \
      --replace '${LIB_ZLIB}' "${pkgs.zlib}" \
      --replace '${LIB_FONTCONFIG}' "${pkgs.fontconfig.lib}" \
      --replace '${LIB_NSS}' "${pkgs.nss_latest}" \
      --replace '${LIB_X11}' "${pkgs.xorg.libX11}" \
      --replace '${LIB_ICE}' "${pkgs.xorg.libICE}" \
      --replace '${LIB_SM}' "${pkgs.xorg.libSM}"
    
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