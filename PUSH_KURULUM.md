# Bildirimleri Açma (Firebase) — Kurulum Rehberi

Pomp, uygulama kapalıyken bile **yeni eşleşme** ve **yeni mesaj** bildirimleri gönderebilir.
Bunun için Google'ın ücretsiz **Firebase** hizmetini kullanıyoruz.

> Bu adımları yapmazsanız uygulama yine sorunsuz çalışır, sadece bildirim gelmez.
> İstediğiniz zaman yapabilirsiniz. Toplam süre yaklaşık 10 dakika.

---

## 1. Firebase projesi oluşturun

1. Tarayıcıda **https://console.firebase.google.com** adresini açın ve Google hesabınızla giriş yapın.
2. **"Proje oluştur"** (Create a project) düğmesine tıklayın.
3. Proje adı olarak `Pomp` yazın, **Devam**'a tıklayın.
4. Google Analytics sorulursa kapatabilirsiniz (gerekli değil). **Proje oluştur**'a tıklayın ve bitmesini bekleyin.

## 2. Android uygulamasını ekleyin

1. Proje ana sayfasında **Android simgesine** (yeşil robot) tıklayın.
2. **"Android paket adı"** kutusuna uygulamanın paket adını yazın.
   - Paket adını bulmak için `mobile/android/app/build.gradle.kts` dosyasını Not Defteri ile açın.
   - İçinde `applicationId = "..."` yazan satırı bulun. Tırnak içindeki yazıyı **aynen** kopyalayın
     (örneğin `com.walcadow.pomp`).
3. Diğer kutuları boş bırakabilirsiniz. **Uygulamayı kaydet**'e tıklayın.
4. **`google-services.json`** dosyasını indirin.
5. İndirdiğiniz dosyayı şu klasöre koyun:

   ```
   mobile/android/app/google-services.json
   ```

   (Dosya adı tam olarak `google-services.json` olmalı. Windows dosyanın adına `(1)` gibi bir ek koyduysa silin.)
6. Firebase sayfasındaki diğer adımları (SDK ekleme vb.) **atlayın** — **İleri** / **Konsola devam et** deyin. Bunlar zaten hazır.

## 3. Sunucu anahtarını indirin

Sunucunun bildirim gönderebilmesi için bir anahtar dosyası gerekiyor.

1. Firebase konsolunda sol üstteki **dişli çark ⚙ → Proje ayarları**'na tıklayın.
2. Üstteki **"Hizmet hesapları"** (Service accounts) sekmesine geçin.
3. **"Yeni özel anahtar oluştur"** (Generate new private key) düğmesine, sonra **Anahtar oluştur**'a tıklayın.
4. Bir `.json` dosyası inecek. Bu dosyanın adını **`firebase-service-account.json`** yapın ve şu klasöre koyun:

   ```
   server/firebase-service-account.json
   ```

> ⚠️ **Bu dosya gizlidir!** Kimseyle paylaşmayın, GitHub'a yüklemeyin.
> (Proje ayarlarında bu dosya zaten GitHub'a gönderilmeyecek şekilde ayarlanmıştır.)

## 4. Her şeyi yeniden başlatın

1. Sunucuyu yeniden başlatın (`SUNUCU_DURDUR.bat`, ardından `SUNUCU.bat`).
   Sunucu kayıtlarında **"Bildirimler açık"** yazısını görürseniz sunucu tarafı hazırdır.
2. Uygulamayı yeniden derleyip telefona kurun (`APK.bat`).
3. Uygulamayı açıp giriş yaptığınızda **"Bildirimlere izin ver"** sorusu çıkar — **İzin ver** deyin.

## Deneme

- İki farklı hesapla giriş yapın (iki telefon ya da telefon + emülatör).
- Bir telefonda uygulamayı kapatın, diğerinden mesaj gönderin. Bildirim gelmelidir.

## Sorun mu var?

| Belirti | Çözüm |
|---|---|
| Sunucu kayıtlarında "Bildirimler kapalı: Firebase hizmet hesabı bulunamadı" | `server/firebase-service-account.json` dosyasının adını ve yerini kontrol edin. |
| Uygulama derlenirken "No matching client found for package name" hatası | Firebase'e yazdığınız paket adı, `build.gradle.kts` içindeki `applicationId` ile aynı değil. Firebase'de doğru adla yeni bir Android uygulaması ekleyip yeni `google-services.json` indirin. |
| Bildirim gelmiyor | Telefonda **Ayarlar → Uygulamalar → Pomp → Bildirimler** açık mı kontrol edin. Pil tasarrufu modu da bildirimleri geciktirebilir. |
| iPhone | iPhone için ek ayar gerekir (Mac ve Apple geliştirici hesabı). `mobile/IOS_NOTLARI.md` dosyasına bakın. |
