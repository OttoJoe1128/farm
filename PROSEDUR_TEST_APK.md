# SmartFarm Field – Test ve APK Prosedürü

Bu dokümanda: backend kurulumu, emülatörde test, APK üretme adımları var.

**IDX’te repo güncellerken** `git pull` “Your local changes would be overwritten” derse:  
`git checkout -- .idx/install_android_studio.sh` (veya ilgili dosya) sonra `git pull origin main`.

---

## 1. Backend kurulumu ve çalıştırma

### 1a. Sanal ortam (önerilir)

```bash
cd ~/farm/backend
python3 -m venv .venv
source .venv/bin/activate   # Linux/macOS
# Windows: .venv\Scripts\activate
```

### 1b. Bağımlılıkları yükle

**Seçenek A – Minimal (sadece API/auth):**

```bash
pip install -r requirements-backend.txt
```

**Seçenek B – Projedeki tam liste (GIS vb. dahil):**

```bash
pip install -r requirements.txt
```

### 1c. Backend’i başlat

**Yöntem 1 – Script ile (önerilen):**

```bash
cd ~/farm/backend
chmod +x start.sh
./start.sh
```

**Yöntem 2 – Tek satır:**

```bash
cd ~/farm/backend
kill $(lsof -t -i:8000) 2>/dev/null; python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend açıldığında: `http://0.0.0.0:8000` ve `http://127.0.0.1:8000/docs` (Swagger) kullanılabilir olmalı.

---

## 2. Emülatörde uygulamayı test etme

Backend’in 8000’de çalıştığını varsayıyoruz.

**Öneri:** Uygulama Android için tasarlandığı için **Android emülatör** kullanmak en sorunsuz yoldur. IDX `dev.nix` içinde Android SDK tanımlı; ortamı rebuild ettikten sonra emülatör kullanılabilir.

### 2a. Flutter bağımlılıkları

```bash
cd ~/farm/smartfarm_field
flutter pub get
```

### 2b. Cihaz / platform

- **Android emülatör (önerilen):** IDX ortamında Android SDK vardır. `flutter devices` ile emülatörü görüyorsan doğrudan `flutter run` yeterli. Emülatör yoksa bir AVD oluşturup başlatın (aşağıda kısa not var).
- **Linux masaüstü:** GTK/Nix ortamı gerektirir; sorun yaşanırsa Android emülatör tercih edin.

Cihazları görmek için:

```bash
flutter devices
```

### 2c. Uygulamayı çalıştır

**Android (emülatör veya fiziksel cihaz) – önerilen:**

```bash
cd ~/farm/smartfarm_field
flutter run
```

Birden fazla cihaz varsa: `flutter run -d <cihaz_id>`

**Linux (sadece emülatör yoksa, opsiyonel):**

```bash
cd ~/farm/smartfarm_field
./run_linux.sh
# veya: flutter run -d linux
```

Birden fazla cihaz varsa:

```bash
flutter run -d <cihaz_id>
```

Emülatör backend’e `10.0.2.2:8000` üzerinden erişir. Linux’ta backend `127.0.0.1:8000` ise varsayılan ayar yeterli; gerekirse `export SMARTFARM_API_URL=http://127.0.0.1:8000/api/v1` kullan.

### 2d. Android emülatör (AVD) yoksa

IDX/Nix ortamında Android SDK kuruluysa, komut satırından örnek bir AVD oluşturup çalıştırabilirsin (SDK’daki `avdmanager` / `emulator` yolu ortama göre değişir). Alternatif olarak bilgisayarında Android Studio kuruluysa AVD Manager’dan emülatör oluşturup başlatıp `flutter run` ile bağlanabilirsin.

### 2e. IDX: Ortam açıldıktan sonra Android SDK kurulumu (script)

`dev.nix` ortamı Android Studio/unfree içermediği için ortamın build olması hedeflenir; Android SDK ve emülatör ortam **açıldıktan sonra** script ile kurulur.

1. Workspace’i aç, ortamın “Ready” olmasını bekle.
2. Terminalde:

```bash
cd ~/farm
chmod +x .idx/install_android_studio.sh
.idx/install_android_studio.sh
```

