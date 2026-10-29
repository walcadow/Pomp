# E-posta kurulumu (doğrulama ve şifre sıfırlama kodları)

Pomp, kayıt olan kişiye **e-posta doğrulama kodu**, şifresini unutan kişiye de **şifre sıfırlama kodu** gönderir. Kodlar 6 hanelidir ve 15 dakika geçerlidir.

## 1. Denerken (geliştirme modu) — hiçbir ayar gerekmez

E-posta ayarı yapılmadıysa e-postalar gerçekten **gönderilmez**. Bunun yerine:

- Bilgisayarınızın tarayıcısında şu adresi açın: **http://localhost:3000/dev/emails**
  Son gönderilen e-postalar en yeni üstte görünür, kod büyük harflerle yazar. Sayfa kendini 10 saniyede bir yeniler.
- Ayrıca kod, sunucu penceresinin (konsolun) çıktısına da yazılır.
- Android emülatörünün içinden açacaksanız adres: http://10.0.2.2:3000/dev/emails

Not: Bu sayfa yalnızca `NODE_ENV=development` iken çalışır. Yayında (`production`) kapalıdır. Sunucu yeniden başlarsa liste sıfırlanır.

## 2. Gerçek e-posta göndermek (yayına alırken)

Gerçek e-posta için bir **SMTP** hesabı gerekir. İki kolay seçenek:

### Seçenek A: Gmail (az sayıda kullanıcı için, günde ~500 e-posta sınırı)
1. Google hesabınızda **2 Adımlı Doğrulama**'yı açın.
2. https://myaccount.google.com/apppasswords adresinden bir **Uygulama şifresi** oluşturun (16 harfli bir şifre verir).
3. `.env` dosyanıza şunları ekleyin:

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=adresiniz@gmail.com
SMTP_PASS=uygulama-sifreniz-16-harf
SMTP_FROM=Pomp <adresiniz@gmail.com>
```

### Seçenek B: Brevo, Resend gibi e-posta servisleri (önerilen)
Ücretsiz planları vardır (ör. Brevo günde 300 e-posta). Hesap açın, kendi alan adınızı (domain) doğrulayın ve servisin verdiği SMTP bilgilerini yazın. Örnek (Brevo):

```
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=brevo-giris-adiniz
SMTP_PASS=brevo-smtp-anahtariniz
SMTP_FROM=Pomp <no-reply@alanadiniz.com>
```

Resend için: `SMTP_HOST=smtp.resend.com`, `SMTP_PORT=465`, `SMTP_SECURE=true`, `SMTP_USER=resend`, `SMTP_PASS=` Resend API anahtarınız.

### Ayarların anlamı
| Ayar | Açıklama |
|---|---|
| `SMTP_HOST` | E-posta sunucusu adresi. **Boş bırakılırsa e-posta gönderilmez** (geliştirme modu). |
| `SMTP_PORT` | Genelde `465` (şifreli) veya `587`. |
| `SMTP_SECURE` | Port 465 ise `true`, 587 ise `false`. |
| `SMTP_USER` / `SMTP_PASS` | Servisin verdiği kullanıcı adı ve şifre. |
| `SMTP_FROM` | Gönderen olarak görünecek ad ve adres. |

Ayarları değiştirdikten sonra sunucuyu yeniden başlatın. E-postalar spam klasörüne düşüyorsa kendi alan adınızla bir e-posta servisi (Seçenek B) kullanın.
