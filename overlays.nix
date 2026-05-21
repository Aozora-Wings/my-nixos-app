#overlays.nix
[
  (
    #self: super:
    final: prev:
      let
        inherit (prev.kdePackages) qtmultimedia qtwebchannel qtwebengine qtwebsockets;
        commonLibs = with prev; [
          pkgs.ncurses
          pkgs.icu74
          pkgs.glibc
          pkgs.openssl
          pkgs.attr
          pkgs.gmp
          pkgs.gcc.cc.lib
          pkgs.zlib
          pkgs.fontconfig
          pkgs.lttng-ust_2_12
          pkgs.nss_latest
          pkgs.zenity
          pkgs.xorg.libX11
          pkgs.xorg.libICE
          pkgs.xorg.libSM
          # Add more common libraries here...
        ];

      in
      {
        wallpaperengine-steam = prev.kdePackages.callPackage ./wallpaper-steam {
          inherit (prev) lz4 mpv-unwrapped python3;
          inherit (prev.python3Packages) wrapPython;
          # 不需要手动传 Qt/KDE 依赖，kdePackages 会自动处理
        };
        kdiskmark-fix = prev.callPackage ./kdiskmark {  };
        verysync-my = prev.callPackage ./verysync { inherit commonLibs; };
        Ipanel-my = prev.callPackage ./1panel { inherit commonLibs; };
        qq-my = prev.callPackage ./qq { };
        pc115-my = prev.callPackage ./pc115 { inherit commonLibs; };
        osu-my = prev.callPackage ./osu { };
        SteamTools-my = prev.callPackage ./SteamTools {
  nixUnstable = prev.nixUnstable;
};
        android-udev-rules = prev.android-udev-rules.overrideAttrs (oldAttrs: {
          installPhase = (oldAttrs.installPhase or "") + ''
            sed -i \
              -e 's/ATTR{idVendor}=="2b4c", ENV{adb_user}="yes"/&\n\n# Vivo\nATTR{idVendor}=="2d95", ENV{adb_user}="yes"/' \
              $out/lib/udev/rules.d/51-android.rules
          '';
        });

        conky-nox = prev.conky.override {
          x11Support = false;
        };

        discords = prev.discord.overrideAttrs (drv: drv // import ./discord/override.nix {
          inherit (prev) fetchurl;
        });

        dmenu =
          let
            seriesFile = builtins.split "\n" (builtins.readFile ./dmenu/patches/series);
            patchFiles = builtins.filter (x: ! builtins.isList x && x != "") seriesFile;
            patches = builtins.map (x: ./. + "/dmenu/patches/${x}") patchFiles;
          in
          prev.dmenu.override {
            inherit patches;
          };

        dwm =
          let
            seriesFile = builtins.split "\n" (builtins.readFile ./dwm/patches/series);
            patchFiles = builtins.filter (x: ! builtins.isList x && x != "") seriesFile;
            patches = builtins.map (x: ./. + "/dwm/patches/${x}") patchFiles;
          in
          (prev.dwm.override {
            inherit patches;
          }).overrideAttrs (oldAttrs: {
            postPatch = (oldAttrs.postPatch or "") + ''
              substituteInPlace dwm.c \
                --replace '@psmisc@' '${final.psmisc}/bin/'
              substituteInPlace config.def.h \
                --replace '@dmenu@' '${final.dmenu}/bin/' \
                --replace '@j4_dmenu_desktop@' '${final.j4-dmenu-desktop}/bin/' \
                --replace '@alacritty@' '${final.alacritty}/bin/'
            '';
          });

        # Library versions:
        # libavutil      55. 58.100
        # libavcodec     57. 89.100
        # libavformat    57. 71.100
        # libavdevice    57.  6.100
        # libavfilter     6. 82.100
        # libavresample   3.  5.  0
        # libswscale      4.  6.100
        # libswresample   2.  7.100
        # libpostproc    54.  5.100
        ffmpeg_3_3_9 = (prev.callPackage
          (import (prev.path + "/pkgs/development/libraries/ffmpeg/generic.nix") rec {
            version = "3.3.9";
            sha256 = "sha256-Z33h6bCVl0WaSx74cCVeeRamMkQ8zp2iQEbrmx4pXCA=";
            # extraPatches = [
            #   {
            #     name = "CVE-2017-16840.patch";
            #     url = "http://git.videolan.org/?p=ffmpeg.git;a=patch;h=a94cb36ab2ad99d3a1331c9f91831ef593d94f74";
            #     sha256 = "1rjr9lc71cyy43wsa2zxb9ygya292h9jflvr5wk61nf0vp97gjg3";
            #   }
            # ];
          })
          {
            inherit (prev.darwin.apple_sdk.frameworks)
              Cocoa CoreServices CoreAudio CoreMedia AVFoundation MediaToolbox
              VideoDecodeAcceleration VideoToolbox;
            withNvdec = false;
            withSdl2 = false;
            withNvenc = false;
          }).overrideAttrs (oldAttrs:
          let
            stripUnknownOptions = builtins.filter (x: builtins.match "^--(en|dis)able-(alsa|cuda-llvm|libdav1d|libaom|libdrm|libjack|libmysofa|librsvg|libsrt|libtensorflow|v4l2-m2m|libvmaf|libxml2|nvdec|librav1e|libsvtav1|vulkan|libglslang).*" x == null);
            disableOptions =
              let
                disable = x: y: if builtins.match ("^--enable-" + x + ".*") y != null then ("--disable-" + x) else y;
              in
              builtins.map (x: builtins.foldl' (x: f: f x) x [
                (disable "cuvid")
                (disable "nvenc")
                (disable "sdl2")
              ]);
          in
          {
            configureFlags = stripUnknownOptions oldAttrs.configureFlags;
          });

        flashplayer-standalone = prev.callPackage ./flashplayer-standalone { };

        gaupol = prev.callPackage ./gaupol { };

        #git = prev.git.overrideAttrs (drv: drv // {
        #  preConfigure = ''
        #    ${final.perl}/bin/perl -i ${./git/disable-CVE-2022-24765.pl} setup.c
        #    rm -f t/t0033-safe-directory.sh
        #  '';
        #});

        github-linguist = (import ./github-linguist { nixpkgs = prev; }).github-linguist;

        haskellPackages = prev.haskellPackages.override {
          overrides = self: super: with prev.haskell.lib; {

            binary-parsers = appendPatch super.binary-parsers ./binary-parsers/bytestring_version.patch;

            xmobar = overrideCabal super.xmobar
              (drv: {
                doCheck = false;
                configureFlags = [
                  "-fwith_utf8"
                  "-fwith_rtsopts"
                  "-fwith_weather"
                  "-fwith_xft"
                  "-fwith_xpm"
                ];
              });

            # Latest version of xmobar that still supports Xft font
            xmobar_0_44_2 = dontCheck (appendPatch
              (super.callHackageDirect
                {
                  pkg = "xmobar";
                  ver = "0.44.2";
                  sha256 = "1ka3bbgrgrxdnswjaj1lf6qiz80vygg75bx89wzg6m092wdwxk0h";
                }
                { }) ./xmobar_0_44_2/base_version.patch);

            xmobar_0_43 = dontCheck (super.callHackageDirect
              {
                pkg = "xmobar";
                ver = "0.43";
                sha256 = "1r5yb5278x5984115xrzzfrcdrdy7cifnq5ly3x49hqq8hc5kp7q";
              }
              { });

            termonad = appendPatch
              (super.callHackageDirect
                {
                  pkg = "termonad";
                  ver = "4.6.0.0";
                  sha256 = "1vs0sjlircg70qad6d7mx8qwkr6nlwwnvigc4danqckxjbmdjjhq";
                }
                {
                  inherit (final.pkgs) gtk3;
                  inherit (final.pkgs) pcre2;
                  vte_291 = final.pkgs.vte;
                }) ./termonad/disable_alt_num_keys.patch;
            #let
            #  rev = "fcfcefec04e7157be8c61a398dd7839d9672abd5";
            #  src = prev.fetchFromGitHub {
            #    owner = "cdepillabout";
            #    repo = "termonad";
            #    hash = "sha256-Y4Zm+fzyaEaybfG2i480jrWRfWmi4/JJ1bZaq3QC1zg=";
            #    inherit rev;
            #    postFetch = ''
            #      (cd $out && patch -p1 -i ${./termonad/disable_alt_num_keys.patch})
            #    '';
            #  };
            #in overrideSrc (super.callPackage ./termonad {
            #  inherit (final.pkgs) gtk3;
            #  inherit (final.pkgs) pcre2;
            #  vte_291 = final.pkgs.vte;
            #}) {
            #  inherit src;
            #  version = builtins.substring 0 7 rev;
            #};
            #in overrideCabal (super.callCabal2nix
            #  "termonad"
            #  src
            #  { inherit (prev.pkgs) gtk3;
            #    inherit (prev.pkgs) pcre2;
            #    vte_291 = prev.pkgs.vte;
            #  }
            #) (drv: { version = builtins.substring 0 7 rev; });

          };
        };

        klatexformula = prev.callPackage ./klatexformula { };

        # Fix X11 apps not respecting the cursors.
        # https://github.com/NixOS/nixpkgs/issues/24137
        #xorg =
        #  /*
        #  prev.xorg.overrideScope' (self: super: {
        #    libX11 = super.libX11.overrideAttrs (oldAttrs: {
        #      postPatch = (oldAttrs.postPatch or "") + ''
        #        substituteInPlace src/CrGlCur.c --replace "libXcursor.so.1" "${self.libXcursor}/lib/libXcursor.so.1"
        #      '';
        #    });
        #  });
        #  */
        #  prev.xorg // {
        #    libX11 = prev.xorg.libX11.overrideAttrs (oldAttrs: {
        #      postPatch = (oldAttrs.postPatch or "") + ''
        #        substituteInPlace src/CrGlCur.c --replace "libXcursor.so.1" "${final.xorg.libXcursor}/lib/libXcursor.so.1"
        #      '';
        #    });
        #  };

        #microsoft-edge-stable = prev.callPackage (import ./edge).stable { };
        #microsoft-edge-beta = prev.callPackage (import ./edge).beta { };
        #microsoft-edge-dev = prev.callPackage (import ./edge).dev { };
        mpv-full = prev.mpv-unwrapped.override {
          inherit (prev) lua;
          inherit (prev.darwin.apple_sdk.frameworks) CoreFoundation Cocoa CoreAudio MediaPlayer;
          ffmpeg = prev.ffmpeg-full;
        };

        nixpkgs-manual = prev.callPackage (prev.path + "/doc") { };

        #systemd = prev.systemd.overrideAttrs (oldAttrs: {
        #  mesonFlags = oldAttrs.mesonFlags ++ [ "-Ddns-servers=''" ];
        #});

        weechat = prev.weechat.override {
          configure = { availablePlugins, ... }: {
            plugins = builtins.attrValues availablePlugins;
            scripts = [ final.weechatScripts.weechat-matrix ];
          };
        };

        xmobar_0_44_2 =
          let
            xmobarEnv = final.haskellPackages.ghcWithPackages (self: [ self.xmobar_0_44_2 ]);
          in
          prev.stdenv.mkDerivation {
            pname = "xmobar-with-packages";
            inherit (xmobarEnv) version;

            nativeBuildInputs = [ prev.makeWrapper ];

            buildCommand = ''
              makeWrapper ${xmobarEnv}/bin/xmobar $out/bin/xmobar \
                --prefix PATH : "${xmobarEnv}/bin"
            '';

            # trivial derivation
            preferLocalBuild = true;
            allowSubstitutes = false;
          };

        zathuraPkgs = prev.zathuraPkgs.override {
          useMupdf = true;
        };
      }
  )
]
