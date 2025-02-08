{ stdenv, fetchzip, cmake, qt5, texlive, ghostscript, ... }:

stdenv.mkDerivation rec {
  pname = "klatexformula";
  version = "4.1.0";

  src = fetchzip {
    url = "https://sourceforge.net/projects/${pname}/files/${pname}/${pname}-${version}/${pname}-${version}.tar.bz2";
    sha256 = "sha256-0w9JlJoJz3EBkdxIGXPK1UsirGjX+fsc0Mf+hc5ZT4k=";
  };

  nativeBuildInputs = with qt5; [
    cmake qtbase qttools qtx11extras wrapQtAppsHook
  ];

  patches = [
    ./patches/add_missing_QPainterPath_include.patch
  ];

  postPatch = ''
    substituteInPlace src/klfbackend/klfbackend.cpp \
      --replace 'QStringList progLATEX = QStringList() << "latex"' 'QStringList progLATEX = QStringList() << "${texlive.combined.scheme-basic}/bin/latex"' \
      --replace 'QStringList progDVIPS = QStringList() << "dvips"' 'QStringList progDVIPS = QStringList() << "${texlive.combined.scheme-basic}/bin/dvips"' \
      --replace 'QStringList progGS = QStringList() << "gs"' 'QStringList progGS = QStringList() << "${ghostscript}/bin/gs"'
  '';
}
