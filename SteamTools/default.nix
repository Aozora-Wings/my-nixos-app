{ pkgs ? import <nixpkgs> {}
,stdenv
, ...
}:

let
  lib = pkgs.lib;
  dotnet-sdk_10 = pkgs.dotnetCorePackages.sdk_10_0;

  src = pkgs.fetchurl {
    url = "https://oazcc.qzapp.qkzy.net/Steam++.tgz";
    sha256 = "sha256-5l2nESCaBKk5y/duY461K+8zSPcNSdZJeMLBxjHy+S8=";
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

  # 主程序运行时原生依赖（原 fhsEnv targetPkgs 清单，经 makeWrapper 注入 LD_LIBRARY_PATH）
  runtimeLibs = with pkgs; [
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
    lttng-ust
    icu74
    libunwind
    libuuid
    krb5
    curl
    alsa-lib
    pulseaudio
  ];

in
stdenv.mkDerivation {
  pname = "watt-toolkit";
  version = "3.1.0";

  # 声明多个输出：out（主程序）/ accelerator（加速子进程）/ ssl（系统根证书）
  outputs = [ "out" "accelerator" "ssl" ];

  src = unpacked;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.patchelf pkgs.openssl ];

  installPhase = ''
    runHook preInstall

    # ---- ssl output：生成系统根证书（打包证书源） ----
    # 与软件 CertGenerator 生成的主题/用途保持一致（CN=SteamTools Certificate, CA:TRUE, SHA256, 300 天）。
    # rebuild 后系统 security.pki.certificateFiles 信任新 cer；应用启动时经入口 wrapper
    # 的 STEAMTOOLS_BUNDLED_PFX 把同一把 PFX 同步到 AppData，保证代理私钥与系统信任一致。
    mkdir -p $ssl
    openssl req -x509 -newkey rsa:2048 -sha256 -days 300 -nodes \
      -keyout $ssl/SteamTools.Certificate.key.pem \
      -out $ssl/SteamTools.Certificate.cer \
      -subj "/C=CN/O=BeyondDimension/OU=Technical Department/CN=SteamTools Certificate" \
      -addext "basicConstraints=critical,CA:TRUE" \
      -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign" \
      -addext "extendedKeyUsage=serverAuth,clientAuth"
    openssl pkcs12 -export \
      -inkey $ssl/SteamTools.Certificate.key.pem \
      -in $ssl/SteamTools.Certificate.cer \
      -out $ssl/SteamTools.Certificate.pfx \
      -passout pass:
    rm -f $ssl/SteamTools.Certificate.key.pem
    chmod 644 $ssl/SteamTools.Certificate.cer $ssl/SteamTools.Certificate.pfx
    echo "已生成系统根证书: $ssl/SteamTools.Certificate.cer / .pfx"

    # ---- 主程序（out output） ----
    mkdir -p $out
    cp -r $src/* $out/
    mkdir -p $out/assemblies
    mv $out/*.dll $out/assemblies/ 2>/dev/null || true
    if [ -f "$out/Steam++.dll" ]; then
      mv $out/Steam++.dll $out/assemblies/
    fi

    # 入口 wrapper：直接使用 dotnet 运行主程序，参数/环境变量由 makeWrapper 自然传递
    mkdir -p $out/bin
    makeWrapper ${dotnet-sdk_10}/bin/dotnet $out/bin/watt-toolkit \
      --set DOTNET_ROOT "${dotnet-sdk_10}/share/dotnet" \
      --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT "1" \
      --set STEAMTOOLS_BUNDLED_PFX "$ssl/SteamTools.Certificate.pfx" \
      --set XDG_DATA_HOME "\$HOME/.local/share/WattToolkit" \
      --prefix PATH : "${dotnet-sdk_10}/bin:${pkgs.nss_latest}/bin" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:${dotnet-sdk_10}/share/dotnet" \
      --add-flags "$out/assemblies/Steam++.dll"
    echo "Watt Toolkit 已安装到: $out/bin/watt-toolkit"

    # ---- Accelerator（accelerator output） ----
    mkdir -p $accelerator/bin
    ACCELERATOR_FILE=""
    if [ -f "$src/modules/Accelerator/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="$src/modules/Accelerator/Steam++.Accelerator"
    elif [ -f "$src/Accelerator/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="$src/Accelerator/Steam++.Accelerator"
    elif [ -f "$src/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="$src/Steam++.Accelerator"
    fi

    if [ -n "$ACCELERATOR_FILE" ] && [ -f "$ACCELERATOR_FILE" ]; then
      echo "找到 Accelerator: $ACCELERATOR_FILE"
      cp "$ACCELERATOR_FILE" $accelerator/bin/Steam++.Accelerator
      # tgz 中权限为 700，改 755 保证 store 下所有用户可读可执行
      chmod 755 $accelerator/bin/Steam++.Accelerator

      # 修复单文件 apphost 的 ELF 解释器：
      # apphost 在发布机（NixOS）上被写死为构建时 store 的 glibc 路径，
      # 换机器/更新 nixpkgs 后路径不存在 → 报"找不到 app host"。
      # 用当前系统 glibc 重写解释器。
      patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $accelerator/bin/Steam++.Accelerator
      echo "已修复 Accelerator 解释器: $(patchelf --print-interpreter $accelerator/bin/Steam++.Accelerator)"
    else
      echo "警告: 未找到 Accelerator 文件"
      find $src -name "*.Accelerator" 2>/dev/null || true
    fi

    runHook postInstall
  '';

  meta = {
    description = "Watt Toolkit (Steam++)";
    homepage = "https://steampp.net";
    license = lib.licenses.gpl3Only;
    mainProgram = "watt-toolkit";
    platforms = [ "x86_64-linux" ];
  };
}
