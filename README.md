# Pansiyon Yönetim

Flutter ile geliştirilen Windows masaüstü pansiyon yönetim uygulaması. Her pansiyon tek bir `.pansiyon` dosyası olarak saklanır; öğrenci, oda, yoklama ve nöbet kayıtları bu dosya içindeki SQLite veritabanında tutulur.

## Ekranlar

Sol menüde sekiz ekran yer alır:

| Ekran | İçerik |
| --- | --- |
| **Ana Sayfa** | Özet panosu |
| **Öğrenciler** | Kayıt, veli, sağlık, acil iletişim, Excel toplu yükleme |
| **Odalar** | Otomatik oda üretimi ve sürükle-bırak yerleştirme |
| **Etüt Salonları** | Salon tanımı, düzen ve yerleştirme |
| **Yoklama** | Günlük yoklama, evci izni, rapor |
| **Nöbetler** | Nöbet listesi, öğretmenler, ayarlar, istatistik |
| **Disiplin** | Öğrenci disiplin kayıtları |
| **Ayarlar** | Pansiyon bilgileri, dosya işlemleri, yedekleme |

---

## Öğrenciler

- Öğrenci ekleme ve düzenleme (üç adımlı form)
- Veli bilgileri: veli adı, yakınlık, telefon
- Sağlık bilgileri: alerji, sürekli hastalık, ilaç, psikolojik rahatsızlık, kan grubu
- Acil iletişim: acil kişi ve telefon
- Okul, sınıf, şube, okul numarası ve T.C. kimlik no
- Cinsiyet (`Kız` / `Erkek`) — oda yerleştirme kurallarında kullanılır
- Okul yönetimi (okul listesi ekran içinden yönetilir)
- Öğrenci detay ekranı
- **Öğrenci İletişim Bilgileri Formu** çıktısı: kat bazlı gruplanmış öğrenci iletişim ve sağlık bilgileri (telefonlar, kronik hastalık, düzenli ilaç, kan grubu) PDF olarak yazdırılır
- Excel’den toplu yükleme, şablon indirme ve eksik alan önizlemesi

Sınıf seçenekleri pansiyon kademesine göre dinamiktir: **Ortaokul** `5, 6, 7, 8`, **Lise** `Hazırlık, 9, 10, 11, 12`.

---

## Pansiyon Bilgileri (Ayarlar)

Dört adımlı sihirbaz: **Tür → Binalar → Genel Bilgiler → Kontrol**.

- Pansiyon türü: Kız, Erkek, Karma
- Kademe: Ortaokul, Lise
- Blok başına: bölüm, blok adı, standart oda kapasitesi, bodrum kat seçeneği
- Kat başına: oda/etüt salonu varlık anahtarı, öğrenci odası sayısı, etüt salonu sayısı, oda başlangıç numarası
- Kaydedilmemiş değişiklik uyarısı ve **düzenleme kilidi**
- Pansiyon türü değişikliğinde etki analizi: mevcut oda ve yerleştirmeler için uyarı gösterilir, onaylanırsa temizlenir
- Kademe değişikliğinde sınıf listesi güncellenir

---

## Odalar

Pansiyon bilgileri kaydedildikten sonra **Odalar** ekranı açıldığında, öğrenci odası bulunan katlar için oda numaraları **otomatik oluşturulur**. Odalar blok, bölüm ve kat bilgisiyle ayrı gruplar halinde gösterilir.

- Oda kapasitesi oda kartındaki düzenleme ikonundan değiştirilir
- Öğrenci havuzundaki kart oda kartına **sürükle-bırak** ile yerleştirilir; yerleşen öğrenci havuzdan çıkar
- **Cinsiyet ve bölüm kısıtı:** kız öğrenciler yalnızca kız, erkek öğrenciler yalnızca erkek bölümü odalarına yerleşebilir; `Ortak` bölümler her iki gruba açıktır
- Cinsiyeti olmayan öğrenci karma pansiyon odasına yerleştirilemez
- Yanlış bölüme bırakıldığında yerleştirme gerçekleşmez ve ekranda açıklayıcı uyarı çıkar
- Aynı kısıtlar veritabanı katmanında da tekrar kontrol edilir
- Filtreler: dolu oda, kat, sınıf, havuz cinsiyeti
- **Odaları Güncelle** düğmesi ile pansiyon bilgilerinden yeniden senkronizasyon