3. Script bittikten sonra aynı oturumda (veya yeni terminalde env’i yükleyip):

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH
```

4. AVD oluştur ve başlat:

```bash
echo no | avdmanager create avd -n Pixel_34 -k "system-images;android-34;google_apis;x86_64" -d pixel
emulator -avd Pixel_34 -no-snapshot-load &
```

5. Emülatör açıldıktan sonra `flutter devices` ile görünüp `flutter run` ile uygulamayı çalıştırabilirsin.

**Sorun giderme (2e):**

- **"Package path is not valid. Valid system image paths are: null"**  
  Lisanslar onaylanmamış veya sistem imajı inmemiş olabilir. Şunu çalıştırıp tekrar AVD oluştur:

  ```bash
  yes | sdkmanager --sdk_root=$ANDROID_HOME --licenses
  sdkmanager --sdk_root=$ANDROID_HOME "system-images;android-34;google_apis;x86_64"
  echo no | avdmanager create avd -n Pixel_34 -k "system-images;android-34;google_apis;x86_64" -d pixel
  ```

- **"libX11.so.6: cannot open shared object file"**  
  Ortamda X11 kütüphaneleri yok. `dev.nix` içine X11 paketleri eklendi; değişikliği alıp IDX ortamını **Rebuild** et (Environment → Rebuild). Sonra emülatörü tekrar başlat. IDX headless ise emülatör penceresi açılmayabilir; bu durumda APK build edip fiziksel cihazda test edebilirsin.

- **"No space left on device"**  
  IDX workspace diskte yer kalmamış. Sistem imajı (~1 GB+) atlanıp sadece APK derlenebilir:  
  `SKIP_SYSTEM_IMAGE=1 .idx/install_android_studio.sh`  
  Aynı terminalde `export ANDROID_HOME=$HOME/Android/Sdk` ve `export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH` yap. Emülatör olmadan doğrudan `cd ~/farm/smartfarm_field && flutter build apk --release` ile APK al.

- **"sdkmanager: command not found"**  
  Script’i çalıştırdığın terminalde PATH zaten ayarlı; **yeni açtığın terminalde** mutlaka şunu yaz:  
  `export ANDROID_HOME=$HOME/Android/Sdk` ve  
  `export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH`  
  Nix’ın önerdiği `pkgs.python312Packages.sdkmanager` **Android SDK değil**; onu kurma, Android’in kendi sdkmanager’ını kullan (yukarıdaki PATH ile).

- **"mv: inter-device move failed"**  
  Script güncellendi (artık `cp` kullanıyor). `git pull` alıp script’i tekrar çalıştır. Önceki yarım kurulumu silmek için: `rm -rf ~/Android/Sdk/cmdline-tools/latest` sonra script’i tekrar çalıştır.

---

## 3. APK üretme

Release APK:

```bash
cd ~/farm/smartfarm_field
flutter build apk --release
```

APK yolu:

```
~/farm/smartfarm_field/build/app/outputs/flutter-apk/app-release.apk
```

Debug APK (daha hızlı, test için):

```bash
flutter build apk --debug
```

---

## 4. Özet komut sırası

```bash
# Terminal 1 – Backend
cd ~/farm/backend
./start.sh

# Terminal 2 – Test
cd ~/farm/smartfarm_field
flutter pub get
flutter run

# APK için (test bittikten sonra)
cd ~/farm/smartfarm_field
flutter build apk --release
```

---

## 5. Sık karşılaşılanlar

| Sorun | Çözüm |
|--------|--------|
| `Address already in use` | `kill $(lsof -t -i:8000)` veya `./start.sh` kullan. |
| Emülatörde “bağlantı hatası” | Backend’in `0.0.0.0:8000` ile çalıştığından emin ol; emülatör için URL `http://10.0.2.2:8000/api/v1`. |
| Firebase hatası | `flutterfire configure` çalıştırıp `google-services.json` ve `saha_firebase_options.dart` güncelle. |
| APK imzasız | Release APK varsayılan debug keystore ile imzalıdır; dağıtım için kendi keystore’unu ekleyebilirsin. |
