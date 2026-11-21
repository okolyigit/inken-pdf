#!/usr/bin/env bash
# Pardus / Debian / Ubuntu için .deb paketi üretir: dist/inken-pdf_<sürüm>_amd64.deb
#
# dpkg-deb gerekmez: .deb, `ar` arşivi içinde debian-binary, control.tar.xz
# ve data.tar.xz'tir. Uygulama /opt/inken-pdf altına kurulur; /usr/bin/inken-pdf
# komutu, menü girdisi (PDF'ler için "Birlikte aç") ve ikon eklenir.
#
# Uyumluluk: derlenen ikililer en çok GLIBC 2.34 istemeli (Pardus 23: 2.36).
# Betik bunu denetler; daha yenisi gerekiyorsa paket üretmez.
#
# Kullanım: packaging/linux/build_deb.sh [--no-build]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/apps/inken"
BUNDLE="$APP/build/linux/x64/release/bundle"
OUT="$ROOT/dist"
MAX_GLIBC="2.36"

if [[ "${1:-}" != "--no-build" ]]; then
  (cd "$APP" && flutter build linux --release)
fi
[[ -x "$BUNDLE/inken" ]] || { echo "Derleme yok: $BUNDLE" >&2; exit 1; }

# Sürüm pubspec'ten: "1.2.3+4" → "1.2.3-4".
VERSION="$(sed -n 's/^version: *//p' "$APP/pubspec.yaml" | tr '+' '-')"
[[ -n "$VERSION" ]] || { echo "pubspec.yaml'da sürüm yok" >&2; exit 1; }

# GLIBC denetimi (en yüksek istenen sürüm).
need="$(for f in "$BUNDLE/inken" "$BUNDLE"/lib/*.so; do
  objdump -T "$f" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//'
done | sort -uV | tail -1)"
if [[ "$(printf '%s\n%s\n' "$need" "$MAX_GLIBC" | sort -V | tail -1)" != "$MAX_GLIBC" ]]; then
  echo "İkililer GLIBC $need istiyor; Pardus 23'te $MAX_GLIBC var. Daha eski bir sistemde derleyin." >&2
  exit 1
fi
echo "GLIBC gereksinimi: $need (sınır $MAX_GLIBC)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/data"
CTRL="$WORK/control"
mkdir -p "$STAGE/opt/inken-pdf" "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" "$STAGE/usr/share/icons" \
  "$STAGE/usr/share/doc/inken-pdf" "$CTRL"

cp -a "$BUNDLE/." "$STAGE/opt/inken-pdf/"
ln -s /opt/inken-pdf/inken "$STAGE/usr/bin/inken-pdf"
install -m 644 "$ROOT/packaging/linux/com.inkenpdf.app.desktop" \
  "$STAGE/usr/share/applications/"
# Uygulama ikonu ve .pdf dosya ikonu (application-pdf), bütün boylar
# (packaging/icons/generate.sh üretir).
cp -r "$ROOT/packaging/linux/icons/hicolor" "$STAGE/usr/share/icons/"
install -m 644 "$ROOT/LICENSE" "$STAGE/usr/share/doc/inken-pdf/copyright"
for f in LICENSE-DejaVu.txt OFL-Figtree.txt OFL-Fraunces.txt OFL-JetBrainsMono.txt; do
  install -m 644 "$APP/assets/fonts/$f" "$STAGE/usr/share/doc/inken-pdf/"
done

# İzinler: klasörler 755, dosyalar 644, çalıştırılabilirler ve .so 755.
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -exec chmod 644 {} +
chmod 755 "$STAGE/opt/inken-pdf/inken"
find "$STAGE/opt/inken-pdf/lib" -name '*.so' -exec chmod 755 {} +

# Bakımcı: INKEN_MAINTAINER, yoksa git kullanıcısı, o da yoksa yer tutucu.
MAINTAINER="${INKEN_MAINTAINER:-}"
if [[ -z "$MAINTAINER" ]]; then
  name="$(git -C "$ROOT" config user.name || true)"
  email="$(git -C "$ROOT" config user.email || true)"
  if [[ -n "$name" && -n "$email" ]]; then
    MAINTAINER="$name <$email>"
  else
    MAINTAINER="Inken PDF <noreply@invalid>"
  fi
fi
SIZE_KB="$(du -sk "$STAGE" | cut -f1)"
cat > "$CTRL/control" <<CONTROL
Package: inken-pdf
Version: $VERSION
Architecture: amd64
Maintainer: $MAINTAINER
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.34), libgtk-3-0 | libgtk-3-0t64, libglib2.0-0 | libglib2.0-0t64, libepoxy0, libfontconfig1, libstdc++6
Section: education
Priority: optional
Description: PDF üzerinde ders anlatma uygulaması
 Öğretmenler için: PDF'i açın, kalem, fosforlu, şekil ve metinle üzerinde
 ders anlatın. Çizimler PDF'in içine kaydedilir ve her PDF okuyucuda
 görünür; orijinal dosyanın üzerine yazılmaz. Akıllı tahta ve kalemli
 tablet için tasarlandı.
CONTROL
(cd "$STAGE" && find . -type f ! -path './usr/bin/*' -printf '%P\0' \
  | sort -z | xargs -0 md5sum) > "$CTRL/md5sums"
chmod 644 "$CTRL/control" "$CTRL/md5sums"

TAR=(tar --owner=0 --group=0 --numeric-owner --sort=name -cJf)
"${TAR[@]}" "$WORK/control.tar.xz" -C "$CTRL" ./control ./md5sums
"${TAR[@]}" "$WORK/data.tar.xz" -C "$STAGE" .
echo "2.0" > "$WORK/debian-binary"

mkdir -p "$OUT"
DEB="$OUT/inken-pdf_${VERSION}_amd64.deb"
rm -f "$DEB"
(cd "$WORK" && ar rcD "$DEB" debian-binary control.tar.xz data.tar.xz)
echo "Paket: $DEB ($(du -h "$DEB" | cut -f1))"
