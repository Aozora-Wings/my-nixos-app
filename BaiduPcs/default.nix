{
  fetchurl,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  lib,
  makeDesktopItem,
  copyDesktopItems,
  dpkg,
  # Baidu Netdisk dependencies (from control file)
  gtk3,
  libnotify,
  nss,
  libXScrnSaver,
  libxtst,
  xdg-utils,
  at-spi2-core,
  libuuid,
  libsecret,
  libappindicator-gtk3,
  # Additional runtime dependencies
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  libdbusmenu,
  libglvnd,
  libpulseaudio,
  nspr,
  pango,
  pciutils,
  udev,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libdrm,
  mesa
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "baidunetdisk";
  version = "4.17.8";
  
  src = fetchurl {
    url = "https://pkg-ant.baidu.com/issue/netdisk/LinuxGuanjia/${finalAttrs.version}/baidunetdisk_${finalAttrs.version}_amd64.deb";
    hash = "sha256-rTpM4/29u0TT4Vf6By9pLAYpvn5ulOkVHPw0CMDVuiM=";  # You need to replace this with the actual hash
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
    dpkg
  ];

  buildInputs = [
    # Explicitly listed dependencies from control file
    gtk3
    libnotify
    nss
    libXScrnSaver
    libxtst
    xdg-utils
    at-spi2-core
    libuuid
    libsecret
    libappindicator-gtk3
    # Additional dependencies for Chromium framework
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    libdbusmenu
    libglvnd
    libpulseaudio
    nspr
    pango
    pciutils
    udev
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libdrm
    mesa
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg -x $src .

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out 2>/dev/null
    # cp -r usr/* $out/

    # Create bin directory and wrapper
    mkdir -p $out/bin
    ls $out/opt/baidunetdisk
    # The executable name might vary, common patterns:
      # makeWrapper $out/opt/baidunetdisk/baidunetdisk $out/bin/baidunetdisk \
      #   --argv0 "baidunetdisk" \
      #   --add-flags "--no-sandbox" \
      #   --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath finalAttrs.buildInputs}"
  cat > $out/bin/baidunetdisk << EOF
  #!/bin/bash
  # Change to the program directory
  cd "$out/opt/baidunetdisk"
  # Set library path to include current directory
  export LD_LIBRARY_PATH="\$PWD:${lib.makeLibraryPath finalAttrs.buildInputs}:\$LD_LIBRARY_PATH"
  # Run the program with no-sandbox flag
  exec "$out/opt/baidunetdisk/baidunetdisk" --no-sandbox "\$@"
EOF
  
  chmod +x $out/bin/baidunetdisk
    # Clean up swiftshader if exists
    # rm -rf $out/opt/baidunetdisk/swiftshader 2>/dev/null || rm -rf $out/opt/baidu/baidunetdisk/swiftshader 2>/dev/null

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "baidunetdisk";
      desktopName = "BaiduNetdisk";
      exec = "baidunetdisk %U";
      terminal = false;
      icon = "baidunetdisk";
      startupWMClass = "baidunetdisk";
      comment = "Baidu Netdisk Client";
      categories = [ "Network" "FileTransfer" ];
      extraConfig = {
        "Name[zh_CN]" = "百度网盘";
        "Name[zh_TW]" = "百度網盤";
        "Comment[zh_CN]" = "百度网盘客户端";
        "Comment[zh_TW]" = "百度網盤客戶端";
      };
    })
  ];

  meta = {
    maintainers = with lib.maintainers; [ /* your name here */ ];
    description = "Baidu Netdisk Client";
    homepage = "https://pan.baidu.com/";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.free;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "baidunetdisk";
  };
})