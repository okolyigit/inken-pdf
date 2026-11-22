#!/usr/bin/env bash
# Uygulama ve .pdf dosya ikonlarının bütün türevlerini tasarım sisteminin
# SVG'lerinden (apps/inken/assets/brand/) üretir. Logolar değişince
# çalıştırılır; çıktılar depoya girer.
#
# Gerekenler: rsvg-convert (librsvg), python3.
# SVG'lerdeki yazılar harf şekline çevrilmiş olmalı (<text> yok): her
# çizici aynı sonucu verir, Figtree kurulu olmasa da.
#
# Kural (tasarım sistemi → AppIcon): 48px'in altında -small çizimleri.
# Uygulama ikonunun küçük çizimi kaldırıldı (22 Kasım 2026): her boyutta
# "PDF" etiketli ana ikon. Küçük çizim yalnızca .pdf dosya ikonunda var.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/apps/inken"
BRAND="$APP/assets/brand"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if grep -l '<text' "$BRAND"/*.svg; then
  echo "Yukarıdaki SVG'lerde <text> var; önce harf şekline çevirin." >&2
  exit 1
fi

png() { # <svg> <boy> <çıktı>
  mkdir -p "$(dirname "$3")"
  rsvg-convert -w "$2" -h "$2" "$BRAND/$1.svg" -o "$3"
}
icon() { # <ad> <küçük-ad> <boy> <çıktı>: 48'in altında küçük çizim
  if (($3 < 48)); then png "$2" "$3" "$4"; else png "$1" "$3" "$4"; fi
}

# Uygulama içi ve Linux pencere ikonu.
png inken-app-icon 256 "$BRAND/inken-icon-256.png"

# Windows: uygulama ve .pdf dosya ikonu (Runner.rc), MSIX logoları.
ico() { # <ad> <küçük-ad> <çıktı>
  local files=()
  for s in 16 20 24 32 40 48 64 128 256; do
    icon "$1" "$2" "$s" "$TMP/$1-$s.png"
    files+=("$TMP/$1-$s.png")
  done
  python3 "$ROOT/packaging/icons/make_ico.py" "$3" "${files[@]}"
}
ico inken-app-icon inken-app-icon "$APP/windows/runner/resources/app_icon.ico"
ico inken-pdf-file inken-pdf-file-small "$APP/windows/runner/resources/pdf_file.ico"
png inken-app-icon 1024 "$APP/windows/msix/logo.png"
png inken-pdf-file 256 "$APP/windows/msix/pdf-file.png"

# Android: eski başlatıcı ikonu, uyarlanabilir ön plan ve temalı (tek renk).
RES="$APP/android/app/src/main/res"
for pair in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  d=${pair%%:*} k=${pair##*:}
  legacy=$(python3 -c "print(round(48*$k))")
  layer=$(python3 -c "print(round(108*$k))")
  png inken-app-icon "$legacy" "$RES/mipmap-$d/ic_launcher.png"
  png inken-adaptive-foreground "$layer" "$RES/mipmap-$d/ic_launcher_foreground.png"
  png inken-mono "$layer" "$RES/mipmap-$d/ic_launcher_monochrome.png"
done

# Linux: hicolor teması (uygulama ve application-pdf MIME ikonu).
HI="$ROOT/packaging/linux/icons/hicolor"
rm -rf "$HI"
for s in 16 24 32 48 64 128 256 512; do
  icon inken-app-icon inken-app-icon "$s" "$HI/${s}x${s}/apps/inken-pdf.png"
  icon inken-pdf-file inken-pdf-file-small "$s" \
    "$HI/${s}x${s}/mimetypes/application-pdf.png"
done
mkdir -p "$HI/scalable/apps" "$HI/scalable/mimetypes"
cp "$BRAND/inken-app-icon.svg" "$HI/scalable/apps/inken-pdf.svg"
cp "$BRAND/inken-pdf-file.svg" "$HI/scalable/mimetypes/application-pdf.svg"

echo "İkonlar üretildi."
