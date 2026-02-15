#!/bin/bash
# IDX icinde Android SDK + emulator kurar (dev.nix unfree kullanmadigi icin ortam build olur,
# bu scripti ortam acildiktan sonra bir kez calistirirsin).
# Kullanim: .idx/install_android_studio.sh
set -e
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
mkdir -p "$ANDROID_HOME"
CMD_TOOLS_ZIP="$HOME/cmdline-tools.zip"
# Google'in resmi command-line tools (Linux) - versiyon guncel olabilir
CMD_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
echo "Android command-line tools indiriliyor..."
if ! wget -q --spider "$CMD_TOOLS_URL" 2>/dev/null; then
  echo "Uyari: $CMD_TOOLS_URL erisilemedi."
  echo "Manuel: https://developer.android.com/studio#command-line-tools-only adresinden"
  echo "  'Command line tools only' Linux indirip bu scripti tekrar calistirin (zip dosyasi $CMD_TOOLS_ZIP konumunda olmali)."
  exit 1
fi
wget -O "$CMD_TOOLS_ZIP" "$CMD_TOOLS_URL"
echo "Aciliyor..."
TMP_UNZIP=$(mktemp -d)
unzip -q -o "$CMD_TOOLS_ZIP" -d "$TMP_UNZIP"
rm -f "$CMD_TOOLS_ZIP"
mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ -d "$TMP_UNZIP/cmdline-tools" ]; then
  mv "$TMP_UNZIP/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
else
  mv "$TMP_UNZIP"/* "$ANDROID_HOME/cmdline-tools/latest" 2>/dev/null || mv "$TMP_UNZIP" "$ANDROID_HOME/cmdline-tools/latest"
fi
rm -rf "$TMP_UNZIP"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
echo "SDK paketleri yukleniyor..."
yes | sdkmanager --sdk_root="$ANDROID_HOME" "platform-tools" "emulator" "platforms;android-34" "system-images;android-34;google_apis;x86_64" 2>/dev/null || true
echo "ANDROID_HOME=$ANDROID_HOME"
echo "Kurulum bitti. Shell'e ekleyin: export ANDROID_HOME=$ANDROID_HOME"
echo "AVD olusturmak icin: avdmanager create avd -n Pixel_34 -k 'system-images;android-34;google_apis;x86_64' -d pixel_7"
echo "Emulator baslatmak icin: emulator -avd Pixel_34 &"