Kat etiketleri: bodrum yoksa `Zemin Kat, 1. Kat, ...`; bodrum varsa `Bodrum Kat, Zemin Kat, 1. Kat, ...`

---

## Etüt Salonları

- Salon ekleme, düzenleme ve silme
- Oturma düzenleri: **Tekli Sıra**, **Çiftli Sıra**, **U Tipi**, **Grup Çalışma Masası**
- Düzen kolon/satır/U kenarı sayılarıyla büyütülüp küçültülebilir; kapasite otomatik hesaplanır (en fazla 300 kişi)
- Salonun ait olduğu bölüm, blok ve kat seçilir
- Salon haritası üzerinde öğrenci yerleştirme, **Otomatik Yerleştir** ve **Havuza al** işlemleri
- Blok ve kat filtreleri, dar pencerede taşma olmayan düzen

---

## Yoklama

- Günlük yoklama: **Mevcut**, **Evci izinli**, **Raporlu**
- Evci izni ve rapor ekleme diyalogları (başlangıç–bitiş tarihi aralığı ve yoklama çizelgesinde görünen açıklama)
- Öğrenci bazlı yoklama geçmişi
- Kat bazlı izin ve rapor sayıları
- **Pansiyon Yoklama Çizelgesi** PDF çıktısı

---

## Disiplin

- Öğrenci bazlı disiplin kaydı ekleme (tarihli)
- Kayıt listesi ve silme

---

## Nöbetler

Dört sekme:

**Nöbet Listeleri** — yıl/ay seçimi, manuel veya **Otomatik Dağıt** ile liste oluşturma, ay bazında listeler, **Çıktı Al** (yazdırma/PDF), liste silme.

**Nöbet Ayarları** — bölüm, blok ve kat bazında nöbet yerleri, kara dönem (tatil) tanımları, öğretmen-ay bazlı izin günleri.

**Öğretmenler** — öğretmen ekleme/düzenleme/silme; T.C. kimlik, telefon, okul, branş, nöbet eğitimi, nöbet tercihi (Minimum / Dengeli / Maksimum), müsait günler, aktiflik. **Excel’den toplu yükleme** ve **şablon indirme**.

**İstatistikler** — öğretmen ve ay bazında nöbet sayıları.

Otomatik dağıtım; nöbet tercihi, müsait günler, kara dönemler ve aylık izinleri dikkate alır.

---

## Ayarlar

- Pansiyon bilgileri sihirbazı ve özet görünümü
- **Pansiyon Dosyası Aç** ve **Yeni Pansiyon Oluştur**
- Veritabanı yedeği alma
- Kaydedilmemiş değişiklik kontrolü

---

## Pansiyon Dosyası (`.pansiyon`)

Her pansiyon tek dosyada tutulur; dosya açıldığında uygulama o dosyanın veritabanını kullanır.

- **Yeni Pansiyon Oluştur** — boş `.pansiyon` dosyası üretir
- **Pansiyon Dosyası Aç** — dosya seçilir, sürümü doğrulanır ve açılır
- Eski sürümlü dosyalar açılırken otomatik olarak güncel şemaya yükseltilir
- Yükseltmeden önce dosyanın yanına **otomatik yedek** kopyası yazılır (mevcut yedeğin üzerine yazılmaz)
- Daha önce kullanılan veritabanı dosyası `.pansiyon` formatına dönüştürülebilir

---

## Excel Öğrenci Yükleme

Öğrenci ekranındaki **Excel** düğmesi `.xlsx` dosyası seçer. İlk satır başlık, sonraki satırlar öğrenci verisi olarak okunur.

Zorunlu alan:

- Ad Soyad

Tanınan başlıklardan bazıları:

- Ad Soyad, Cinsiyet, T.C. Kimlik No, Okul, Sınıf, Şube, Okul No
- Doğum Tarihi, Adres, Telefon
- Anne Adı, Baba Adı, Anne Telefonu, Baba Telefonu
- Alerji, Sürekli Hastalık, İlaç, Psikolojik Rahatsızlık
- Veli Adı, Yakınlık, Veli Telefonu
- Acil Kişi, Acil Telefon, Pansiyon Kayıt Tarihi

