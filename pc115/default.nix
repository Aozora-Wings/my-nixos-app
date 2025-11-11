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

    # X11 相关（即使使用 Wayland，很多应用仍然需要 X11 库）
    xorg.libX11
    xorg.libXext
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libxcb
    xorg.libXau
    xorg.libXdmcp

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
    libsecret
    p11-kit

    # 字体和文本
    freetype
    fontconfig
    harfbuzz
    pango
    cairo
    libpng
    libjpeg
    libtiff
    libwebp

    # 其他必要库
    zlib
    bzip2
    expat
    dbus
    atk
    at-spi2-core
    at-spi2-atk
    cups
    libxkbcommon
    libidn2
    e2fsprogs
    libgpg-error

    # Portal 相关
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
  ];

  # 正确的输入法相关库
  inputMethodLibs = with pkgs; [
    fcitx5
    qt6Packages.fcitx5-configtool
    fcitx5-gtk
    #libsForQt5.fcitx5-qt # Qt5 版本
    # 或者如果需要 Qt6: 
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

      # 创建新的启动脚本，保留原始环境变量
          cat > $out/local/115Browser/115.sh << "EOF"
          #!${pkgs.bash}/bin/bash

          # 保留所有父进程的环境变量（特别是输入法相关）
          # 仅添加必要的浏览器特定配置
          export XDG_CURRENT_DESKTOP=hyprland
          export GTK_USE_PORTAL=1
          export XDG_SESSION_TYPE=wayland
          export QT_QPA_PLATFORM=wayland
          export MOZ_ENABLE_WAYLAND=1
          export NO_AT_BRIDGE=1
          export XMODIFIERS="fcitx5"
          export GTK_IM_MODULE="fcitx5"
          export INPUT_METHOD="fcitx5"
          export QT_IM_MODULE="fcitx5"
          # Vulkan 配置
          export VK_ICD_FILENAMES="/run/current-system/sw/share/vulkan/icd.d/intel_icd.x86_64.json"

          # 库路径配置
          export LD_LIBRARY_PATH="/run/current-system/sw/lib:$LD_LIBRARY_PATH"
    EOF
    echo 'APP_DIR="'$out'/local/115Browser"' >> $out/local/115Browser/115.sh
    cat >> $out/local/115Browser/115.sh << "EOF"
          # 应用目录配置
          APP_NAME=115Browser
          APP_PATH="$APP_DIR/$APP_NAME"

          # 检查程序目录和文件
          if [ ! -d "$APP_DIR" ]; then
              echo "Error: $APP_DIR not found!"
              exit 1
          fi

          if [ ! -f "$APP_PATH" ]; then
              echo "Error: $APP_PATH not found!"
              exit 1
          fi

          if [ ! -x "$APP_PATH" ]; then
              echo "Error: $APP_PATH not executable!"
              exit 1
          fi

          cd "$APP_DIR" || exit 1

          # 处理启动参数
          start_browser() {
              local delay=$1
              local args=$2

              if [ "$delay" -gt 0 ]; then
                  echo "Waiting for $delay seconds before start..."
                  sleep "$delay"
              fi

              if [ -n "$args" ]; then
                  "$APP_PATH" "$args" &
              else
                  "$APP_PATH" &
              fi

              echo "Starting $APP_NAME..."
          }

          # 根据参数决定启动方式
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

          exit 0
    EOF

          # 修复.desktop文件路径
          sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=$out/bin/115.sh|g" $out/share/applications/115Browser.desktop
          sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/local/115Browser/res/115Browser.png|g" $out/share/applications/115Browser.desktop

          # 设置可执行权限
          chmod +x $out/local/115Browser/115.sh
          chmod +x $out/local/115Browser/115Browser

          # 创建二进制链接
          mkdir -p $out/bin
          ln -s $out/local/115Browser/115.sh $out/bin/115.sh

          # 修复ELF文件的依赖路径
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                    --set-rpath "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}:$out/local/115Browser" \
                    $out/local/115Browser/115Browser

          # 使用 makeWrapper 确保环境变量正确传递
          makeWrapper $out/local/115Browser/115Browser $out/bin/115Browser \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (needlib ++ inputMethodLibs)}" \
            --prefix PATH : "${lib.makeBinPath [pkgs.xdg-desktop-portal pkgs.xdg-desktop-portal-gtk]}" \
            --set VK_ICD_FILENAMES "${pkgs.vulkan-loader}/share/vulkan/icd.d/intel_icd.x86_64.json" \
            --set XDG_CURRENT_DESKTOP hyprland \
            --set GTK_USE_PORTAL 1 \
            --set XDG_SESSION_TYPE wayland

          runHook postInstall
  '';
}
