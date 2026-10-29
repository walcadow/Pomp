#!/usr/bin/env python3
"""Pomp - E-posta ayari (dogrulama ve sifre sifirlama kodlari).

Oracle sunucusuna SMTP bilgilerini yazar, sunucuyu yeniden baslatir ve bir deneme e-postasi gonderir.
Sifre yalnizca sunucudaki .env dosyasina yazilir; bilgisayarda ya da GitHub'da saklanmaz.

Kullanim (Mac):      python3 EPOSTA.py
Kullanim (Windows):  EPOSTA.py dosyasina cift tiklayin  ya da  py EPOSTA.py
Ayrintilar: EPOSTA_KURULUM.md
"""
import getpass
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "deploy"))
from sunucu import COMPOSE, Sunucu, bekle, hata  # noqa: E402


def sor(soru, varsayilan=""):
    ek = f" [{varsayilan}]" if varsayilan else ""
    cevap = input(f"{soru}{ek}: ").strip()
    return cevap or varsayilan


def main():
    print("=== Pomp e-posta ayari ===\n")
    print("1) Gmail (en kolayi; Google hesabinizda 'Uygulama sifresi' gerekir)")
    print("2) Baska bir SMTP servisi (Brevo, Resend, Yandex, Outlook...)")
    secim = sor("Seciminiz", "1")

    if secim == "1":
        print("\nUygulama sifresi: https://myaccount.google.com/apppasswords")
        print("(Google hesabinizda 2 Adimli Dogrulama acik olmali. 16 harfli sifreyi kopyalayin.)\n")
        kullanici = sor("Gmail adresiniz")
        if "@" not in kullanici:
            hata("Gecerli bir e-posta adresi girin.")
        sifre = getpass.getpass("Uygulama sifresi (yazarken gorunmez): ").replace(" ", "")
        ayar = {"SMTP_HOST": "smtp.gmail.com", "SMTP_PORT": "465", "SMTP_SECURE": "true",
                "SMTP_USER": kullanici, "SMTP_PASS": sifre, "SMTP_FROM": f"Pomp <{kullanici}>"}
    else:
        host = sor("SMTP sunucusu (orn. smtp-relay.brevo.com)")
        port = sor("Port", "587")
        kullanici = sor("Kullanici adi")
        sifre = getpass.getpass("Sifre / SMTP anahtari (yazarken gorunmez): ")
        gonderen = sor("Gonderen adresi", kullanici if "@" in kullanici else "")
        ayar = {"SMTP_HOST": host, "SMTP_PORT": port, "SMTP_SECURE": "true" if port == "465" else "false",
                "SMTP_USER": kullanici, "SMTP_PASS": sifre, "SMTP_FROM": f"Pomp <{gonderen}>"}

    if not ayar["SMTP_HOST"] or not ayar["SMTP_PASS"]:
        hata("Sunucu adresi ve sifre bos olamaz.")
    for k, v in ayar.items():
        if '"' in v or "\n" in v:
            hata(f"{k} degeri tirnak isareti iceremez.")

    alici = sor("\nDeneme e-postasi hangi adrese gitsin", kullanici if "@" in kullanici else "")

    sunucu = Sunucu()
    print(">> Ayar sunucuya yaziliyor...")
    satirlar = "".join(f'{k}="{v}"\n' for k, v in ayar.items())
    kod, cikti = sunucu.calistir(
        "umask 077 && cat > .smtp.yeni && "
        "grep -v -E '^SMTP_(HOST|PORT|SECURE|USER|PASS|FROM)=' .env > .env.yeni; "
        "cat .smtp.yeni >> .env.yeni && mv .env.yeni .env && rm -f .smtp.yeni && "
        f"{COMPOSE} up -d api 2>&1 | tail -3",
        girdi=satirlar, yakala=True)
    if kod != 0:
        hata("Ayar yazilamadi:\n" + cikti)

    print(">> Deneme e-postasi gonderiliyor...")
    js = ("require('./src/mailer').sendMail({to: %s, subject: 'Pomp e-posta deneme', "
          "text: 'Bu bir deneme e-postasidir. Pomp e-posta ayari calisiyor.'})"
          ".then(() => console.log('GONDERILDI'))"
          ".catch(e => { console.log('GONDERILEMEDI: ' + e.message); process.exit(1); })") % json.dumps(alici)
    kod, cikti = sunucu.calistir(f"sleep 4; {COMPOSE} exec -T api node -e {json.dumps(js)}", yakala=True)
    print(cikti.strip())
    if "GONDERILDI" in cikti:
        print(f"\nTAMAM: {alici} adresine deneme e-postasi gonderildi (gelmezse Spam klasorune bakin).")
        print("Bundan sonra dogrulama ve sifre sifirlama kodlari gercekten gonderilecek.")
        bekle()
    else:
        hata("E-posta gonderilemedi. Adres/sifreyi kontrol edip EPOSTA.py'yi tekrar calistirin.")


if __name__ == "__main__":
    main()
