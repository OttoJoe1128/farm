{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = [
    pkgs.python311
    pkgs.python311Packages.fastapi
    pkgs.python311Packages.uvicorn
    pkgs.python311Packages.python-multipart
    pkgs.python311Packages.pip
    pkgs.flutter
    pkgs.jdk17
    # Flutter Linux build
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.gcc
    pkgs.clang
    # GTK3 + pkg-config .pc (Flutter Linux)
    pkgs.gtk3
    pkgs.gtk3.dev
    pkgs.glib
    pkgs.glib.dev
    pkgs.pango
    pkgs.pango.dev
    pkgs.cairo
    pkgs.cairo.dev
    pkgs.gdk-pixbuf
    pkgs.gdk-pixbuf.dev
    pkgs.atk
    pkgs.atk.dev
  ];
  env = [
    "PKG_CONFIG_PATH=${pkgs.gtk3.dev}/lib/pkgconfig:${pkgs.glib.dev}/lib/pkgconfig:${pkgs.pango.dev}/lib/pkgconfig:${pkgs.cairo.dev}/lib/pkgconfig:${pkgs.gdk-pixbuf.dev}/lib/pkgconfig:${pkgs.atk.dev}/lib/pkgconfig"
  ];
  idx = {
    extensions = [
      "Dart-Code.dart-code"
      "Dart-Code.flutter"
    ];
    previews = {
      enable = true;
      previews = {};
    };
    workspace = {
      onCreate = {
        field-pub-get = "cd smartfarm_field && flutter pub get";
      };
    };
  };
}
