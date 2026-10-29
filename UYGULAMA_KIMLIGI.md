# Uygulama Kimliği (Pomp)

## Paket adı
Uygulamanın paket adı (Android "applicationId" ve iPhone "Bundle ID"):

    com.walcadow.pomp

**Önemli:** Uygulama Google Play'de bir kez yayınlandıktan sonra bu ad **asla değiştirilemez**.
Değiştirilirse Google Play onu tamamen yeni (başka) bir uygulama sayar.

Not: Eski adla (com.pomp.pomp) emülatöre/telefona kurulmuş bir sürüm varsa, onu önce silin.
Yeni sürüm ayrı bir uygulama olarak kurulur.

## Uygulama adı
Telefonda görünen ad: **Pomp**

## Simge (ikon) ve açılış ekranı dosyaları nerede?
- Ana simge (1024x1024): `mobile/assets/branding/icon_1024.png`
- Google Play tanıtım görseli (1024x500): `mobile/assets/branding/feature_graphic.png`
- Android simgeleri: `mobile/android/app/src/main/res/mipmap-*/`
- Android açılış ekranı logosu: `mobile/android/app/src/main/res/drawable-*/launch_logo.png`
- iPhone simgeleri: `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- iPhone açılış logosu: `mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/`
- Windows simgesi: `mobile/windows/runner/resources/app_icon.ico`

Açılış ekranı rengi mor (#6C4CF1), ortada beyaz "p" logosu vardır.

## Simgeyi daha sonra nasıl değiştiririm?
1. Yeni simgenizi 1024x1024 piksel PNG olarak hazırlayın.
2. `mobile/assets/branding/icon_1024.png` dosyasının üzerine kaydedin.
3. Claude'a şunu yazın: "icon_1024.png dosyasını değiştirdim, tüm uygulama simgelerini ve açılış ekranını bundan yeniden oluştur."
