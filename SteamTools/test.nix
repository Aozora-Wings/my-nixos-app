{ pkgs ? import <nixpkgs> {} }:

let
  dotnet-sdk_10 = pkgs.dotnetCorePackages.sdk_10_0;
  
  src = pkgs.fetchurl {
    url = "https://publicinaccess.blob.core.windows.net/file/steam++.tgz";
    sha256 = "sha256-lp9NViBP9ngdzEaTeqsgWrdDB17jGc1ui1JV/i8IZbU=";
  };
  
  unpacked = pkgs.runCommand "steam++-unpacked" {} ''
    mkdir -p $out
    cd $out
    tar -xzf ${src}
    if [ -d "Steam++" ]; then
      mv Steam++/* ./
      rmdir Steam++
    fi
  '';
  
  # 诊断脚本 - 检查缺少的依赖
  diagnosticScript = pkgs.writeShellScript "diagnose" ''
    echo "=== 诊断 Watt Toolkit 环境 ==="
    
    # 1. 检查主程序需要的库
    echo -e "\n=== 1. 检查 .NET 运行时库依赖 ==="
    find /app -name "*.so" -type f -exec ldd {} \; 2>&1 | grep "not found" | sort -u
    
    # 2. 检查 dotnet 本身的依赖
    echo -e "\n=== 2. dotnet 依赖检查 ==="
    ldd ${dotnet-sdk_10}/bin/dotnet 2>&1 | grep "not found"
    
    # 3. 列出所有可用的库
    echo -e "\n=== 3. FHS 环境中的库路径 ==="
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo -e "\n/lib 目录内容:"
    ls -la /lib/*.so* 2>/dev/null | head -20
    echo -e "\n/usr/lib 目录内容:"
    ls -la /usr/lib/*.so* 2>/dev/null | head -20
    
    # 4. 检查特定的缺失库
    echo -e "\n=== 4. 常见缺失库检查 ==="
    for lib in libssl.so.3 libcrypto.so.3 libicuuc.so.74 libicui18n.so.74 liblttng-ust.so; do
      if ! ldconfig -p | grep -q "$lib"; then
        echo "缺失: $lib"
      fi
    done
    
    # 5. 运行时监控（如果程序能启动）
    echo -e "\n=== 5. 尝试运行并监控 ==="
    echo "使用 strace 追踪库加载..."
    strace -e openat,open,access ${dotnet-sdk_10}/bin/dotnet /app/assemblies/Steam++.dll 2>&1 | grep -E "ENOENT|No such file" | grep "\.so" | sort -u | head -30
    
    echo -e "\n=== 诊断完成 ==="
  '';
  
in
pkgs.buildFHSEnv {
  name = "watt-toolkit-diagnostic";
  
  targetPkgs = pkgs: with pkgs; [
    dotnet-sdk_10
    lttng-ust
    icu74
    openssl
    zlib
    fontconfig.lib
    nss_latest
    libX11
    libICE
    libSM
    gtk3
    glib
    at-spi2-core
    libunwind
    libuuid
    krb5
    curl
    # 诊断工具
    strace
    glibc.bin  # 提供 ldd
    binutils   # 提供 ldconfig
    file
  ];
  
  runScript = diagnosticScript;
  
  extraBuildCommands = ''
    mkdir -p $out/app
    cp -r ${unpacked}/* $out/app/
  '';
}