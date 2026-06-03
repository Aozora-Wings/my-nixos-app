{ pkgs ? import <nixpkgs> {}
, ...
}:

let
  lib = pkgs.lib;
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
    
    mkdir -p assemblies
    if [ -f "Steam++.dll" ]; then
      mv Steam++.dll assemblies/ 2>/dev/null || true
    fi
    
    mv *.dll assemblies/ 2>/dev/null || true
  '';
  
in
pkgs.buildFHSEnv {
  name = "watt-toolkit";
  
  targetPkgs = pkgs: with pkgs; [
    dotnet-sdk_10
    glibc
    zlib
    openssl
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
    gtk3
    glib
    at-spi2-core
    gdk-pixbuf
    cairo
    pango
    fontconfig.lib
    nss_latest.tools
    lttng-ust
    icu74
    libunwind
    libuuid
    krb5
    curl
    alsa-lib
    pulseaudio
    bash
    coreutils
    findutils
  ];
  
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
    
    export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
    export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
    export PATH="${dotnet-sdk_10}/bin:${pkgs.nss_latest}/bin:$PATH"
    
    export LD_LIBRARY_PATH="${dotnet-sdk_10}/share/dotnet:${dotnet-sdk_10}/share/dotnet/host/fxr:${lib.makeLibraryPath (with pkgs; [ libGL libICE libSM libXcursor libXext libXi libXrandr ])}:$LD_LIBRARY_PATH"
    
    export XDG_DATA_HOME="$HOME/.local/share/WattToolkit"
    mkdir -p "$XDG_DATA_HOME"
    
    APP_DIR="/app"
    
    echo "启动 Watt Toolkit..."
    
    if [ ! -d "$APP_DIR/assemblies" ]; then
      mkdir -p "$APP_DIR/assemblies"
      find "$APP_DIR" -maxdepth 1 -name "*.dll" -exec mv {} "$APP_DIR/assemblies/" \; 2>/dev/null
    fi
    
    if [ -f "$APP_DIR/assemblies/Steam++.dll" ]; then
      exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/assemblies/Steam++.dll" "$@"
    elif [ -f "$APP_DIR/Steam++.dll" ]; then
      exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/Steam++.dll" "$@"
    else
      echo "错误：找不到 Steam++.dll"
      find "$APP_DIR" -name "*.dll" -type f
      exit 1
    fi
  '';
  
  extraBuildCommands = ''
    # 复制应用文件到 /app（不要创建 bin 目录，它已经存在）
    mkdir -p $out/app/assemblies
    cp -r ${unpacked}/* $out/app/
    
    # 确保所有 .dll 文件都在 assemblies 目录中
    if [ -f "$out/app/Steam++.dll" ]; then
      mv $out/app/Steam++.dll $out/app/assemblies/
    fi
    mv $out/app/*.dll $out/app/assemblies/ 2>/dev/null || true
    
    # 创建符号链接到系统库
    mkdir -p $out/app/assemblies/native
    ln -sf ${pkgs.libGL}/lib/libGL.so.1 $out/app/assemblies/ 2>/dev/null || true
    ln -sf ${pkgs.libICE}/lib/libICE.so.6 $out/app/assemblies/ 2>/dev/null || true
    ln -sf ${pkgs.libSM}/lib/libSM.so.6 $out/app/assemblies/ 2>/dev/null || true
    
    # 创建图标目录
    if [ -d $out/app/Icons ]; then
      mkdir -p $out/share/icons/hicolor/128x128/apps
      cp $out/app/Icons/*.png $out/share/icons/hicolor/128x128/apps/ 2>/dev/null || true
    fi
    
    chmod -R +r $out/app/
    
    # 创建 Accelerator 启动器（使用已存在的 bin 目录，不要 mkdir）
    cat > $out/bin/run-accelerator <<'EOF'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$SCRIPT_DIR/.."

if [ -f "$ROOTFS/app/modules/Accelerator/Steam++.Accelerator" ]; then
    ACCELERATOR="$ROOTFS/app/modules/Accelerator/Steam++.Accelerator"
elif [ -f "$ROOTFS/app/Accelerator/Steam++.Accelerator" ]; then
    ACCELERATOR="$ROOTFS/app/Accelerator/Steam++.Accelerator"
else
    echo "错误: 找不到 Accelerator"
    exit 1
fi

export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
export PATH="$DOTNET_ROOT/bin:$PATH"
exec dotnet "$ACCELERATOR" "$@"
EOF
    chmod +x $out/bin/run-accelerator
    ln -sf run-accelerator $out/bin/Steam++.Accelerator
  '';
}