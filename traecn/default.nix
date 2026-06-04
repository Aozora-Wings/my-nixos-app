{ pkgs ? import <nixpkgs> {}
, ...
}:
let
  lib = pkgs.lib;
  
  src = pkgs.fetchurl {
    url = "https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/2.3.33255/linux/Trae_CN-linux-x64.deb";
    sha256 = "sha256-VX56wn7cyafU+x6ouBfaEnIaccYzy3HmgxSIHxtDNDM=";
  };
  
  unpacked = pkgs.runCommand "traecn-unpacked" {
    nativeBuildInputs = [ pkgs.dpkg pkgs.binutils ];
  } ''
    mkdir -p $out
    cd $out
    
    # 手动解压 .deb 文件，避免 setuid 权限问题
    ar x ${src}
    
    # 解压 data.tar.xz，忽略权限
    tar -xf data.tar.xz --no-same-permissions --no-same-owner
    
    # 强制移除 chrome-sandbox 的 setuid 位
    if [ -f ./usr/share/trae-cn/chrome-sandbox ]; then
      chmod 0755 ./usr/share/trae-cn/chrome-sandbox
    fi
    
    # 确保所有文件都有正确的权限
    find . -type f -exec chmod 0644 {} \;
    find . -type d -exec chmod 0755 {} \;
    
    # 恢复可执行文件的权限
    chmod +x ./usr/share/trae-cn/trae-cn 2>/dev/null || true
    chmod +x ./usr/share/trae-cn/chrome_crashpad_handler 2>/dev/null || true
    find ./usr/share/trae-cn -name "*.so" -exec chmod 0755 {} \; 2>/dev/null || true
    find ./usr/share/trae-cn/resources/app -name "*.node" -exec chmod 0755 {} \; 2>/dev/null || true
    find ./usr/share/trae-cn/resources/app -name "*.so" -exec chmod 0755 {} \; 2>/dev/null || true
    
    # 移动内容到根目录，避免路径过深
    mv usr/* ./
    rm -rf usr
    
    # 创建必要的符号链接
    mkdir -p lib
    ln -sf share/trae-cn/lib*.so lib/ 2>/dev/null || true
  '';
  
  # 创建 FHS 环境
  fhsEnv = pkgs.buildFHSEnv {
    name = "trae-cn-fhs";
    
    targetPkgs = pkgs: with pkgs; [
      # 基础库
      glib
      glibc
      gtk3
      gobject-introspection
      gdk-pixbuf
      pango
      cairo
      atk
      at-spi2-core
      
      # X11 相关
      libx11
      libxext
      libxcomposite
      libxdamage
      libxfixes
      libxrandr
      libxcb
      libxkbfile
      
      # OpenGL/图形
      mesa
      libglvnd
      libdrm
      libva
      libgbm
      libxkbcommon
      
      # 音频
      alsa-lib
      pulseaudio
      
      # 加密和安全
      gnutls
      libgcrypt
      nss
      nspr
      openssl
      
      # 系统工具
      systemd
      expat
      dbus
      libuuid
      curl
      libarchive
      zlib
      
      # WebKit 和网络
      webkitgtk_4_1
      libsoup_3
      libsecret
      
      # 其他
      cups
      udev
      libnotify
      
      # 运行时工具
      bash
      coreutils
      findutils
      which
      procps
    ];
    
    multiPkgs = pkgs: with pkgs.pkgsi686Linux; [
      glibc
      libx11
      mesa
      libglvnd
    ];
    
    runScript = pkgs.writeShellScript "run-trae-cn" ''
      #!/bin/sh
      set -e
      
      export APP_DIR="/app"
      export TRAE_CN_HOME="$HOME/.config/Trae CN"
      
      # 创建配置目录
      mkdir -p "$TRAE_CN_HOME"
      mkdir -p "$HOME/.trae-cn"
      
      # 设置 OpenGL 相关环境变量
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver/lib32:$APP_DIR/share/trae-cn:$APP_DIR/share/trae-cn/resources/app/modules/ckg/binary:$LD_LIBRARY_PATH"
      
      # 强制使用 X11 后端（解决 Wayland 下的 OpenGL 问题）
      export QT_QPA_PLATFORM=xcb
      export GDK_BACKEND=x11
      
      # 禁用 GPU sandbox 但保留 GPU 加速
      export DISABLE_GPU_SANDBOX=1
      
      # Electron 环境
      export ELECTRON_FORCE_IS_PACKAGED=true
      export ENABLE_IPC_SERVER=true
      export TRAE_RUNTIME=local
      export TRAE_STATIC_CLIENT_TYPE=ide
      
      # 启动应用（使用 --use-gl=egl 或 --use-gl=desktop）
      if [ -f "$APP_DIR/share/trae-cn/trae-cn" ]; then
        exec "$APP_DIR/share/trae-cn/trae-cn" \
          --no-sandbox \
          --disable-gpu-sandbox \
          --use-gl=desktop \
          --ignore-gpu-blocklist \
          --enable-features=UseOzonePlatform \
          --ozone-platform=x11 \
          "$@"
      else
        echo "错误：找不到 trae-cn 可执行文件"
        find "$APP_DIR" -name "trae-cn" -type f
        exit 1
      fi
    '';
    
    extraBuildCommands = ''
      mkdir -p $out/app
      cp -r ${unpacked}/* $out/app/
      
      # 确保可执行权限
      chmod +x $out/app/share/trae-cn/trae-cn 2>/dev/null || true
      chmod 0755 $out/app/share/trae-cn/chrome-sandbox 2>/dev/null || true
      
      # 创建 bin 目录
      #mkdir -p $out/bin
      
      # 创建启动脚本包装器
      cat > $out/app/trae-cn << EOF
#!/bin/sh
exec $out/app/share/trae-cn/trae-cn \\
  --no-sandbox \\
  --disable-gpu-sandbox \\
  --use-gl=desktop \\
  --ignore-gpu-blocklist \\
  "\$@"
EOF
      #chmod +x $out/bin/trae-cn
      
      # 创建 desktop 文件
      mkdir -p $out/share/applications
      cat > $out/share/applications/trae-cn.desktop << 'EOF'
[Desktop Entry]
Name=Trae CN
Comment=Trae CN IDE
Exec=trae-cn %F
Icon=trae-cn
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Trae CN
MimeType=text/plain;inode/directory;
EOF
      
      # 复制图标
      if [ -d "$out/app/share/trae-cn/resources/app/resources/linux" ]; then
        mkdir -p $out/share/icons/hicolor/128x128/apps
        cp $out/app/share/trae-cn/resources/app/resources/linux/*.png $out/share/icons/hicolor/128x128/apps/ 2>/dev/null || true
      fi
    '';
  };
  
in
fhsEnv