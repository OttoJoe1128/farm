# SmartFarm: İki Uygulama – Sunum Özeti

Bu dokümanda projedeki **iki kullanıcı uygulaması** ve **ortak backend** kısaca anlatılıyor. Sunum veya üst yönetime anlatım için kullanılabilir.

---

## Genel bakış

| Bileşen | Ne? | Kim kullanır? | Nerede çalışır? |
|--------|-----|----------------|------------------|
| **SmartFarm Field** | Saha veri toplama uygulaması | Saha ekipleri, tarla/parselde çalışanlar | Android telefon/tablet (APK) |
| **SmartFarm XR** | Harita ve yönetim paneli | Ofis, planlama, yönetim | Web tarayıcı (masaüstü) |
| **Backend** | API + Admin panel + XR’i sunar | Sistem / yöneticiler | Sunucu (örn. 8000 portu) |

İki uygulama da **aynı backend’e** bağlanır; veriler tek merkezde toplanır.

---

## 1) SmartFarm Field – Saha uygulaması

**Ne işe yarar?**  
Tarlada/parselde **canlı veri toplama**: konum, fotoğraf, varlık (bitki, tesis, vb.) kaydı. Veriler anında veya senkron ile backend’e gider.

**Kim kullanır?**  
Saha personeli, teknisyenler, denetçiler – işi sahada yapan ekip.

**Nasıl çalıştırılır?**  
- **Android cihaza APK kurulur** (`smartfarm_field` projesinden `flutter build apk --release` ile üretilir).  
- Gerekirse emülatörde veya Linux’ta da test edilebilir; asıl kullanım **telefon/tablet**.

**Özet cümle (sunumda):**  
*“Saha uygulaması, ekiplerin tarlada anlık veri girmesini ve fotoğraf/varlık kaydı yapmasını sağlar; tüm veri merkezî backend’e iletilir.”*

---

## 2) SmartFarm XR – Harita ve yönetim paneli

**Ne işe yarar?**  
- Parselleri **haritada** yönetmek,  
- **Uydu görüntüsü** ile parsel üzerinde çalışmak,  
- **Dijital ikiz** mantığıyla parsel/varlık görüntüleme,  
- Ölçüm, snap, çoklu parsel yükleme gibi ofis tarafı işler.

**Kim kullanır?**  
Ofis kullanıcıları, planlama ve yönetim – masaüstü tarayıcıda çalışır.

**Nasıl çalıştırılır?**  
- Backend **tek portta** (örn. 8000) hem API’yi hem XR web uygulamasını sunar.  
- `smartfarm_xr` projesinde `flutter build web` yapılır; çıkan dosyalar backend ile aynı adreste servis edilir.  
- Kullanıcı tarayıcıda `https://.../` açarak hem haritayı hem yönetim ekranlarını kullanır.

**Özet cümle (sunumda):**  
*“Yönetim paneli, parselleri harita ve uydu görüntüsüyle yönetmek, varlıkları ofisten takip etmek için kullanılır; web üzerinden erişilir.”*

---

## 3) Backend – Ortak altyapı

**Ne işe yarar?**  
- **API:** Saha uygulaması ve XR paneli veriyi buradan alır/gönderir.  
- **Admin paneli:** `/admin/login` – kullanıcı/yetki ve sistem yönetimi.  
- **XR web uygulaması:** Build edilmiş Flutter web dosyalarını sunar (tek port).

**Özet cümle (sunumda):**  
*“Tüm veri ve işlemler tek bir backend üzerinden yürür; saha uygulaması ve yönetim paneli aynı API’yi kullanır.”*

---

## Sunumda kullanılabilecek tek paragraf

*“Projede iki uygulama var: **SmartFarm Field** sahada, Android cihazlarda çalışan veri toplama uygulaması; **SmartFarm XR** ise ofiste, tarayıcıda kullanılan harita ve yönetim paneli. İkisi de aynı backend’e bağlanıyor: sahadan giren veriler merkezde toplanıyor, yönetim panelinden harita ve uydu görüntüsüyle takip edilebiliyor.”*

---

## Teknik isimlendirme (referans)

- **Saha uygulaması:** `smartfarm_field` (Flutter, Android APK). Ayrı repoya taşınmış olabilir; bakınız `AYRI_REPO_SAHA.md`.  
- **Yönetim paneli / harita:** `smartfarm_xr` (Flutter Web, backend üzerinden sunulur).  
- **Sunucu:** `backend` (FastAPI; API, admin, XR static dosyaları).
