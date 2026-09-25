# Pansiyon Yönetim

Flutter ile geliştirilen Windows masaüstü pansiyon yönetim uygulaması.

## Özellikler

- Pansiyon bilgileri ve bina/kat formu (her kat için oda/etüt salonu varlık anahtarları, oda başlangıç numarası ve blok bazında bodrum kat seçeneği)
- Öğrenci listesi, ekleme ve düzenleme
- Okul listesi yönetimi
- Öğrenci veli, sağlık ve acil iletişim bilgileri
- Öğrenci cinsiyet bilgisi ve karma pansiyon bölümlerine göre oda yerleştirme kısıtları
- Günlük yoklama: Mevcut, Evci izinli, Raporlu
- İzin ekleme ve rapor ekleme diyalogları
- Disiplin kaydı alanı
- Excel’den toplu öğrenci yükleme ve eksik alan önizlemesi
- Pansiyon bilgilerinden otomatik oda oluşturma, kapasite düzenleme ve sürükle-bırak öğrenci yerleştirme

## Odalar

Pansiyon bilgileri kaydedildikten sonra **Odalar** ekranı açıldığında, öğrenci odası bulunan katlar için oda numaraları otomatik oluşturulur. Odalar blok, bölüm ve kat bilgisiyle ayrı gruplar halinde gösterilir. Oda kapasitesi oda kartındaki düzenleme ikonundan değiştirilebilir.

Öğrenci havuzundaki öğrenci kartı oda kartına sürüklenerek yerleştirilir. Yerleştirilen öğrenci havuzdan çıkar ve odanın kapasitesi kadar öğrenci alınabilir. Karma pansiyonlarda kız öğrenciler yalnızca kız bölümü odalarına, erkek öğrenciler yalnızca erkek bölümü odalarına yerleştirilebilir. Dolu oda ve kat filtreleri ile sınıf filtreleri aynı ekranda kullanılabilir. Pansiyon kademesi **Lise** seçilirse sınıf seçenekleri `Hazırlık, 9, 10, 11, 12`; **Ortaokul** seçilirse `5, 6, 7, 8` olarak gelir.

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
