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
  ];
  idx = {
    extensions = [
      "Dart-Code.dart-code"
      "Dart-Code.flutter"
    ];
    previews = { enable = true; previews = {}; };
  };
}
