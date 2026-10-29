"""Pomp araclari icin ortak kod: Oracle sunucusuna SSH ile baglanip komut calistirir.

Mac ve Windows'ta calisir (Windows 10/11'in kendi ssh komutunu kullanir).
Sunucu IP'si Pomp klasorundeki sunucu_bilgileri.txt dosyasindan okunur
(ORACLE_YUKLE.command / ORACLE_YUKLE.bat bu dosyayi olusturur).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INFO = ROOT / "sunucu_bilgileri.txt"
KEY = Path.home() / ".ssh" / "pomp_oracle.key"
COMPOSE = "sudo docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml"
WINDOWS = os.name == "nt"

try:  # ssh ciktisiyla karismamasi icin satir satir yaz
    sys.stdout.reconfigure(line_buffering=True)
except AttributeError:
    pass


def hata(mesaj):
    print("\nHATA: " + mesaj)
    print("Bu pencerenin ekran goruntusunu Claude'a gonderin.")
    bekle()
    sys.exit(1)


def bekle():
    try:
        input("\nKapatmak icin Enter...")
    except EOFError:
        pass


def bilgiler():
    sonuc = {}
    if INFO.exists():
        for satir in INFO.read_text(encoding="utf-8", errors="ignore").splitlines():
            if "=" in satir:
                k, v = satir.split("=", 1)
                sonuc[k.strip()] = v.strip()
    return sonuc


def _anahtar_hazirla():
    if not KEY.exists():
        indirilenler = sorted((Path.home() / "Downloads").glob("ssh-key-*.key"),
                              key=lambda p: p.stat().st_mtime, reverse=True)
        if not indirilenler:
            hata("SSH anahtari bulunamadi. Oracle'in verdigi ssh-key-....key dosyasini Indirilenler klasorune koyun.")
        KEY.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(indirilenler[0], KEY)
        print("SSH anahtari alindi: " + str(indirilenler[0]))
    if WINDOWS:
        user = os.environ.get("USERNAME", "")
        subprocess.run(["icacls", str(KEY), "/inheritance:r", "/grant:r", f"{user}:R"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        os.chmod(KEY, 0o600)


class Sunucu:
    def __init__(self):
        if not shutil.which("ssh"):
            hata("ssh komutu bulunamadi.")
        _anahtar_hazirla()
        b = bilgiler()
        self.ip = b.get("IP") or input("Oracle sunucusunun IP adresi: ").strip()
        if not self.ip:
            hata("IP adresi girilmedi.")
        self.adres = b.get("ADRES", "https://" + self.ip.replace(".", "-") + ".sslip.io")
        print(f">> Sunucuya baglaniliyor ({self.ip})...")
        self.ssh = None
        for kullanici in ("opc", "ubuntu"):
            deneme = ["ssh", "-i", str(KEY), "-o", "StrictHostKeyChecking=accept-new",
                      "-o", "ConnectTimeout=15", f"{kullanici}@{self.ip}"]
            r = subprocess.run(deneme[:1] + ["-o", "BatchMode=yes"] + deneme[1:] + ["true"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if r.returncode == 0:
                self.ssh = deneme
                break
        if not self.ssh:
            hata("Sunucuya baglanilamadi. IP adresini ve SSH anahtarini kontrol edin.")

    def calistir(self, komut, girdi=None, yakala=False):
        """Sunucuda ~/pomp klasorunde komut calistirir."""
        r = subprocess.run(self.ssh + ["cd ~/pomp && " + komut],
                           input=girdi.encode("utf-8") if girdi is not None else None,
                           stdout=subprocess.PIPE if yakala else None,
                           stderr=subprocess.STDOUT if yakala else None)
        cikti = r.stdout.decode("utf-8", errors="replace") if yakala else ""
        return r.returncode, cikti
