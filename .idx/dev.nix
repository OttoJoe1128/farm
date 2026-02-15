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
