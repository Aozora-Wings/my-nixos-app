{ lib, python3, fetchFromGitHub, gettext
, wrapGAppsHook, gobject-introspection
, gtk3, cairo, gspell, isocodes, gst_all_1
}:

python3.pkgs.buildPythonApplication {
  pname = "gaupol";
  version = "1.11";

  src = fetchFromGitHub {
    owner = "otsaloma";
    repo = "gaupol";
    rev = "51ae5c96e25fef795f29df0684f9c00e615e74e7";
    hash = "sha256-iF2ScQFYxYM2o18Cfy6U6JAZxIiZSsGrWEb4yjyECwc=";
  };

  nativeBuildInputs = [
    gettext
    wrapGAppsHook # GI_TYPELIB_PATH
    gobject-introspection
  ];

  buildInputs = [
    gobject-introspection
    gtk3
    cairo
    gspell
    isocodes
  ] ++ (with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ]);

  propagatedBuildInputs = [
    python3.pkgs.pygobject3
    python3.pkgs.chardet
    python3.pkgs.pycairo
  ];

  doCheck = false;

  postPatch = ''
    line=$(grep -n '# Allow --root to be used like DESTDIR.' setup.py | sed 's,:.*,,')
    start=$(( $line - 2 ))
    stop=$(( $line + 3 ))
    sed -i -e "''${start},''${stop}d" setup.py
    sed -i -e "''${start}i\        prefix = '$out'" setup.py
  '';

  meta = with lib; {
    description = "Editor for text-based subtitles";
    homepage = "https://otsaloma.io/gaupol/";
    license = licenses.gpl3;
    maintainers = [
      {
        name = "Azure Zanculmarktum";
        email = "zanculmarktum@gmail.com";
      }
    ];
    platforms = platforms.all;
  };
}
