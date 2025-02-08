{ lib,
  stdenv,
  fetchurl,
  fetchzip,
  autoPatchelfHook,
  dotnet-sdk_8,
  pkgs,
  systemd,
  nixUnstable,
  ...}: #参数列表

let
  #unstable = import (builtins.fetchTarball "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz") { config = { allowUnfree = true; }; };
  #unstable=https://nixos.org/channels/nixos-unstable
  pname = "WattToolkit";
  version = "3.0.0-rc.8";
  readline = pkgs.readline;
  #history = pkgs.hishtory;
  ncurses = pkgs.ncurses;
  glibc = pkgs.glibc;
  openssl = pkgs.openssl;
  attr = pkgs.attr;
  gmp = pkgs.gmp;
  lttng-ust = pkgs.lttng-ust;
  fontconfig = pkgs.fontconfig.lib;
  libX11 = pkgs.xorg.libX11;
  libice = pkgs.xorg.libICE;
  libsm = pkgs.xorg.libSM;
  src = {
    x86_64-linux = fetchurl {
      url = "https://alist.qkzy.net/d/115/APP/%5BRelease%5D%20Steam%2B%2B_v3.0.0-rc.8_linux_x64_240624_1617075690292.tgz?sign=ZKa8VKUqh0ypQJ-AxZN-qq01QUYlifNrvEOYPTIKCZY=:0";
      sha256 = "sha256-+tdwvMfnWbYhqG1/JeZyGkR/xIb7t8CgsystejqwNWA=";
    };
  }.${stdenv.system} or (throw "${pname}-${version}: ${stdenv.system} is unsupported.");

  meta = {
    description = "Steam Tools";
    homepage = "https://steampp.net";
    license = with lib.licenses; [
      mit
      cc-by-nc-40
      unfreeRedistributable # osu-framework contains libbass.so in repository
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ delan spacefault stepbrobd ];
    mainProgram = "WattToolkit.sh";
    platforms = [ "x86_64-linux" ];
  };

  #passthru.updateScript = ./update-bin.sh;
    runtimeDependencies = map lib.getLib [
    pkgs.dotnetCorePackages.sdk_8_0_1xx
    pkgs.dotnet-runtime_8
    pkgs.readline
    pkgs.ncurses
    pkgs.icu74
    pkgs.glibc
    pkgs.openssl
    pkgs.attr
    pkgs.gmp
    pkgs.gcc.cc.lib
    pkgs.zlib
    pkgs.fontconfig
    pkgs.lttng-ust_2_12
    pkgs.nss_latest
    pkgs.gnome.zenity
    pkgs.xorg.libX11
    pkgs.xorg.libICE
    pkgs.xorg.libSM
  ];
in
stdenv.mkDerivation {
  #passthru
  inherit pname version src meta ;
    nativeBuildInputs = [
      autoPatchelfHook
      dotnet-sdk_8
      pkgs.makeWrapper
      pkgs.nss_latest
      pkgs.nss.tools
      pkgs.libcap
    # makeBinaryWrapper not support shell wrapper specifically for `NIXOS_OZONE_WL`.
  ];
  #构建时所需要的依赖
    buildInputs = [
    pkgs.dotnetCorePackages.sdk_8_0_1xx
    pkgs.dotnet-runtime_8
    pkgs.readline
    pkgs.ncurses
    pkgs.icu74
    pkgs.glibc
    pkgs.openssl
    pkgs.attr
    pkgs.gmp
    pkgs.gcc.cc.lib
    pkgs.zlib
    pkgs.fontconfig
    pkgs.lttng-ust_2_12
    pkgs.gnome.zenity
    pkgs.xorg.libX11
    pkgs.xorg.libICE
    pkgs.xorg.libSM
    pkgs.nss_latest
  ];
 #运行时所需要的依赖
runtimeDependencies =
map lib.getLib [
  pkgs.dotnet-runtime_8
  pkgs.readline
  pkgs.ncurses
  pkgs.icu74
  pkgs.glibc
  pkgs.openssl
  pkgs.attr
  pkgs.gmp
  pkgs.gcc.cc.lib
  pkgs.zlib
  pkgs.fontconfig
  pkgs.lttng-ust_2_12
  pkgs.nss_latest
  pkgs.gnome.zenity
  pkgs.xorg.libX11
  pkgs.xorg.libICE
  pkgs.xorg.libSM
];
  #解压缩
    unpackPhase = ''
    echo "Watt Toolkit unpackPhase installings...."
    mkdir temp
    tar -xzf $src -C temp
    mv temp/* .
  '';

#     preFixup = ''
    
#   autoPatchelfLibs+=(${lttng-ust}/lib)
#   echo "autoPatchelfLibs: $autoPatchelfLibs"
# '';
  dontPatchELF = true;
  dontStrip = true;
    installPhase = ''
    runHook preInstall
    echo "Watt Toolkit installPhase installings...."
    mkdir -p $out/bin
    cp -r . $out/bin
    # cp -r ./assemblies $out/bin
    # cp -r ./modules $out/bin
    # cp -r ./Icons $out/bin
    # cp -r ./native $out/bin
        # 创建 WattToolkit.sh 脚本
    cat > $out/bin/WattToolkit.sh <<EOF
#!/bin/sh
unset SSL_DIR
echo 'exporting sh_local'
export sh_local=/bin/sh
echo $sh_local
export PATH=${pkgs.nss_latest}:$PATH
export LD_LIBRARY_PATH=${pkgs.dotnet-runtime_8}/:${pkgs.dotnetCorePackages.sdk_8_0_1xx}/sdk:${pkgs.gcc.cc.lib}/lib:${libX11}/lib:${libice}/lib:${libsm}/lib:${fontconfig}/lib:$out/bin/native/linux-x64/:$LD_LIBRARY_PATH
export DOTNET_ROOT="${pkgs.dotnetCorePackages.sdk_8_0_1xx}"
#getcap /run/wrappers/bin/dotnet
dotnet "$out/bin/assemblies/Steam++.dll"
EOF
chmod +x $out/bin/WattToolkit.sh
wrapProgram $out/bin/WattToolkit.sh \
    --prefix PATH : ${pkgs.dotnetCorePackages.sdk_8_0_1xx}/sdk:${pkgs.dotnet-runtime_8}/bin:${pkgs.nss.tools}/bin:${pkgs.libcap}/bin
    chmod 755 $out/bin/WattToolkit.sh
    chmod -R 755 $out/bin/assemblies/
    mkdir -p $out/share/applications
    echo "create desktop file"
    cat > $out/share/applications/WattToolkit.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=$out/bin/WattToolkit.sh
Name=WattToolkit
Icon=$out/bin/Icons/Watt-Toolkit.png
EOF

    chmod 755 $out/share/applications/WattToolkit.desktop
runHook postInstall
'';
}