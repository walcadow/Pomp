#!/usr/bin/env python3
"""Pomp - Demo (bot) kullanicilar.

Oracle sunucusuna 12 sahte kullanici ekler (DEMO.bat'in yerine).
Uygulamadan en son giris yapan gercek kullanicinin 15 km cevresine yerlestirilir;
yarisi o kullaniciyi onceden begenmis olur, saga kaydirinca hemen eslesirsiniz.

Kullanim (Mac):      python3 DEMO.py
Kullanim (Windows):  DEMO.py dosyasina cift tiklayin  ya da  py DEMO.py

Secenekler:
  --sil                    Tum demo kullanicilari siler
  --konum 41.01 28.97      Belirli bir konumun cevresine ekler
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "deploy"))
from sunucu import COMPOSE, Sunucu, bekle, hata  # noqa: E402


def main():
    args = sys.argv[1:]
    seed_args = []
    if "--sil" in args:
        seed_args = ["--sil"]
    elif "--konum" in args:
        i = args.index("--konum")
        try:
            lat, lng = float(args[i + 1]), float(args[i + 2])
        except (IndexError, ValueError):
            hata("Konum su sekilde verilmeli:  --konum 41.01 28.97")
        seed_args = ["--lat", str(lat), "--lng", str(lng)]

    print("=== Pomp demo kullanicilar ===")
    if not seed_args:
        print("Not: Once uygulamada kayit olup fotograf ekleyin ve konum izni verin.\n")
    sunucu = Sunucu()
    komut = f"{COMPOSE} exec -T api npm run --silent seed"
    if seed_args:
        komut += " -- " + " ".join(seed_args)
    kod, _ = sunucu.calistir(komut)
    if kod != 0:
        hata("Demo kullanicilar olusturulamadi (yukaridaki mesaja bakin).")
    bekle()


if __name__ == "__main__":
    main()
