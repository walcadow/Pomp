# iPhone (iOS) için ek ayar

iPhone sürümünü derlemek için bir **Mac** bilgisayar ve **Xcode** gerekir; Windows'ta iOS uygulaması derlenemez.
Mac'te `flutter create` çalıştırdıktan sonra `ios/Runner/Info.plist` dosyasını açın ve
en alttaki `</dict>` satırının hemen **üstüne** şunları ekleyin:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Yakınındaki kişileri gösterebilmek için yaklaşık konumunu kullanıyoruz.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Profiline fotoğraf ekleyebilmen için galerine erişmemiz gerekiyor.</string>
<key>NSCameraUsageDescription</key>
<string>Profil fotoğrafı çekebilmen için kameraya erişmemiz gerekiyor.</string>
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Yalnızca geliştirme için: http:// sunucuya bağlanmaya izin verir. Yayında kaldırın. -->
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
