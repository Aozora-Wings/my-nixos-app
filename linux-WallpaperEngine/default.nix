{ lib
, fetchzip
, stdenv
, fetchFromGitHub
, cmake
, ffmpeg
, freeglut
, freeimage
, glew
, glfw
, glm
, libGL
, libpulseaudio
, libX11
, libXau
, libXdmcp
, libXext
, libXpm
, libXrandr
, libXxf86vm
, lz4
, mpv
, pkg-config
, SDL2
, SDL2_mixer
, zlib
, libcef
}:
let src1 = fetchFromGitHub {
    owner = "Almamu";
    repo = "linux-wallpaperengine";
    # upstream lacks versioned releases
    rev = "13cc080410444ea72cceebdd5ea0ae7c23dd2270";
    hash = "sha256-XdFU5BKZPyGpV0PYmmM12efMFimt3eJAsG+dzyycIzo=";
  };
   src2 = fetchzip {
     url = "https://cef-builds.spotifycdn.com/cef_binary_120.1.10%2Bg3ce3184%2Bchromium-120.0.6099.129_linux64.tar.bz2";
     sha256 = "sha256-FFkFMMkTSseLZIDzESFl8+h7wRhv5QGi1Uy5MViYpX8=";
   };
  in
stdenv.mkDerivation {
  pname = "linux-wallpaperengine";
  version = "unstable-2023-09-23";
  srcs = [ src1 ];
  sourceRoot = "${src1.name}";
preConfigure = ''
  export CEF_ROOT=${src2}
'';

buildPhase = ''
  echo "CEF_ROOT is $CEF_ROOT"
  cmake .
  make
'';
  cmakeFlags = [
   # "-DCEF_ROOT=${libcef}"
  ];
#   src = fetchFromGitHub {
#     owner = "Almamu";
#     repo = "linux-wallpaperengine";
#     # upstream lacks versioned releases
#     rev = "13cc080410444ea72cceebdd5ea0ae7c23dd2270";
#     hash = "sha256-XdFU5BKZPyGpV0PYmmM12efMFimt3eJAsG+dzyycIzo=";
#   };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    ffmpeg
    freeglut
    freeimage
    glew
    glfw
    glm
    libGL
    libpulseaudio
    libX11
    libXau
    libXdmcp
    libXext
    libXrandr
    libXpm
    libXxf86vm
    mpv
    lz4
    SDL2
    SDL2_mixer.all
    zlib
    libcef
  ];

  meta = {
    description = "Wallpaper Engine backgrounds for Linux";
    homepage = "https://github.com/Almamu/linux-wallpaperengine";
    license = lib.licenses.gpl3Only;
    mainProgram = "linux-wallpaperengine";
    maintainers = with lib.maintainers; [ eclairevoyant ];
    platforms = lib.platforms.linux;
  };
}