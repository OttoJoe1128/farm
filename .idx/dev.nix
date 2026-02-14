{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = [
    pkgs.python311
    pkgs.python311Packages.fastapi
    pkgs.python311Packages.uvicorn
    pkgs.python311Packages.python-multipart
    pkgs.python311Packages.pip  # Bunu da ekleyelim ne olur ne olmaz
    pkgs.flutter
  ];
  idx.previews = {
    enable = true;
    previews = {
      # Burası kalsın
    };
  };
}