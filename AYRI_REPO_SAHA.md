# Saha uygulamasını (SmartFarm Field) ayrı repoya çıkarma

Bu repodan `smartfarm_field` klasörünü ayrı bir Git reposuna taşımak için aşağıdaki adımları **sırayla** uygula.

---

## 1. Yeni repo oluştur (GitHub)

- GitHub’da yeni bir repo oluştur (örn. `smartfarm-field` veya `farm-field`).
- **Boş** olsun (README, .gitignore ekleme).
- Repo URL’ini not et: `https://github.com/KULLANICI/smartfarm-field.git`

---

## 2. Mevcut repoda saha uygulamasını ayrı dalda çıkar

**Farm reponun kökünde** (terminalde `~/farm` veya `farm-main/farm`):

```bash
cd ~/farm
git fetch origin
git checkout main
git pull origin main
# Sadece smartfarm_field geçmişini içeren dal
git subtree split -P smartfarm_field -b field-only
```

Bu komut `field-only` adlı bir dal oluşturur; içinde yalnızca `smartfarm_field` vardır ve proje kökü o dalda `smartfarm_field` klasörünün içeriği gibi görünür (dalın kökü = eski smartfarm_field içeriği).

---

## 3. Yeni repoya push et

Yeni repoyu remote olarak ekleyip bu dalı orada `main` yap:

```bash
git remote add field-repo https://github.com/KULLANICI/smartfarm-field.git
git push field-repo field-only:main
```

`KULLANICI` ve `smartfarm-field` kısmını kendi repo adresinle değiştir.

---

## 4. Farm repodan `smartfarm_field` kaldır

Aynı farm reposunda:

```bash
git checkout main
git rm -r smartfarm_field
# Dokümanlar zaten güncellenmiş olacak; commit’e dahil et
git add -A
git status
git commit -m "smartfarm_field ayrı repoya tasindi; saha uygulamasi artik field-repo"
git push origin main
```

Bundan sonra bu repo (farm) içinde `smartfarm_field` klasörü olmaz; saha uygulaması sadece yeni repoda kalır.

---

## 5. Yeni IDX’te saha repoyu kullan

- Yeni bir IDX workspace aç.
- Repo olarak **yeni oluşturduğun saha reposunu** seç (`smartfarm-field`).
- Clone edince proje kökü doğrudan saha uygulaması olur; `flutter pub get`, `flutter build apk` bu kök dizinde çalıştırılır.
- Backend bu IDX’te olmayacağı için `api_config` / ortam değişkeninde API URL’ini farm backend’ine (diğer IDX veya sunucu) yönlendir.

---

## Özet

| Nerede | Ne var? |
|--------|--------|
| **Farm repo** (bu repo) | Backend + SmartFarm XR; `smartfarm_field` yok. |
| **Yeni repo** (smartfarm-field) | Sadece SmartFarm Field (saha uygulaması). |

İşlevsellik aynı kalır: saha uygulaması API URL’i ile farm backend’ine bağlanır.
