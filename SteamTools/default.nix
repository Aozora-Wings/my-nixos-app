{ pkgs ? import <nixpkgs> {}
, ...
}:

let
  lib = pkgs.lib;
  dotnet-sdk_10 = pkgs.dotnetCorePackages.sdk_10_0;
  
  src = pkgs.fetchurl {
    url = "https://publicinaccess.blob.core.windows.net/file/Steam++.tgz";
    sha256 = "sha256-bEiiYsBO4iBoqW0x+oXriRof30NqwDmUlurC+t3xQjw=";
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
    mv *.dll assemblies/ 2>/dev/null || true
  '';
  
  fhsEnv = pkgs.buildFHSEnv {
    name = "watt-toolkit-fhs";
    
    targetPkgs = pkgs: with pkgs; [
      dotnet-sdk_10
      libGL libICE libSM libXcursor libXext libXi libXrandr
      gtk3 glib at-spi2-core fontconfig.lib openssl zlib icu74
      bash coreutils
    ];
    
    runScript = pkgs.writeShellScript "run-watt-toolkit" ''
      export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
      export PATH="${dotnet-sdk_10}/bin:$PATH"
      exec ${dotnet-sdk_10}/bin/dotnet /app/assemblies/Steam++.dll "$@"
    '';
    
    extraBuildCommands = ''
      mkdir -p $out/app
      cp -r ${unpacked}/* $out/app/
      chmod -R +r $out/app/
      
      # 创建启动 Accelerator 的脚本（在容器外运行）
     # mkdir -p $out/bin
      cat > $out/bin/run-accelerator <<'EOF'
#!/bin/sh
# 这个脚本会在 FHS 容器内启动 Accelerator
# 找到当前 FHS 环境的根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$SCRIPT_DIR/.."

# 检查 Accelerator 是否存在
if [ -f "$ROOTFS/app/modules/Accelerator/Steam++.Accelerator" ]; then
    ACCELERATOR="$ROOTFS/app/modules/Accelerator/Steam++.Accelerator"
elif [ -f "$ROOTFS/app/Accelerator/Steam++.Accelerator" ]; then
    ACCELERATOR="$ROOTFS/app/Accelerator/Steam++.Accelerator"
else
    echo "错误: 找不到 Accelerator"
    exit 1
fi

# 使用 dotnet 运行 Accelerator（因为它也是 .NET 程序）
export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
export PATH="${dotnet-sdk_10}/bin:$PATH"
export LD_LIBRARY_PATH="${lib.makeLibraryPath (with pkgs; [ libGL libICE libSM ])}"

exec ${dotnet-sdk_10}/bin/dotnet "$ACCELERATOR" "$@"
EOF
      chmod +x $out/bin/run-accelerator
      
      # 创建符号链接到 bin/Steam++.Accelerator
      ln -sf run-accelerator $out/bin/Steam++.Accelerator
    '';
  };
  
in
pkgs.symlinkJoin {
  name = "watt-toolkit";
  paths = [ fhsEnv ];
  
  postBuild = ''
    # 确保最终的 bin 目录中有 Accelerator 启动器
    mkdir -p $out/bin
    if [ -f ${fhsEnv}/bin/Steam++.Accelerator ]; then
      ln -sf ${fhsEnv}/bin/Steam++.Accelerator $out/bin/Steam++.Accelerator
      echo "Accelerator 启动器已创建: $out/bin/Steam++.Accelerator"
    fi
  '';
  
  meta = {
    description = "Watt Toolkit with standalone Accelerator launcher";
    mainProgram = "watt-toolkit";
  };
}