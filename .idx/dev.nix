# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  channel = "unstable";

  packages = [
    pkgs.flutter
    pkgs.python3
    pkgs.python3Packages.pip
    pkgs.php
    pkgs.composer
    pkgs.nodejs_20
    pkgs.cmake
  ];

  env = {};

  idx = {
    extensions = [
      "dart-code.flutter"
      "dart-code.dart-code"
    ];

    previews = {
      enable = true;
      previews = {
        web = {
          command = [ "sh" "-c" '''
            cd smartfarm_xr && flutter run -d web-server --web-port=$PORT
          ''' ];
          manager = "web";
        };
      };
    };

    workspace = {
      onCreate = {
        install-py-root-deps = "pip install -r requirements.txt";
        install-py-backend-deps = "pip install -r backend/requirements.txt";
        install-flutter-deps = "cd smartfarm_xr && flutter pub get";
        install-php-deps = "composer install";
      };
      onStart = {};
    };
  };
}
