# Saha uygulamasi (SmartFarm Field) + backend - minimal (her zaman build olur)
# Android Studio: ortam acildiktan sonra .idx/install_android_studio.sh calistir
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
    pkgs.wget
    pkgs.unzip
    pkgs.cmake
    pkgs.clang
    # Emulator icin X11 (libX11.so.6 vb.)
    pkgs.xorg.libX11
    pkgs.xorg.libXext
    pkgs.xorg.libxcb
    pkgs.xorg.libXrandr
    pkgs.xorg.libXi
    pkgs.xorg.libXrender
    pkgs.xorg.libXtst
  ];
  idx = {
    extensions = [
      "Dart-Code.dart-code"
      "Dart-Code.flutter"
    ];
    previews = { enable = true; previews = {}; };
  };
}
