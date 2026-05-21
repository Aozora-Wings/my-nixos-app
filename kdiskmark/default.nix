{
  stdenv,
  lib,
  fio,
  cmake,
  fetchFromGitHub,
  kdePackages,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "kdiskmark";
  version = "3.2.0";

  src = fetchFromGitHub {
    owner = "jonmagon";
    repo = "kdiskmark";
    rev = finalAttrs.version;
    hash = "sha256-b42PNUrG10RyGct6dPtdT89oO222tEovkSPoRcROfaQ=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = with kdePackages; [
    cmake
    extra-cmake-modules
    wrapQtAppsHook
  ];

  buildInputs = with kdePackages; [
    qtbase
    qttools
    polkit-qt-1
  ];

  cmakeFlags = [
    "-DKF5AUTH_USING=OFF"  # 禁用 KAuth 支持
  ];

  preConfigure = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \$\{POLKITQT-1_POLICY_FILES_INSTALL_DIR\} $out/share/polkit-1/actions
  '';

  qtWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ fio ])
  ];

  meta = {
    description = "HDD and SSD benchmark tool with a friendly graphical user interface";
    longDescription = ''
      Built without KAuth support. The application will need to be run as root
      to perform benchmarks.
    '';
    homepage = "https://github.com/JonMagon/KDiskMark";
    maintainers = [ lib.maintainers.symphorien ];
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "kdiskmark";
  };
})