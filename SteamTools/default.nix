{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;  # 添加这一行
  dotnet-sdk_10 = pkgs.dotnetCorePackages.sdk_10_0;
  
  src = pkgs.fetchurl {
    url = "https://publicinaccess.blob.core.windows.net/file/Steam++.tgz";
    sha256 = "sha256-bEiiYsBO4iBoqW0x+oXriRof30NqwDmUlurC+t3xQjw=";
  };
  
  unpacked = pkgs.runCommand "steam++-unpacked" {} ''
    mkdir -p $out
    cd $out
    tar -xzf ${src}
    if [ -d "Steam++" ]; then
      mv Steam++/* ./
      rmdir Steam++
    fi
    
    # 确保 assemblies 目录存在
    mkdir -p assemblies
    if [ -f "Steam++.dll" ]; then
      mv Steam++.dll assemblies/ 2>/dev/null || true
    fi
    
    # 移动其他可能的 DLL 文件
    mv *.dll assemblies/ 2>/dev/null || true
  '';
  
in
pkgs.buildFHSEnv {
  name = "watt-toolkit";
  
  targetPkgs = pkgs: with pkgs; [
    # .NET 运行时
    dotnet-sdk_10
    
    # 核心系统库
    glibc
    zlib
    openssl
    
    # X11 相关（从缺失列表看很重要）
    libGL
    libICE
    libSM
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    libXrender
    libXfixes
    libXdamage
    libXcomposite
    libxkbcommon
    
    # GUI 相关
    gtk3
    glib
    at-spi2-core
    gdk-pixbuf
    cairo
    pango
    
    # 系统库
    fontconfig.lib
    nss_latest.tools
    lttng-ust
    icu74
    libunwind
    libuuid
    krb5
    curl
    
    # 音频相关（如果需要）
    alsa-lib
    pulseaudio
    
    # 其他可能需要的
    bash
    coreutils
    findutils
  ];
  
  # 多架构支持（32位库，某些游戏可能需要）
  multiPkgs = pkgs: with pkgs.pkgsi686Linux; [
    glibc
    libGL
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
  ];
  
  runScript = pkgs.writeShellScript "run-watt-toolkit" ''
    #!/bin/sh
    set -e
    
    # 设置 .NET 环境
    export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
    export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
    export PATH="${dotnet-sdk_10}/bin:${pkgs.nss_latest}/bin:$PATH"
    
    # 设置库路径（包括所有可能需要的路径）
    export LD_LIBRARY_PATH="${dotnet-sdk_10}/share/dotnet:${dotnet-sdk_10}/share/dotnet/host/fxr:${lib.makeLibraryPath (with pkgs; [ libGL libICE libSM libXcursor libXext libXi libXrandr ])}:$LD_LIBRARY_PATH"
    
    # 设置数据目录
    export XDG_DATA_HOME="$HOME/.local/share/WattToolkit"
    mkdir -p "$XDG_DATA_HOME"
    
    # 应用目录
    APP_DIR="/app"
    
    echo "启动 Watt Toolkit..."
    echo "DOTNET_ROOT: $DOTNET_ROOT"
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    
    # 确保 assemblies 目录存在
    if [ ! -d "$APP_DIR/assemblies" ]; then
      mkdir -p "$APP_DIR/assemblies"
      # 移动可能存在的 DLL 文件
      find "$APP_DIR" -maxdepth 1 -name "*.dll" -exec mv {} "$APP_DIR/assemblies/" \;
    fi
    
    # 运行程序
    if [ -f "$APP_DIR/assemblies/Steam++.dll" ]; then
      exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/assemblies/Steam++.dll" "$@"
    elif [ -f "$APP_DIR/Steam++.dll" ]; then
      exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/Steam++.dll" "$@"
    else
      echo "错误：找不到 Steam++.dll"
      echo "查找所有 .dll 文件："
      find "$APP_DIR" -name "*.dll" -type f
      exit 1
    fi
  '';
  
  extraBuildCommands = ''
    # 复制应用文件到 /app
    mkdir -p $out/app/assemblies
    cp -r ${unpacked}/* $out/app/
    
    # 确保所有 .dll 文件都在 assemblies 目录中
    if [ -f "$out/app/Steam++.dll" ]; then
      mv $out/app/Steam++.dll $out/app/assemblies/
    fi
    mv $out/app/*.dll $out/app/assemblies/ 2>/dev/null || true
    
    # 创建符号链接到系统库（如果需要）
    mkdir -p $out/app/assemblies/native
    ln -sf ${pkgs.libGL}/lib/libGL.so.1 $out/app/assemblies/ 2>/dev/null || true
    ln -sf ${pkgs.libICE}/lib/libICE.so.6 $out/app/assemblies/ 2>/dev/null || true
    ln -sf ${pkgs.libSM}/lib/libSM.so.6 $out/app/assemblies/ 2>/dev/null || true
    
    # 创建图标目录
    if [ -d $out/app/Icons ]; then
      mkdir -p $out/share/icons/hicolor/128x128/apps
      cp $out/app/Icons/*.png $out/share/icons/hicolor/128x128/apps/ 2>/dev/null || true
    fi
    
    # 设置权限
    chmod -R +r $out/app/
  '';
}