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

    # 图形相关库
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
    xorg.libXdamage
    xorg.libXfixes

    # GUI 工具包
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-core
    at-spi2-atk

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
    cups
    libxkbcommon
    expat
  ];

  # 输入法相关库 - 确保包含所有必要的 fcitx5 组件
  inputMethodLibs = with pkgs; [
    fcitx5
    fcitx5-gtk
    kdePackages.fcitx5-qt
    qt6Packages.fcitx5-configtool
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

    # 创建目录结构
    mkdir -p $out/bin
    mkdir -p $out/share/applications

    # 修复 .desktop 文件
    cp $out/share/applications/115Browser.desktop $out/share/applications/115Browser.desktop.backup
    sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=$out/bin/115.sh|g" $out/share/applications/115Browser.desktop
    sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/local/115Browser/res/115Browser.png|g" $out/share/applications/115Browser.desktop

    # 创建主要的启动脚本包装器
    makeWrapper $out/local/115Browser/115Browser $out/bin/115Browser \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:${pkgs.libglvnd}/lib:${pkgs.mesa}/lib:/run/opengl-driver/lib" \
      --prefix PATH : "${lib.makeBinPath [pkgs.xdg-desktop-portal pkgs.xdg-desktop-portal-gtk pkgs.fcitx5]}" \
      --set VK_ICD_FILENAMES "${pkgs.vulkan-loader}/share/vulkan/icd.d/intel_icd.x86_64.json" \
      --set XDG_CURRENT_DESKTOP "KDE" \
      --set GTK_USE_PORTAL 1 \
      --set XDG_SESSION_TYPE "x11" \
      --set QT_QPA_PLATFORM "xcb" \
      --set XMODIFIERS "@im=fcitx5" \
      --set GTK_IM_MODULE "fcitx5" \
      --set QT_IM_MODULE "fcitx5" \
      --set SDL_IM_MODULE "fcitx5" \
      --set GLFW_IM_MODULE "ibus" \
      --set INPUT_METHOD "fcitx5" \
      --set DefaultIMModule "fcitx5" \
      --set LIBGL_DRIVERS_PATH "/run/opengl-driver/lib/dri" \
      --set __EGL_VENDOR_LIBRARY_DIRS "/run/opengl-driver/share/glvnd/egl_vendor.d" \
      --set FONTCONFIG_FILE "${pkgs.fontconfig.out}/etc/fonts/fonts.conf" \
      --set FONTCONFIG_PATH "${pkgs.fontconfig.out}/etc/fonts/"

    cat > $out/local/115Browser/115.sh << "EOF"
    #!${pkgs.bash}/bin/bash

    # 设置输入法环境变量 - 在启动前确保 fcitx5 运行
    export XMODIFIERS="@im=fcitx5"
    export GTK_IM_MODULE="fcitx5"
    export QT_IM_MODULE="fcitx5"
    export SDL_IM_MODULE="fcitx5"
    export INPUT_METHOD="fcitx5"
    export DefaultIMModule="fcitx5"

    # 检查 fcitx5 是否运行，如果没有则尝试启动
    if ! pgrep -x fcitx5 > /dev/null; then
        echo "注意: fcitx5 没有运行，尝试启动..."
        fcitx5 -d > /dev/null 2>&1 &
        sleep 1
    fi

    # 图形环境设置
    export XDG_CURRENT_DESKTOP=KDE
    export GTK_USE_PORTAL=1
    export XDG_SESSION_TYPE=x11
    export QT_QPA_PLATFORM=xcb

    # Vulkan 配置
    export VK_ICD_FILENAMES="${pkgs.vulkan-loader}/share/vulkan/icd.d/intel_icd.x86_64.json"

    # 库路径配置
    export LD_LIBRARY_PATH="${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:${pkgs.libglvnd}/lib:${pkgs.mesa}/lib:/run/opengl-driver/lib:$LD_LIBRARY_PATH"
    EOF
    echo 'APP_DIR="'$out'/local/115Browser"' >> $out/local/115Browser/115.sh
    cat >> $out/local/115Browser/115.sh << "EOF"
    # 处理启动参数
    APP_NAME=115Browser
    APP_PATH="$APP_DIR/$APP_NAME"

    if [ ! -f "$APP_PATH" ]; then
        echo "错误: 找不到 $APP_PATH"
        exit 1
    fi

    cd "$APP_DIR" || exit 1

    start_browser() {
        local delay=$1
        local args=$2

        if [ "$delay" -gt 0 ]; then
            echo "等待 $delay 秒后启动..."
            sleep "$delay"
        fi

        echo "启动 $APP_NAME..."
        if [ -n "$args" ]; then
            exec "$APP_PATH" "$args"
        else
            exec "$APP_PATH"
        fi
    }

    case "$1" in
        "update")
            start_browser 2 "--update"
            ;;
        "")
            start_browser 0
            ;;
        *)
            start_browser 0 "$1"
            ;;
    esac
    EOF
    mkdir -p $out/bin
    ln -s $out/local/115Browser/115.sh $out/bin/115.sh
    chmod +x $out/bin/115.sh
    chmod +x $out/local/115Browser/115Browser

    # 修复ELF文件的依赖路径
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
             --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:${pkgs.libglvnd}/lib:${pkgs.mesa}/lib:/run/opengl-driver/lib" \
             $out/local/115Browser/115Browser

    # 创建必要的符号链接
    ln -sf ${pkgs.libglvnd}/lib/libGL.so.1 $out/local/115Browser/libGL.so.1
    ln -sf ${pkgs.mesa}/lib/libGLX_mesa.so.0 $out/local/115Browser/libGLX_mesa.so.0

    runHook postInstall
  '';

  # 添加修复阶段，确保所有库都被正确链接
  fixupPhase = ''
    runHook preFixup
    
    # 再次运行 autoPatchelf 确保所有依赖都被处理
    autoPatchelf $out/local/115Browser
    
    # 检查并修复可能的库缺失
    for libfile in $out/local/115Browser/*.so*; do
      if [ -f "$libfile" ] && [ ! -L "$libfile" ]; then
        patchelf --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser:${pkgs.libglvnd}/lib:${pkgs.mesa}/lib:/run/opengl-driver/lib" "$libfile" 2>/dev/null || true
      fi
    done
    
    runHook postFixup
  '';
}
