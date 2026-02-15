# SmartFarm Field – Test ve APK Prosedürü

Bu dokümanda: backend kurulumu, emülatörde test, APK üretme adımları var.

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

### 2a. Flutter bağımlılıkları

```bash
cd ~/farm/smartfarm_field
flutter pub get
```

### 2b. Emülatörü aç

- Android Studio: AVD Manager’dan bir cihaz başlat, veya  
- IDX içinde emülatör zaten açıksa devam et.

Cihazları görmek için:

```bash
flutter devices
```

### 2c. Uygulamayı çalıştır

```bash
cd ~/farm/smartfarm_field
flutter run
```

Birden fazla cihaz varsa:

```bash
flutter run -d <cihaz_id>
```

Emülatör backend’e `10.0.2.2:8000` üzerinden erişir (varsayılan ayar buna uygun).

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
