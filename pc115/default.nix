#pc115/default.nix
{ lib
, stdenv
, fetchurl
, fetchzip
, autoPatchelfHook
, dotnet-sdk_8
, pkgs
, systemd
, commonLibs
, makeWrapper
, intel-compute-runtime
, ...
}:

let
  pname = "115Browser";
  version = "36.0.0";
  src = {
    x86_64-linux = fetchurl {
      url = "https://down.115.com/client/115pc/lin/115br_v${version}.deb";
      sha256 = "sha256-E5+0421/SPHheTF+WtK9ixKHnnHTxP+Z2iaGVmG0/Eg=";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "115 Browser for Nixos";
    homepage = "https://115.com/";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
      unfreeRedistributable
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "115.sh";
    platforms = [ "x86_64-linux" ];
  };

  needlib = with pkgs; [
    # 基本系统库
    glibc
    glib
    gcc-unwrapped.lib

    # 图形相关库 - 修复 libGL 依赖
    mesa
    libglvnd
    libGL
    libGLU
    vulkan-loader
    vulkan-validation-layers

    # X11 相关
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libxcb

    # 添加缺失的库
    xorg.libXdamage # 缺失的 libXdamage.so.1
    pango # 缺失的 libpango-1.0.so.0
    cairo # 缺失的 libcairo.so.2

    # 多媒体和音频
    alsa-lib
    libpulseaudio
    libdrm
    libva
    ffmpeg

    # 网络和安全
    nss
    nspr
    openssl

    # 字体和文本
    freetype
    fontconfig
    harfbuzz

    # 其他必要库
    zlib
    dbus
    atk
    at-spi2-core
    at-spi2-atk
    cups
    libxkbcommon
  ];

  # 正确的输入法相关库
  inputMethodLibs = with pkgs; [
    fcitx5
    qt6Packages.fcitx5-configtool
    fcitx5-gtk
    kdePackages.fcitx5-qt
  ];

in
stdenv.mkDerivation {
  inherit pname version src meta;

  nativeBuildInputs = [
    intel-compute-runtime
    autoPatchelfHook
    makeWrapper
    pkgs.dpkg
  ];

  buildInputs = commonLibs ++ needlib ++ inputMethodLibs;

  unpackPhase = ''
    echo "115 unpackPhase installing...."
    mkdir temp
    dpkg-deb -R $src temp
    mkdir -p $out/
    cp -rT temp/usr $out
  '';

  installPhase = ''
    runHook preInstall

    # 创建新的启动脚本
    cat > $out/local/115Browser/115.sh << "EOF"
    #!${pkgs.bash}/bin/bash

    # 输入法环境变量
    export XMODIFIERS="@im=fcitx5"
    export GTK_IM_MODULE="fcitx5"
    export QT_IM_MODULE="fcitx5"
    export INPUT_METHOD="fcitx5"
  
    # 图形和桌面环境
    export XDG_CURRENT_DESKTOP=KDE
    export QT_QPA_PLATFORM=xcb
    export DISPLAY=":0"
  
    # 修复 portal 和 DBus 问题
    export GTK_USE_PORTAL=0
    export NO_AT_BRIDGE=1
  
    # 修复 Intel VA-API 驱动问题
    export LIBVA_DRIVER_NAME=iHD
    EOF

    echo 'APP_DIR="'$out'/local/115Browser"' >> $out/local/115Browser/115.sh

    cat >> $out/local/115Browser/115.sh << "EOF"
    APP_NAME=115Browser
    APP_PATH="$APP_DIR/$APP_NAME"
  
    # 设置库路径 - 修复所有依赖
    export LD_LIBRARY_PATH="$APP_DIR:${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:/run/opengl-driver/lib:$LD_LIBRARY_PATH"
  
    # 设置 VA-API 驱动路径
    export LIBVA_DRIVERS_PATH="/run/opengl-driver/lib/dri"
  
    cd "$APP_DIR" || exit 1
    exec "$APP_PATH" "$@"
    EOF

    cat > $out/local/115Browser/115-debug.sh << "EOF"
    #!${pkgs.bash}/bin/bash
    # 调试版本 - 显示详细错误

    export XMODIFIERS="@im=fcitx5"
    export GTK_IM_MODULE="fcitx5" 
    export QT_IM_MODULE="fcitx5"
    export GTK_USE_PORTAL=0
    export QT_QPA_PLATFORM=xcb
    EOF

    echo 'APP_DIR="'$out'/local/115Browser"' >> $out/local/115Browser/115-debug.sh

    cat >> $out/local/115Browser/115-debug.sh << "EOF"

    APP_PATH="$APP_DIR/115Browser"

    export LD_LIBRARY_PATH="$APP_DIR:${lib.makeLibraryPath needlib}:/run/opengl-driver/lib"

    echo "=== 开始调试 115Browser ==="
    echo "APP_PATH: $APP_PATH"
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo "当前环境变量:"
    env | grep -E "(XDG|QT|GTK|DISPLAY|WAYLAND)"

    # 检查文件是否存在
    if [ ! -f "$APP_PATH" ]; then
      echo "错误: 可执行文件不存在: $APP_PATH"
      exit 1
    fi

    # 检查依赖
    echo "=== 检查依赖 ==="
    ldd "$APP_PATH" | grep -E "not found|=>"

    # 使用 strace 跟踪
    echo "=== 开始 strace 跟踪 ==="
    ${pkgs.strace}/bin/strace -f -s 1000 -o /tmp/115browser-strace.log "$APP_PATH" "$@"

    echo "=== 程序退出，strace 日志保存在: /tmp/115browser-strace.log ==="
    EOF
  
    # 修复 .desktop 文件
    sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=$out/bin/115.sh|g" $out/share/applications/115Browser.desktop
    sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/local/115Browser/res/115Browser.png|g" $out/share/applications/115Browser.desktop

    chmod +x $out/local/115Browser/115.sh
    chmod +x $out/local/115Browser/115Browser

    # 创建二进制链接
    mkdir -p $out/bin
    chmod +x $out/local/115Browser/115-debug.sh
    ln -s $out/local/115Browser/115-debug.sh $out/bin/115-debug.sh
    ln -s $out/local/115Browser/115.sh $out/bin/115.sh

    # 强制修复二进制文件的库依赖
    echo "Patching binary dependencies..."
  
    # 首先修复解释器
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/local/115Browser/115Browser
  
    # 然后修复 RUNPATH，确保包含所有必要的库路径
    patchelf --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:/run/opengl-driver/lib" $out/local/115Browser/115Browser
  
    # 如果有其他可执行文件，也修复它们
    find $out/local/115Browser -type f -executable -exec file {} \; | grep -i elf | cut -d: -f1 | while read file; do
      if patchelf --print-interpreter "$file" 2>/dev/null; then
        echo "Patching $file"
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
        patchelf --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:/run/opengl-driver/lib" "$file" || true
      fi
    done

    # 创建必要的符号链接
    ln -sf ${pkgs.libglvnd}/lib/libGL.so.1 $out/local/115Browser/libGL.so.1
    ln -sf ${pkgs.libglvnd}/lib/libGLESv2.so.2 $out/local/115Browser/libGLESv2.so.2

    runHook postInstall
  '';
}
