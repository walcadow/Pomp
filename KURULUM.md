# Pomp – Adım Adım Kurulum Rehberi (Windows)

Bu rehber hiç yazılım deneyimi olmayan biri için yazıldı. Adımları **sırasıyla** yapın.
Bir yerde takılırsanız, ekrandaki hata mesajını kopyalayıp Claude'a yapıştırın.

Klasör yapısı:

```
POMP\
├── KURULUM.md          ← bu dosya
├── docker-compose.yml  ← sunucuyu ve veritabanını başlatır
├── .env.example        ← ayarlar (yayına alırken değiştirilecek)
├── server\             ← sunucu (Node.js)
└── mobile\             ← telefon uygulaması (Flutter)
```

Uygulama iki parçadan oluşur:
1. **Sunucu**: kullanıcıları, fotoğrafları, eşleşmeleri ve mesajları saklar. Önce bunu çalıştıracağız.
2. **Mobil uygulama**: telefonda açılan Pomp uygulaması. Sunucuya bağlanır.

---

## BÖLÜM 1 – Sunucuyu çalıştırmak (yaklaşık 20 dakika)

### 1.1 Docker Desktop'ı kurun
Docker, sunucuyu ve veritabanını tek tıkla çalıştırmanızı sağlayan bir programdır.

1. https://www.docker.com/products/docker-desktop/ adresine gidin, **Download for Windows**'a tıklayın.
2. İndirilen dosyayı çalıştırın, varsayılan ayarlarla kurun. Bilgisayarı yeniden başlatmanız istenebilir.
3. Docker Desktop'ı açın. Sol altta **Engine running** (yeşil) yazısını görene kadar bekleyin.

### 1.2 PowerShell'i POMP klasöründe açın
1. Masaüstündeki **POMP** klasörünü açın.
2. Klasörün içinde boş bir yere **Shift tuşuna basılı tutarak sağ tıklayın**.
3. **"PowerShell penceresini burada açın"** (veya "Terminalde aç") seçeneğine tıklayın.

### 1.3 Sunucuyu başlatın
PowerShell penceresine şu komutları **tek tek** yapıştırıp Enter'a basın:

```powershell
copy .env.example .env
docker compose up -d --build
```

İlk seferde indirme yapacağı için birkaç dakika sürebilir. Bitince test edin:
tarayıcıda **http://localhost:3000/health** adresini açın. Ekranda `{"ok":true}` görüyorsanız sunucu çalışıyor. 🎉

> Sunucuyu durdurmak için: `docker compose down`
> Tekrar başlatmak için: `docker compose up -d`
> Hata kayıtlarını görmek için: `docker compose logs api`

---

## BÖLÜM 2 – Mobil uygulamayı çalıştırmak (yaklaşık 1 saat)

### 2.1 Flutter'ı kurun
1. https://docs.flutter.dev/get-started/install/windows/mobile adresindeki adımları izleyin.
   Kısaca: Flutter SDK'yı indirip `C:\flutter` klasörüne çıkarın ve `C:\flutter\bin` yolunu **PATH**'e ekleyin.
2. **Android Studio**'yu kurun: https://developer.android.com/studio
3. Android Studio'yu açın, kurulum sihirbazını varsayılan ayarlarla bitirin.
4. Yeni bir PowerShell penceresi açıp şunu çalıştırın:
   ```powershell
   flutter doctor --android-licenses
   ```
   Her soruya `y` yazıp Enter'a basın.
5. Sonra şunu çalıştırın:
   ```powershell
   flutter doctor
   ```
   **Flutter** ve **Android toolchain** satırlarının yanında yeşil ✓ görmelisiniz.

### 2.2 Android emülatörü (sanal telefon) oluşturun
1. Android Studio → **More Actions** → **Virtual Device Manager**.
2. **Create Device** → **Pixel 8** (veya herhangi biri) → **Next** → önerilen sistem görüntüsünü indirin → **Finish**.
3. Listede oluşan cihazın yanındaki ▶ düğmesine basarak sanal telefonu başlatın.

### 2.3 Uygulama projesini tamamlayın
PowerShell'de **mobile** klasörüne geçin ve şu komutları tek tek çalıştırın:

```powershell
cd $HOME\Desktop\POMP\mobile
flutter create --org com.walcadow --project-name pomp --platforms android,ios .
flutter pub get
```

> `flutter create` komutu, Android ve iOS için gereken eksik dosyaları oluşturur.
> Mevcut dosyalarımızın üzerine yazmaz.

### 2.4 Uygulamayı başlatın
Sanal telefon açıkken:

```powershell
flutter run
```

İlk derleme 5–10 dakika sürebilir. Sonra sanal telefonda **Pomp** açılır.

---

