#!/bin/bash
# Pomp sunucusunu Oracle Cloud'a kurar veya gunceller. Finder'da cift tiklayin
# ya da Terminal'de:  bash ~/Documents/GitHub/Pomp/ORACLE_YUKLE.command
cd "$(dirname "$0")"
ROOT="$(pwd)"
INFO="$ROOT/sunucu_bilgileri.txt"
KEY="$HOME/.ssh/pomp_oracle.key"
exec > >(tee "$ROOT/oracle_log.txt") 2>&1

hata() { echo; echo "HATA: $1"; echo "Bu pencerenin ekran goruntusunu Claude'a gonderin."; read -p "Kapatmak icin Enter..."; exit 1; }

echo "=== Pomp -> Oracle Cloud ==="

# 1) SSH anahtari: ilk seferde Indirilenler'deki Oracle anahtarini al
if [ ! -f "$KEY" ]; then
  SRC="$(ls -t "$HOME"/Downloads/ssh-key-*.key 2>/dev/null | head -1)"
  [ -z "$SRC" ] && hata "Indirilenler klasorunde Oracle'in verdigi 'ssh-key-....key' dosyasi bulunamadi."
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  cp "$SRC" "$KEY" && chmod 600 "$KEY"
  echo "SSH anahtari alindi: $SRC"
fi

# 2) Sunucu IP adresi (bir kez sorulur, sonra hatirlanir)
IP="$(grep '^IP=' "$INFO" 2>/dev/null | cut -d= -f2)"
if [ -z "$IP" ]; then
  read -p "Oracle sunucusunun Public IP adresi (ornek 129.146.12.34): " IP
  IP="$(echo "$IP" | tr -d ' ')"
fi
[[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || hata "Gecersiz IP adresi: $IP"

echo ">> Sunucuya baglaniliyor ($IP)..."
SSH=""
for U in ubuntu opc; do
  T="ssh -i $KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o BatchMode=yes $U@$IP"
  if $T "true" 2>/dev/null; then SSH="$T"; SSH_USER="$U"; break; fi
done
[ -z "$SSH" ] && hata "Sunucuya baglanilamadi (ubuntu ve opc kullanicilari denendi). IP adresini ve SSH anahtarini kontrol edin."
echo "Baglandi (kullanici: $SSH_USER)"

echo ">> Dosyalar gonderiliyor..."
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf - --exclude=node_modules --exclude=.env --exclude='._*' --exclude=.DS_Store \
  docker-compose.yml deploy server | $SSH "mkdir -p ~/pomp && tar xzf - -C ~/pomp" || hata "Dosyalar gonderilemedi."

echo ">> Sunucu kuruluyor/guncelleniyor (ilk kurulum 5-10 dk surebilir)..."
OUT="$($SSH "bash ~/pomp/deploy/sunucu_kur.sh $IP" 2>&1 | tee /dev/stderr)"
URL="$(echo "$OUT" | grep '^TAMAM ' | cut -d' ' -f2)"
ADMIN="$(echo "$OUT" | grep '^ADMIN_PASSWORD=' | cut -d= -f2)"
[ -z "$URL" ] && hata "Kurulum tamamlanamadi (yukaridaki kayitlara bakin)."

# 3) Bilgileri kaydet ve uygulamadaki sunucu adresini guncelle
cat > "$INFO" <<INFO
IP=$IP
ADRES=$URL
YONETICI_PANELI=$URL/admin
YONETICI_SIFRESI=$ADMIN
SSH=ssh -i ~/.ssh/pomp_oracle.key $SSH_USER@$IP
INFO
chmod 600 "$INFO"
sed -i '' "s#static const String sunucuAdresi = '.*';#static const String sunucuAdresi = '$URL';#" mobile/lib/config.dart

echo
echo "============================================================"
echo " Sunucu hazir:      $URL"
echo " Yonetici paneli:   $URL/admin"
echo " Yonetici sifresi:  $ADMIN"
echo " (Bu bilgiler Pomp klasorunde sunucu_bilgileri.txt dosyasinda.)"
echo
echo " Uygulama artik bu adrese baglanacak sekilde ayarlandi."
echo " Simdi IOS.command / APK.bat ile uygulamayi yeniden derleyin."
echo "============================================================"
read -p "Kapatmak icin Enter..."
