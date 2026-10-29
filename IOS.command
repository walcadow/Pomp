#!/bin/bash
# Pomp - iPhone (iOS) derlemesi. Finder'da cift tiklayarak calistirin.
cd "$(dirname "$0")"
ROOT="$(pwd)"
LOG="$ROOT/ios_log.txt"
echo "Pomp iOS kaydi $(date)" > "$LOG"
FLUTTER_DIR="$HOME/Downloads/flutter/flutter_macos_arm64_3"
if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  # Indirilen dosyalara macOS'un koydugu engeli kaldir
  xattr -dr com.apple.quarantine "$FLUTTER_DIR" 2>/dev/null
  # Flutter'i Terminal'e kalici olarak tanit (bir kez)
  if ! grep -q "$FLUTTER_DIR/bin" "$HOME/.zprofile" 2>/dev/null; then
    echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$HOME/.zprofile"
    echo "Flutter Terminal'e eklendi (~/.zprofile)."
  fi
fi
export PATH="$FLUTTER_DIR/bin:$HOME/flutter/bin:$HOME/development/flutter/bin:$HOME/Desktop/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export LANG=en_US.UTF-8

hata() { echo; echo "HATA: $1"; echo "Ayrintilar: ios_log.txt  -  Claude'a \"ios build hata verdi\" yazin."; read -t 5 -p "Kapaniyor..."; exit 1; }

echo "1/5 Gerekli araclar kontrol ediliyor..."
command -v flutter >/dev/null || hata "Flutter bulunamadi. https://docs.flutter.dev/get-started/install/macos adresinden kurun."
xcodebuild -version >>"$LOG" 2>&1 || hata "Xcode bulunamadi veya kurulumu bitmemis. App Store'dan Xcode kurup bir kez acin, sonra Terminal'de: sudo xcode-select -s /Applications/Xcode.app"
# CocoaPods yerine Swift Package Manager kullanilir (ek kurulum gerekmez)
flutter config --enable-swift-package-manager >>"$LOG" 2>&1
flutter --version | tee -a "$LOG"

echo
IP="$(ipconfig getifaddr en0 2>/dev/null)"
echo "Sunucu adresi (uygulamanin baglanacagi). Bos birakirsaniz http://$IP:3000 kullanilir."
echo "Tunel kullaniyorsaniz https://...trycloudflare.com adresini yapistirin."
read -t 30 -p "Adres (30 sn icinde yazmazsaniz varsayilan kullanilir): " URL; echo
[ -z "$URL" ] && URL="http://$IP:3000"
echo "Sunucu: $URL" | tee -a "$LOG"

cd mobile
echo "2/5 Paketler indiriliyor..."
flutter pub get >>"$LOG" 2>&1 || hata "flutter pub get basarisiz"
echo "3/5 iOS dosyalari hazirlaniyor..."
flutter precache --ios >>"$LOG" 2>&1
echo "4/5 iOS derleniyor (5-15 dk)..."
flutter build ios --release --no-codesign --dart-define=API_URL="$URL" >>"$LOG" 2>&1 || hata "flutter build ios basarisiz"
echo "5/5 Xcode aciliyor..."
open ios/Runner.xcworkspace
echo
echo "============================================================"
echo " Derleme basarili. Telefona kurmak icin Xcode'da:"
echo "  1) Soldan Runner > Signing & Capabilities > Team: Apple hesabinizi secin"
echo "  2) Ustten iPhone'unuzu secin, Play (>) tusuna basin"
echo "  App Store/TestFlight icin: Product > Archive"
echo "============================================================"
read -p "Kapatmak icin Enter..."