## BÖLÜM 3 – Denemek

1. Uygulamada **Hesap oluştur**'a dokunun ve kayıt olun.
2. **En az bir fotoğraf ekleyin.** Emülatörde galeri boşsa "Fotoğraf çek" seçeneğiyle sanal kameradan çekebilirsiniz.
3. **Konumumu kullan**'a dokunun ve izin verin.
   > Emülatörün konumu varsayılan olarak ABD'dedir. İstanbul yapmak için: emülatör penceresinin yanındaki
   > **⋯ (Extended Controls)** → **Location** → haritada bir yer seçin → **Set Location**.
   > Sonra uygulamada konumu tekrar alın (uygulamayı kapatıp açmanız yeterli).

4. Şimdi denemek için sahte kullanıcılar ekleyelim. POMP klasöründeki PowerShell penceresinde:
   ```powershell
   docker compose exec api npm run seed
   ```
   Bu komut, konumunuzun çevresine 12 demo kullanıcı ekler. Bunların **yarısı sizi zaten beğenmiş** olur,
   yani sağa kaydırınca **"Eşleştiniz!"** ekranını görürsünüz. Demo kullanıcılara mesaj atarsanız otomatik cevap verirler.

5. Uygulamada **Keşfet** ekranının sağ üstündeki **yenile** düğmesine basın ve kaydırmaya başlayın!

### Uygulamada neler var?
- Kayıt / giriş, 18 yaş kontrolü, KVKK onayı
- 6 fotoğrafa kadar profil, hakkımda, ilgi alanları
- Konuma göre keşfet; yaş, mesafe ve cinsiyet filtreleri
- Sağa/sola kaydırma (veya ❤ / ✕ düğmeleri), karşılıklı beğenide eşleşme
- Anlık mesajlaşma, "yazıyor…" ve "Görüldü" bilgisi
- Eşleşmeyi kaldırma, engelleme, şikâyet etme
- Hesabı ve tüm verileri silme

---

## BÖLÜM 4 – Gerçek telefonda denemek (isteğe bağlı)

1. Telefon ve bilgisayar **aynı Wi-Fi**'ye bağlı olmalı.
2. Bilgisayarın yerel IP adresini öğrenin: PowerShell'de `ipconfig` yazın, **IPv4 Address** satırına bakın (örn. `192.168.1.20`).
3. Telefonda **Geliştirici seçenekleri** ve **USB hata ayıklama**'yı açın, telefonu USB ile bağlayın.
4. `mobile` klasöründe:
   ```powershell
   flutter run --dart-define=API_URL=http://192.168.1.20:3000
   ```
   (IP adresini kendi adresinizle değiştirin.)
5. Windows Güvenlik Duvarı izin isterse **İzin ver**'e tıklayın.

---

## BÖLÜM 5 – Yayına almadan önce (yapılacaklar listesi)

Şu an her şey **sizin bilgisayarınızda** çalışıyor. Herkesin kullanabilmesi için:

- [ ] **Sunucu kiralamak**: DigitalOcean, Hetzner, AWS vb. bir yerde Linux sunucu (aylık ~5–10 $). Aynı `docker compose up -d --build` komutuyla çalışır.
- [ ] **Alan adı ve HTTPS**: örn. `api.pompapp.com`. HTTPS zorunludur (Caddy veya Nginx + Let's Encrypt ile ücretsiz).
- [ ] **`.env` dosyasını değiştirin**: `JWT_SECRET` için uzun rastgele bir metin, güçlü bir `DB_PASSWORD`, `PUBLIC_URL=https://api.alanadiniz.com`, `NODE_ENV=production`.
- [ ] **Uygulamayı yeni adrese bağlayın**: `flutter build appbundle --dart-define=API_URL=https://api.alanadiniz.com`
- [ ] AndroidManifest.xml'deki `usesCleartextTraffic` değerini `false` yapın.
- [ ] **Yasal metinler**: `server/public/legal/` içindeki taslakları bir avukata kontrol ettirin.
- [ ] **Moderasyon**: şikâyetler veritabanındaki `reports` tablosuna düşer; bunları düzenli kontrol edecek bir süreç kurun.
- [ ] **Mağaza hesapları**: Google Play (tek seferlik 25 $), Apple Developer (yıllık 99 $; iOS için Mac gerekir, bkz. `mobile/IOS_NOTLARI.md`).
- [ ] **Uygulama simgesi ve adı**: mağaza görselleri, ekran görüntüleri.

### Sonraki sürümde eklenebilecekler
Push bildirimleri (uygulama kapalıyken mesaj bildirimi), e-posta doğrulama, şifremi unuttum,
selfie ile profil doğrulama, Super Like, ücretli abonelik, yönetici paneli.
