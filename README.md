# Pansiyon Yönetim

Flutter ile geliştirilen Windows masaüstü pansiyon yönetim uygulaması.

## Özellikler

- Pansiyon bilgileri ve bina/kat formu (her kat için oda başlangıç numarası, blok bazında bodrum kat seçeneği)
- Öğrenci listesi, ekleme ve düzenleme
- Okul listesi yönetimi
- Öğrenci veli, sağlık ve acil iletişim bilgileri
- Günlük yoklama: Mevcut, Evci izinli, Raporlu
- İzin ekleme ve rapor ekleme diyalogları
- Disiplin kaydı alanı
- Excel’den toplu öğrenci yükleme ve eksik alan önizlemesi

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

- Ad Soyad, T.C. Kimlik No, Okul, Sınıf, Şube, Okul No
- Doğum Tarihi, Adres, Telefon
- Anne Adı, Baba Adı, Anne Telefonu, Baba Telefonu
- Alerji, Sürekli Hastalık, İlaç, Psikolojik Rahatsızlık
- Veli Adı, Yakınlık, Veli Telefonu
- Acil Kişi, Acil Telefon, Pansiyon Kayıt Tarihi

Ad Soyad dolu olmayan satırlar eklenmez. Diğer eksik alanlar içe aktarma öncesi önizlemede uyarı olarak gösterilir; öğrenci yine de eklenebilir. Excel’de geçen okul adları mevcut okul listesinde yoksa içe aktarma sırasında otomatik oluşturulur.
