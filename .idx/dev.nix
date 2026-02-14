# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"

  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.flutter
    pkgs.python3
    pkgs.php
    pkgs.composer
    pkgs.nodejs_20
  ];

  # Sets environment variables in the workspace
  env = {};
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "dart-code.flutter"
      "dart-code.dart-code"
    ];

    # Enable previews
    previews = {
      enable = true;
      previews = {
        web = {
          command = [ "sh" "-c" ''cd smartfarm_xr && flutter run -d web-server --web-port=$PORT'' ];
          manager = "web";
        };
      };
    };

    # Workspace lifecycle hooks
    workspace = {
      # Runs when a workspace is first created
      onCreate = {
        install-py-root-deps = "pip install -r requirements.txt";
        install-py-backend-deps = "pip install -r backend/requirements.txt";
        install-flutter-deps = "cd smartfarm_xr && flutter pub get";
        install-php-deps = "composer install";
      };
      # Runs when the workspace is (re)started
      onStart = {
        # Example: start a background task to watch and re-build backend code
        # watch-backend = "npm run watch-backend";
      };
    };
  };
}
