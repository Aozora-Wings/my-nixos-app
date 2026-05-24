{ lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dotnetCorePackages,
  pkgs,
  ... }:

let
  dotnet-sdk_10 = dotnetCorePackages.sdk_10_0;
  dotnet-runtime_10 = dotnetCorePackages.runtime_10_0;
  
  pname = "WattToolkit";
  version = "3.1.0";
  
  src = fetchurl {
    url = "https://publicinaccess.blob.core.windows.net/file/steam++.tgz";
    sha256 = "sha256-TDze5m1gexcIdRdy+nD89Ecx4E04Sm2TP9UTfJjNGIA=";
  };
  
  # 将 buildInputs 定义在 let 块中，使其在整个作用域中可用
  myBuildInputs = [
    pkgs.lttng-ust
    pkgs.icu74
    pkgs.openssl
    pkgs.zlib
    pkgs.fontconfig.lib
    pkgs.nss_latest
    pkgs.libX11
    pkgs.libICE
    pkgs.libSM
  ];
  
  meta = {
    description = "Steam Tools";
    homepage = "https://steampp.net";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "watt-toolkit";
    platforms = [ "x86_64-linux" ];
  };
  
in
stdenv.mkDerivation {
  inherit pname version src meta;
  
  nativeBuildInputs = [
    autoPatchelfHook
    dotnet-sdk_10
    pkgs.makeWrapper
    pkgs.steam-run  # 添加 steam-run 作为构建依赖
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
    
    # 为应用程序的所有可执行文件和共享库设置 RPATH
    # 包括 ELF 可执行文件、共享库和 .NET 自包含应用程序
    echo "修补 ELF 文件..."
    
    # 1. 修补所有 .so 文件
    find $out/bin -type f -name "*.so" -exec patchelf --add-rpath "${lib.makeLibraryPath myBuildInputs}" {} \; 2>/dev/null || true
    
    # 2. 修补所有 ELF 可执行文件（包括 Steam++.Accelerator）
    find $out/bin -type f -executable -exec sh -c 'file "$1" | grep -q "ELF"' _ {} \; \
      -exec patchelf --add-rpath "${lib.makeLibraryPath myBuildInputs}" {} \; 2>/dev/null || true
    
    # 3. 特别修补 modules/Accelerator/Steam++.Accelerator
    if [ -f "$out/bin/modules/Accelerator/Steam++.Accelerator" ]; then
      echo "修补加速器模块..."
      patchelf --add-rpath "${lib.makeLibraryPath myBuildInputs}" "$out/bin/modules/Accelerator/Steam++.Accelerator" 2>/dev/null || true
      # 设置解释器
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$out/bin/modules/Accelerator/Steam++.Accelerator" 2>/dev/null || true
    fi
    
    # 4. 检查是否是 .NET 自包含应用程序，并设置解释器
    find $out/bin -type f -executable -exec sh -c '
      file "$1" | grep -q "ELF" && {
        # 如果是 ELF 文件，设置正确的解释器
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$1" 2>/dev/null || true
      }
    ' _ {} \;
    
    # 创建基础启动脚本（不使用 steam-run）
    cat > $out/bin/watt-toolkit-base <<'EOF'
#!/bin/sh
export DOTNET_ROOT="@DOTNET_ROOT@"
export PATH="@DOTNET_ROOT@/bin:$PATH"
export LD_LIBRARY_PATH="\
@LIB_LTTNG_UST@/lib:\
@LIB_ICU74@/lib:\
@LIB_OPENSSL@/lib:\
@LIB_ZLIB@/lib:\
@LIB_FONTCONFIG@/lib:\
@LIB_NSS@/lib:\
@LIB_X11@/lib:\
@LIB_ICE@/lib:\
@LIB_SM@/lib:\
''${LD_LIBRARY_PATH:-}"
    
exec "@DOTNET_ROOT@/bin/dotnet" "@APP_DIR@/assemblies/Steam++.dll" "$@"
EOF
    
    # 替换基础脚本中的占位符变量
    substituteInPlace $out/bin/watt-toolkit-base \
      --subst-var-by DOTNET_ROOT "${dotnet-sdk_10}" \
      --subst-var-by APP_DIR "$out/bin" \
      --subst-var-by LIB_LTTNG_UST "${pkgs.lttng-ust}" \
      --subst-var-by LIB_ICU74 "${pkgs.icu74}" \
      --subst-var-by LIB_OPENSSL "${pkgs.openssl}" \
      --subst-var-by LIB_ZLIB "${pkgs.zlib}" \
      --subst-var-by LIB_FONTCONFIG "${pkgs.fontconfig.lib}" \
      --subst-var-by LIB_NSS "${pkgs.nss_latest}" \
      --subst-var-by LIB_X11 "${pkgs.libX11}" \
      --subst-var-by LIB_ICE "${pkgs.libICE}" \
      --subst-var-by LIB_SM "${pkgs.libSM}"
    
    chmod +x $out/bin/watt-toolkit-base
    
    # 创建 steam-run 包装的主脚本
    # 这个脚本会调用基础脚本，但通过 steam-run 运行
    makeWrapper ${pkgs.steam-run}/bin/steam-run $out/bin/watt-toolkit \
      --add-flags "$out/bin/watt-toolkit-base" \
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath myBuildInputs}:$LD_LIBRARY_PATH" \
      --set DOTNET_ROOT "${dotnet-sdk_10}/share/dotnet"
    
    # 可选：创建直接运行的版本（用于对比测试）
    ln -s $out/bin/watt-toolkit-base $out/bin/watt-toolkit-direct
    
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
