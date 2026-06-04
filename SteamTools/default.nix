{ pkgs ? import <nixpkgs> {}
,stdenv
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
    if [ -f "Steam++.dll" ]; then
      mv Steam++.dll assemblies/ 2>/dev/null || true
    fi
    
    mv *.dll assemblies/ 2>/dev/null || true
  '';
  
  fhsEnv = pkgs.buildFHSEnv {
    name = "watt-toolkit";
    
    targetPkgs = pkgs: with pkgs; [
      dotnet-sdk_10
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
      nss_latest.tools
      lttng-ust
      icu74
      libunwind
      libuuid
      krb5
      curl
      alsa-lib
      pulseaudio
      bash
      coreutils
      findutils
    ];
    
    multiPkgs = pkgs: with pkgs.pkgsi686Linux; [
      glibc
      libGL
      libX11
      libXcursor
      libXext
      libXi
      libXrandr
    ];
    
    runScript = pkgs.writeShellScript "run-watt-toolkit" ''
      #!/bin/sh
      set -e
      
      export DOTNET_ROOT="${dotnet-sdk_10}/share/dotnet"
      export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
      export PATH="${dotnet-sdk_10}/bin:${pkgs.nss_latest}/bin:$PATH"
      
      export LD_LIBRARY_PATH="${dotnet-sdk_10}/share/dotnet:${dotnet-sdk_10}/share/dotnet/host/fxr:${lib.makeLibraryPath (with pkgs; [ libGL libICE libSM libXcursor libXext libXi libXrandr ])}:$LD_LIBRARY_PATH"
      
      export XDG_DATA_HOME="$HOME/.local/share/WattToolkit"
      mkdir -p "$XDG_DATA_HOME"
      
      APP_DIR="/app"
      
      echo "启动 Watt Toolkit..."
      
      if [ ! -d "$APP_DIR/assemblies" ]; then
        mkdir -p "$APP_DIR/assemblies"
        find "$APP_DIR" -maxdepth 1 -name "*.dll" -exec mv {} "$APP_DIR/assemblies/" \; 2>/dev/null
      fi
      
      if [ -f "$APP_DIR/assemblies/Steam++.dll" ]; then
        exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/assemblies/Steam++.dll" "$@"
      elif [ -f "$APP_DIR/Steam++.dll" ]; then
        exec ${dotnet-sdk_10}/bin/dotnet "$APP_DIR/Steam++.dll" "$@"
      else
        echo "错误：找不到 Steam++.dll"
        find "$APP_DIR" -name "*.dll" -type f
        exit 1
      fi
    '';
    
    extraBuildCommands = ''
      mkdir -p $out/app/assemblies
      cp -r ${unpacked}/* $out/app/
      
      if [ -f "$out/app/Steam++.dll" ]; then
        mv $out/app/Steam++.dll $out/app/assemblies/
      fi
      mv $out/app/*.dll $out/app/assemblies/ 2>/dev/null || true
      
      mkdir -p $out/app/assemblies/native
      ln -sf ${pkgs.libGL}/lib/libGL.so.1 $out/app/assemblies/ 2>/dev/null || true
      ln -sf ${pkgs.libICE}/lib/libICE.so.6 $out/app/assemblies/ 2>/dev/null || true
      ln -sf ${pkgs.libSM}/lib/libSM.so.6 $out/app/assemblies/ 2>/dev/null || true
      
      if [ -d $out/app/Icons ]; then
        mkdir -p $out/share/icons/hicolor/128x128/apps
        cp $out/app/Icons/*.png $out/share/icons/hicolor/128x128/apps/ 2>/dev/null || true
      fi
      
      chmod -R +r $out/app/
    '';
  };
  
in
stdenv.mkDerivation {
  pname = "watt-toolkit";
  version = "3.1.0";
  
  # 声明多个输出
  outputs = [ "out" "accelerator" ];
  
  src = fhsEnv;
  dontUnpack = true;
  dontBuild = true;
  
  installPhase = ''
    runHook preInstall
    
    # 安装主程序（out output）
    mkdir -p $out/bin
    cp -r ${fhsEnv}/* $out/
    echo ${fhsEnv}
    ln -sf ${fhsEnv}/bin/watt-toolkit $out/bin/watt-toolkit
    echo "Watt Toolkit 已安装到: $out/bin/watt-toolkit"
    temp=$(grep -oP '/nix/store/[^/]+-watt-toolkit-fhsenv-rootfs' $out/bin/watt-toolkit | head -1)
    echo "Watt Toolkit 环境: $temp 尝试输出目录："
    ls $temp
    # 直接从 unpacked 中查找并复制 Accelerator 到单独的 output
    mkdir -p $accelerator/bin
    
    # 查找 Accelerator 文件
    ACCELERATOR_FILE=""
    if [ -f "${unpacked}/modules/Accelerator/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="${unpacked}/modules/Accelerator/Steam++.Accelerator"
    elif [ -f "${unpacked}/Accelerator/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="${unpacked}/Accelerator/Steam++.Accelerator"
    elif [ -f "${unpacked}/Steam++.Accelerator" ]; then
      ACCELERATOR_FILE="${unpacked}/Steam++.Accelerator"
    fi
    
    if [ -n "$ACCELERATOR_FILE" ] && [ -f "$ACCELERATOR_FILE" ]; then
      echo "找到 Accelerator: $ACCELERATOR_FILE"
      
      # 复制 Accelerator 文件
      cp "$ACCELERATOR_FILE" $accelerator/bin/Steam++.Accelerator
      chmod +x $accelerator/bin/Steam++.Accelerator
      
    else
      echo "警告: 未找到 Accelerator 文件"
      find ${unpacked} -name "*.Accelerator" -o -name "*accelerator*" 2>/dev/null || true
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