Ad Soyad dolu olmayan satırlar eklenmez. Diğer eksik alanlar içe aktarma öncesi önizlemede uyarı olarak gösterilir; öğrenci yine de eklenebilir. Excel’de geçen okul adları mevcut okul listesinde yoksa içe aktarma sırasında otomatik oluşturulur.

---

## Çalıştırma

```powershell
flutter pub get
flutter run -d windows
```

## Kontrol

```powershell
flutter analyze
flutter test
flutter build windows --debug
```

## Veritabanı

SQLite, şema sürümü **15**. Sürüm yükseltmeleri `lib/core/database/app_database.dart` içindeki `onUpgrade` zincirinde toplanır; eski veritabanları açılışta otomatik yükseltilir.

| Sürüm | İçerik |
| --- | --- |
| 2 | İndeksler |
| 3 | Öğrenci, okul, yoklama ve disiplin tabloları |
| 4–5 | Pansiyon oda/kat alanları, bodrum ve oda başlangıç numarası |
| 6 | `boarding_rooms` ve `room_assignments` |
| 7 | Öğrenci cinsiyeti |
| 8 | Öğrenci benzersizlik indeksleri |
| 9 | Hazırlık sınıfı |
| 10–11 | Etüt salonu tabloları ve düzen alanları |
| 12 | Kan grubu |
| 13–15 | Nöbet tabloları |

## Sorun Giderme

### Windows derlemesi pdfium indirirken hata veriyor

`printing` eklentisi, ilk Windows derlemesinde pdfium kitaplığını GitHub üzerinden indirir. Ağ ortamında sertifika iptal denetimine (CRL/OCSP) ulaşılamıyorsa CMake boş dosya bırakıp derlemeyi durdurur:

```
Build step for pdfium failed
schannel: next InitializeSecurityContext failed: CRYPT_E_NO_REVOCATION_CHECK
```

Bu bir kod hatası değil, ağ ortamı kaynaklıdır ve **aralıklı** görünür: aynı
komut bazen çalışıp bazen başarısız olabilir.

Önce derlemeyi yeniden deneyin. Sorun devam ederse kalıcı çözüm, pdfium arşivini
`curl` ile indirip eklentiyi yerel dosyaya yönlendiren betiktir:

```powershell
powershell -ExecutionPolicy Bypass -File tool/setup_printing_pdfium.ps1
flutter build windows --debug
```

> **Dikkat:** `windows/flutter/ephemeral/.plugin_symlinks/printing` bir sembolik
> bağdır; betik pub cache'teki gerçek dosyayı düzenler. Bu klasör bu
> makinedeki tüm Flutter projeleri tarafından paylaşılır. Betik özgün dosyayı
> `tool/cache/printing-CMakeLists.txt.orig` altında yedekler ve geri alma
> seçeneği sunar. Projeyi silmeden önce mutlaka geri alın:
>
> ```powershell
> powershell -ExecutionPolicy Bypass -File tool/setup_printing_pdfium.ps1 -Restore
> ```

İlk başarılı derlemeden sonra bu adım bir daha çalışmaz; araç dosyaları `build/`
altında önbelleğe alınır.

### Derleme "Yönetici izni gerekiyor" hatası veriyor

```
file cannot create directory: C:/Program Files/pansiyon_yonetim
```

Eklenti adımı başarısız olduğunda CMake yapılandırması yarıda kalır ve kurulum
ön eki `C:/Program Files/<proje>` olarak önbelleğe yazılır. `windows/CMakeLists.txt`
bu değeri de varsayılan olarak ele alıp derleme dizinine sabitlediği için artık
bu hatayı almazsınız. Önbellek zaten bozulduysa bir kez `flutter clean` yeterlidir.

> Uygulama çalışırken yeniden derleme yapılamaz; derleme sırasında
> `runner/Debug` klasöründeki eklenti dosyaları kilitlenir ve
> `Permission denied` hatası alırsınız. Derlemeden önce uygulamayı kapatın.
