{ pkgs ? import <nixpkgs> {}
,stdenv
, ...
}:
let
  lib = pkgs.lib;
  version = "2.3.33255";
  src = pkgs.fetchurl {
    url = "https://lf-cdn.trae.com.cn/obj/trae-com-cn/pkg/app/releases/stable/${version}/linux/Trae_CN-linux-x64.deb";
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
  
  # 创建启动脚本
  startupScript = pkgs.writeShellScript "trae-cn-start" ''
    #!/bin/sh
    set -e
    cp -f "$HOME/.ssh/config" "$HOME/.ssh/config.bak"
    rm -f "$HOME/.ssh/config"
    mv "$HOME/.ssh/config.bak" "$HOME/.ssh/config"
    chmod 644 "$HOME/.ssh/config"
    
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
    
    # 输入法支持
    # export GTK_IM_MODULE=fcitx
    # export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export INPUT_METHOD=fcitx
    export GLFW_IM_MODULE=ibus
    
    # SSH Agent 支持 - 查找主机 SSH agent socket
    SSH_AUTH_SOCK_EXPORTED=""
    
    # 尝试多个可能的 SSH agent socket 位置
    for possible_socket in "$SSH_AUTH_SOCK" "$HOME/.bitwarden-ssh-agent.sock" "/run/user/$UID/keyring/ssh" "/run/user/$UID/gnupg/S.gpg-agent.ssh" "$HOME/.ssh/ssh_auth_sock"; do
      if [ -S "$possible_socket" ] 2>/dev/null; then
        SSH_AUTH_SOCK_EXPORTED="$possible_socket"
        break
      fi
    done
    
    # 也尝试查找 gcr 的 ssh agent
    for gcr_socket in /run/user/$UID/gcr/ssh-*; do
      if [ -S "$gcr_socket" ] 2>/dev/null; then
        SSH_AUTH_SOCK_EXPORTED="$gcr_socket"
        break
      fi
    done
    
    # 尝试通配符匹配
    for possible_socket in /tmp/ssh-*/agent.*; do
      if [ -S "$possible_socket" ] 2>/dev/null; then
        SSH_AUTH_SOCK_EXPORTED="$possible_socket"
        break
      fi
    done
    
    if [ -n "$SSH_AUTH_SOCK_EXPORTED" ]; then
      export SSH_AUTH_SOCK="$SSH_AUTH_SOCK_EXPORTED"
      echo "SSH Agent 已连接: $SSH_AUTH_SOCK"
    else
      echo "警告: 未找到 SSH agent socket"
    fi
    
    # 导出 SSH 相关环境变量
    export SSH_ASKPASS="${pkgs.openssh}/libexec/ssh-askpass"
    
    # 禁用 GPU sandbox 但保留 GPU 加速
    export DISABLE_GPU_SANDBOX=1
    
    # Electron 环境
    export ELECTRON_FORCE_IS_PACKAGED=true
    export ENABLE_IPC_SERVER=true
    export TRAE_RUNTIME=local
    export TRAE_STATIC_CLIENT_TYPE=ide
    
    # 确保 PATH 包含常用工具和系统命令
    export PATH="$PATH:/run/current-system/sw/bin:/run/wrappers/bin"
    
    # 启动应用
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
      
      # 输入法支持
      fcitx5
      fcitx5-gtk
      kdePackages.fcitx5-qt
      libsForQt5.qt5.qtbase
      
      # Git 和 SSH 支持
      git
      openssh
      
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
    
    runScript = startupScript;
    
    extraBuildCommands = ''
      mkdir -p $out/app
      cp -r ${unpacked}/* $out/app/
      
      # 确保可执行权限
      chmod +x $out/app/share/trae-cn/trae-cn 2>/dev/null || true
      chmod 0755 $out/app/share/trae-cn/chrome-sandbox 2>/dev/null || true
      
      # 创建输入法配置文件
      mkdir -p $out/etc/profile.d
      cat > $out/etc/profile.d/fcitx.sh << 'EOF'
#!/bin/sh
#export GTK_IM_MODULE=fcitx
#export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF
      chmod +x $out/etc/profile.d/fcitx.sh
      
#       # 创建 /usr/bin 的 wrapper（因为 bin 被链接到 /usr/bin）
#       #mkdir -p $out/usr/bin
      
#       # SSH wrapper
#       cat > $out/usr/bin/ssh << EOF
# #!/bin/sh
# exec ${pkgs.openssh}/bin/ssh "\$@"
# EOF
#       chmod +x $out/usr/bin/ssh
      
#       cat > $out/usr/bin/ssh-add << EOFstartupScript
# #!/bin/sh
# exec ${pkgs.openssh}/bin/ssh-add "\$@"
# EOF
#       chmod +x $out/usr/bin/ssh-add
      
#       cat > $out/usr/bin/ssh-keygen << EOF
# #!/bin/sh
# exec ${pkgs.openssh}/bin/ssh-keygen "\$@"
# EOF
#       chmod +x $out/usr/bin/ssh-keygen
      
#       # Git wrapper
#       cat > $out/usr/bin/git << EOF
# #!/bin/sh
# exec ${pkgs.git}/bin/git "\$@"
# EOF
#       chmod +x $out/usr/bin/git
      
#       # 创建符号链接到 app 目录的启动脚本
#       ln -sf /app/share/trae-cn/trae-cn $out/usr/bin/trae-cn 2>/dev/null || true
    '';
  };
  
in
stdenv.mkDerivation {
  pname = "TraeCN";
  version = version;
  
  outputs = [ "out" ];
  
  src = fhsEnv;
  dontUnpack = true;
  dontBuild = true;
  
  installPhase = ''
    runHook preInstall
    
    # 安装主程序（out output）
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons/hicolor/128x128/apps
    cp ${unpacked}/share/applications/trae-cn.desktop $out/share/applications/trae-cn.desktop
  substituteInPlace $out/share/applications/trae-cn.desktop \
    --replace-fail "/usr/share/trae-cn/trae-cn" "trae-cn"

  ln -sf ${unpacked}/share/pixmaps/trae-cn.png $out/share/icons/hicolor/128x128/apps/trae-cn.png
    mkdir -p $out/bin
    cp -r ${fhsEnv}/* $out/
    ln -sf ${fhsEnv}/bin/trae-cn-fhs $out/bin/trae-cn
    
    runHook postInstall
  '';
  
  meta = {
    description = "Trae CN";
    homepage = "https://www.trae.cn/";
    license = lib.licenses.unfree;
    mainProgram = "trae-cn";
    platforms = [ "x86_64-linux" ];
  };
}