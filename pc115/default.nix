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
    # 添加 curl 库 - 修复 libcurl.so.4.6.0 缺失
    curl

    # 添加 Intel 媒体驱动
    intel-media-driver
    intel-vaapi-driver

    libvdpau

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
  
    # 图形环境
    export QT_QPA_PLATFORM=xcb
    export GDK_BACKEND=x11
  
    # 禁用有问题的组件
    export GTK_USE_PORTAL=0
    export QTWEBENGINE_DISABLE_SANDBOX=1
    export ELECTRON_DISABLE_SANDBOX=1
    export NO_AT_BRIDGE=1
  
    # 修复 VA-API 驱动
    export LIBVA_DRIVER_NAME=iHD
    export LIBVA_DRIVERS_PATH="/run/opengl-driver/lib/dri"
    EOF

    echo 'APP_DIR="'$out'/local/115Browser"' >> $out/local/115Browser/115.sh

    cat >> $out/local/115Browser/115.sh << "EOF"
    APP_NAME=115Browser
    APP_PATH="$APP_DIR/$APP_NAME"
  
    # 设置库路径 - 包含 curl 库
    export LD_LIBRARY_PATH="$APP_DIR:${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:/run/opengl-driver/lib"
  
    # 修复 curl 库问题 - 创建必要的符号链接
    if [ -f "${pkgs.curl.out}/lib/libcurl.so.4" ]; then
      ln -sf "${pkgs.curl.out}/lib/libcurl.so.4" "$APP_DIR/libcurl.so.4.6.0"
    fi
  
    cd "$APP_DIR" || exit 1
    exec "$APP_PATH" "$@"
    EOF

    # 修复 .desktop 文件
    sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=$out/bin/115.sh|g" $out/share/applications/115Browser.desktop
    sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/local/115Browser/res/115Browser.png|g" $out/share/applications/115Browser.desktop

    chmod +x $out/local/115Browser/115.sh
    chmod +x $out/local/115Browser/115Browser

    # 创建二进制链接
    mkdir -p $out/bin
    ln -s $out/local/115Browser/115.sh $out/bin/115.sh

    # 修复二进制依赖
    echo "Patching binary dependencies..."
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/local/115Browser/115Browser
    patchelf --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:/run/opengl-driver/lib" $out/local/115Browser/115Browser
  
    # 修复所有 ELF 文件
    find $out/local/115Browser -type f -executable -exec file {} \; | grep -i elf | cut -d: -f1 | while read file; do
      if patchelf --print-interpreter "$file" 2>/dev/null; then
        echo "Patching $file"
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
        patchelf --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:/run/opengl-driver/lib" "$file" || true
      fi
    done

    # 创建 curl 符号链接
    ln -sf ${pkgs.curl.out}/lib/libcurl.so.4 $out/local/115Browser/libcurl.so.4.6.0

    runHook postInstall
  '';
}
