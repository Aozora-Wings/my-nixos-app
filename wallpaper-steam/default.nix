{ lib
, fetchFromGitHub
, kpackage
, libplasma
, lz4
, mkKdeDerivation
, mpv-unwrapped
, pkg-config
, python3
, qtbase
, qtmultimedia
, qtwebchannel
, qtwebengine
, qtwebsockets
, wrapPython
, makeWrapper
, extra-cmake-modules
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    websockets
  ]);
in

mkKdeDerivation {
  pname = "wallpaper-engine-kde-plugin-my";
  version = "0.5.5-unstable-2024-11-03";

  src = fetchFromGitHub {
    owner = "catsout";
    repo = "wallpaper-engine-kde-plugin";
    rev = "ed58dd8b920dbb2bf0859ab64e0b5939b8a32a0e";
    hash = "sha256-ICQLtw+qaOMf0lkqKegp+Dkl7eUgPqKDn8Fj5Osb7eA=";
    fetchSubmodules = true;
  };

  patches = [ ./nix-plugin.patch ];

  nativeBuildInputs = [
    kpackage
    pkg-config
    python3
    wrapPython
    makeWrapper
  ];

  buildInputs = [
    extra-cmake-modules
    libplasma
    lz4
    mpv-unwrapped
    pythonEnv
  ];

  extraCmakeFlags = [
    (lib.cmakeFeature "QML_LIB" (
      lib.makeSearchPathOutput "out" "lib/qt-6/qml" [
        qtmultimedia
        qtwebchannel
        qtwebengine
        qtwebsockets
      ]
    ))
    (lib.cmakeFeature "Qt6_DIR" "${qtbase}/lib/cmake/Qt6")
  ];

  postInstall = ''
    cd $out/share/plasma/wallpapers/com.github.catsout.wallpaperEngineKde
    
    # 设置可执行权限
    chmod +x ./contents/pyext.py
    
    # 修正 shebang
    patchShebangs ./contents/pyext.py
    
    # 包装 Python 脚本
    wrapProgram ./contents/pyext.py \
      --prefix PYTHONPATH : "${pythonEnv}/${python3.sitePackages}" \
      --prefix PATH : "${lib.makeBinPath [ python3 ]}"
    
    # 替换 Nix 存储路径
    substituteInPlace ./contents/ui/Pyext.qml \
       --replace-fail NIX_STORE_PACKAGE_PATH "$out"
    
    cd -
  '';

  meta = with lib; {
    description = "KDE wallpaper plugin integrating Wallpaper Engine";
    homepage = "https://github.com/catsout/wallpaper-engine-kde-plugin";
    license = licenses.gpl2Only;
    maintainers = with maintainers; [ macronova ];
  };
}