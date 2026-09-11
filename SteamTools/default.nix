{ pkgs ? import <nixpkgs> {}
,stdenv
, ...
}:

let
  lib = pkgs.lib;
  dotnet-sdk_11 = pkgs.dotnetCorePackages.sdk_11_0;

  src = pkgs.fetchurl {
    url = "https://oazcc.qzapp.qkzy.net/Steam++.tgz";
    sha256 = "sha256-0ZHHBbK39jSfTTaXIEXxpKYeWWn0HUGuG0xIAfBa644=";
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
  # 关键：nix stdenv 默认 strip 会重写 ELF 并丢弃尾部 SingleFile bundle
  # （Steam++.Accelerator 是 15.5MB 单文件，strip 后只剩 59KB → bundle 损坏）。
  dontStrip = true;

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

    # SkiaSharp 2.88 native resolver 只搜 app 目录/固定路径（不认 ../native/<rid>、不走 LD_LIBRARY_PATH）：
    # 必须把发布工具移出的原生库平铺回 assemblies/，同时保留 runtimes 布局（deps.json 声明）。
    chmod -R u+w $out/assemblies
    if [ -d "$src/native/linux-x64" ]; then
      mkdir -p $out/assemblies/runtimes/linux-x64/native
      cp -v $src/native/linux-x64/*.so $out/assemblies/
      cp -v $src/native/linux-x64/*.so $out/assemblies/runtimes/linux-x64/native/
    fi

    # ---- 关键修复：out/modules/Accelerator/ 只保留插件 UI 入口及其非 Avalonia 依赖 ----
    # 插件系统在独立 ALC 中从模块目录 LoadFrom。若模块目录存在 Steam++.Accelerator.dll
    # （加速器服务本体）或 Avalonia/BD.Common 等运行时副本，会与主程序 assemblies/ 形成
    # 双实例，导致 StandardAssetLoader 资源解析错乱（avares FileNotFoundException，UI 启动崩溃）。
    # 加速器服务本体由 $accelerator 输出（完整模块）供 systemd 服务运行，主程序包不携带。
    if [ -d "$out/modules/Accelerator" ]; then
      chmod -R u+w $out/modules/Accelerator
      (cd $out/modules/Accelerator && \
        find . -maxdepth 1 -type f \
          ! -name 'BD.WTTS.Client.Plugins.Accelerator.dll' \
          ! -name 'BD.WTTS.Primitives.dll' \
          ! -name 'BD.WTTS.Primitives.Models.dll' \
          ! -name 'BD.WTTS.Primitives.Resources.dll' \
          ! -name 'BD.WTTS.MicroServices.Primitives.dll' \
          ! -name 'BD.WTTS.MicroServices.Primitives.Models.dll' \
          ! -name 'BD.WTTS.MicroServices.Primitives.Resources.dll' \
          ! -name 'BD.WTTS.Client.IPC.dll' -delete \
        && rm -rf en es it ja ko ru zh-Hant)
      echo "out/modules/Accelerator/ 精简为插件入口+依赖: $(ls $out/modules/Accelerator | wc -l) 文件"
    fi

    # 入口 wrapper：直接使用 dotnet 运行主程序，参数/环境变量由 makeWrapper 自然传递
    mkdir -p $out/bin
    makeWrapper ${dotnet-sdk_11}/bin/dotnet $out/bin/watt-toolkit \
      --set DOTNET_ROOT "${dotnet-sdk_11}/share/dotnet" \
      --set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT "1" \
      --set STEAMTOOLS_BUNDLED_PFX "$ssl/SteamTools.Certificate.pfx" \
      --run 'export XDG_DATA_HOME="$HOME/.local/share/WattToolkit"' \
      --prefix PATH : "${dotnet-sdk_11}/bin:${pkgs.nss_latest}/bin" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:${dotnet-sdk_11}/share/dotnet" \
      --add-flags "$out/assemblies/Steam++.dll"
    echo "Watt Toolkit 已安装到: $out/bin/watt-toolkit"

    # ---- Accelerator（accelerator output，NixOS 目录发布） ----
    # 加速器在 NixOS 构建时改为目录发布（发布工具检测 /etc/NIXOS 设 SingleFile=false）：
    # SingleFile apphost 在 NixOS 加载运行时失败（宿主退出码 203），目录发布后由
    # systemd 服务用 dotnet 直接运行 Steam++.Accelerator.dll（与主程序目录发布一致）。
    mkdir -p $accelerator
    if [ -d "$src/modules/Accelerator" ]; then
      cp -r "$src/modules/Accelerator"/* $accelerator/
      chmod -R u+w $accelerator
      chmod 755 $accelerator/Steam++.Accelerator 2>/dev/null || true
      echo "已复制加速器目录（目录发布）:"
      ls $accelerator | head -25
    else
      echo "警告: 未找到 modules/Accelerator 目录"
      find $src -iname '*Accelerator*' 2>/dev/null || true
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
