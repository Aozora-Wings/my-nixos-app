{ lib,
  stdenv,
  fetchurl,
  fetchzip,
  autoPatchelfHook,
  dotnet-sdk_8,
  pkgs,
  systemd,
  nixUnstable,
  commonLibs,
  ...}: #参数列表

let
  #unstable = import (builtins.fetchTarball "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz") { config = { allowUnfree = true; }; };
  #unstable=https://nixos.org/channels/nixos-unstable
  pname = "115Browser";
  version = "35.3.0.2";
  src = {
    x86_64-linux = fetchurl {
      #url = "https://github.com/ppy/osu/releases/download/${version}/osu.AppImage";
      url = "https://down.115.com/client/115pc/lin/115br_v${version}.deb";
      sha256 = "";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "115 Browser for Nixos";
    homepage = "https://115.com/";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
      unfreeRedistributable # osu-framework contains libbass.so in repository
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "115.sh";
    platforms = [ "x86_64-linux" ];
  };

  #passthru.updateScript = ./update-bin.sh;
    runtimeDependencies = map lib.getLib [
  ];
      needlib =  with pkgs; [
        libdrm
        e2fsprogs
        p11-kit
        alsa-lib
        glib
        libglvnd
        libgpg-error
    ];
in
stdenv.mkDerivation {
  #passthru
  inherit pname version src meta ;
    nativeBuildInputs = [
      autoPatchelfHook
      pkgs.dpkg
    # makeBinaryWrapper not support shell wrapper specifically for `NIXOS_OZONE_WL`.
  ];
  #构建时所需要的依赖

    buildInputs = commonLibs ++ needlib;
 #运行时所需要的依赖
    runtimeDependencies = map lib.getLib [
  ];
  #解压缩
unpackPhase = ''
  echo "115 unpackPhase installings...."
  mkdir temp
  dpkg-deb -R $src temp
  mkdir temp2
  tar -xJf temp/data.tar.xz -C temp2
  tar -xf temp2/data.tar -C temp2
  mkdir -p $out/usr/
  cp -rT temp2/usr $out/usr
'';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
installPhase = ''
  runHook preInstall

  sed -i "s|Exec=sh /usr/local/115Browser/115.sh|Exec=sh $out/usr/local/115Browser/115.sh|g" $out/usr/share/applications/115.desktop
  sed -i "s|Icon=/usr/local/115Browser/res/115Browser.png|Icon=$out/usr/local/115Browser/res/115Browser.png|g" $out/usr/share/applications/115.desktop

  cat > $out/usr/local/115Browser/115.sh <<EOF
#!/bin/sh

export LD_LIBRARY_PATH=$out/usr/local/115Browser:\$LD_LIBRARY_PATH

# 配置
APP_DIR=$out/usr/local/115Browser
APP_NAME=115Browser
APP_PATH="\${APP_DIR}/\${APP_NAME}"

# 检查程序目录
if [ ! -d "\${APP_DIR}" ]; then
    echo "Error: \${APP_DIR} not found!"
    exit 1
fi

# 检查程序文件
if [ ! -f "\${APP_PATH}" ]; then
    echo "Error: \${APP_PATH} not found!"
    exit 1
fi

# 检查执行权限
if [ ! -x "\${APP_PATH}" ]; then
    echo "Error: \${APP_PATH} not executable!"
    exit 1
fi

# 切换目录
cd "\${APP_DIR}" || exit 1

# 处理启动参数
start_browser() {
    local delay=\$1
    local args=\$2
    
    if [ "\$delay" -gt 0 ]; then
        echo "Waiting for \${delay} seconds before start..."
        sleep "\$delay"
    fi
    
    if [ -n "\$args" ]; then
        "\${APP_PATH}" "\$args" >/dev/null 2>&1 &
    else
        "\${APP_PATH}" >/dev/null 2>&1 &
    fi
    
    echo "Starting \${APP_NAME}..."
}

# 根据参数决定启动方式
case "\$1" in
    "update")
        start_browser 2 "--update"
        ;;
    "")
        start_browser 0
        ;;
    *)
        start_browser 0 "\$1"
        ;;
esac

exit 0
EOF

  runHook postInstall
'';
}