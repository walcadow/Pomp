#!/bin/bash
# Oracle sunucusunda calisir (ORACLE_YUKLE.command tarafindan cagrilir).
# Kullanim: bash deploy/sunucu_kur.sh <sunucu-ip>
set -e
IP="$1"
[ -z "$IP" ] && { echo "Sunucu IP adresi verilmedi."; exit 1; }
cd "$(dirname "$0")/.."

. /etc/os-release
echo ">> Isletim sistemi: $PRETTY_NAME"

echo ">> Docker kontrol ediliyor..."
if ! command -v docker >/dev/null; then
  if command -v apt-get >/dev/null; then
    curl -fsSL https://get.docker.com | sudo sh
  else
    # Oracle Linux / RHEL
    # Yeni sunucuda arka plan guncellemesi paket sistemini kilitleyebilir: bitmesini bekle, gerekirse tekrar dene.
    bekle() {
      for i in $(seq 1 60); do
        pgrep -x 'dnf|yum|dnf-automatic|rpm' >/dev/null || return 0
        [ $i = 1 ] && echo "   Sunucunun kendi guncellemesi suruyor, bekleniyor..."
        sleep 10
      done
    }
    tekrar() { for n in 1 2 3 4 5; do bekle; "$@" && return 0; echo "   Tekrar deneniyor ($n)..."; sleep 15; done; return 1; }
    tekrar sudo dnf install -y dnf-plugins-core
    tekrar sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    tekrar sudo rpm --import https://download.docker.com/linux/centos/gpg
    tekrar sudo dnf install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
fi
sudo systemctl enable --now docker

echo ">> Guvenlik duvarinda 80 ve 443 portlari aciliyor..."
if command -v firewall-cmd >/dev/null && sudo firewall-cmd --state >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-service=http --add-service=https >/dev/null
  sudo firewall-cmd --reload >/dev/null
else
  for P in 80 443; do
    sudo iptables -C INPUT -p tcp --dport $P -j ACCEPT 2>/dev/null || sudo iptables -I INPUT 1 -p tcp --dport $P -j ACCEPT
  done
  if command -v netfilter-persistent >/dev/null; then sudo netfilter-persistent save >/dev/null 2>&1 || true; fi
fi

SITE="${IP//./-}.sslip.io"

# .env yalnizca ilk kurulumda olusturulur (veritabani sifresi sonradan degismemeli).
if [ ! -f .env ]; then
  echo ">> Gizli anahtarlar olusturuluyor..."
  cat > .env <<ENV
DB_PASSWORD=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
ADMIN_PASSWORD=$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)
NODE_ENV=production
SITE_ADDRESS=$SITE
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=
SMTP_USER=
SMTP_PASS=
SMTP_FROM=
ENV
  chmod 600 .env
else
  # IP degistiyse adresi guncelle
  sed -i "s/^SITE_ADDRESS=.*/SITE_ADDRESS=$SITE/" .env
fi

echo ">> Pomp baslatiliyor (ilk seferde birkac dakika surer)..."
sudo docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml up -d --build --remove-orphans

echo ">> HTTPS sertifikasi ve saglik kontrolu bekleniyor..."
for i in $(seq 1 40); do
  if curl -fsS "https://$SITE/health" >/dev/null 2>&1; then
    echo "TAMAM https://$SITE"
    echo "ADMIN_PASSWORD=$(grep ^ADMIN_PASSWORD= .env | cut -d= -f2)"
    exit 0
  fi
  sleep 5
done
echo "UYARI: https://$SITE henuz yanit vermiyor."
sudo docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml ps
sudo docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml logs --tail=40 caddy api
exit 2
