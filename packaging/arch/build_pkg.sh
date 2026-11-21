#!/usr/bin/env bash
# Arch / CachyOS / Manjaro için pacman paketi üretir:
#   dist/inken-pdf-<sürüm>-<derleme>-x86_64.pkg.tar.zst
#
# Uygulama /opt/inken-pdf altına kurulur; /usr/bin/inken-pdf komutu, menü
# girdisi (PDF'ler için "Birlikte aç") ve ikon eklenir (.deb ile aynı düzen).
# Arch sürekli güncel olduğundan GLIBC sınırı denetlenmez.
#
# Kullanım: packaging/arch/build_pkg.sh [--no-build]
# Kurulum:  sudo pacman -U dist/inken-pdf-*-x86_64.pkg.tar.zst
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/apps/inken"
BUNDLE="$APP/build/linux/x64/release/bundle"
OUT="$ROOT/dist"

if [[ "${1:-}" != "--no-build" ]]; then
  (cd "$APP" && flutter build linux --release)
fi
[[ -x "$BUNDLE/inken" ]] || { echo "Derleme yok: $BUNDLE" >&2; exit 1; }
command -v makepkg >/dev/null || { echo "makepkg yok (pacman sistemi gerekir)" >&2; exit 1; }

# Sürüm pubspec'ten: "1.2.3+4" → pkgver 1.2.3, pkgrel 4.
# pkgver '-', '+' ve ':' içeremez; ön sürüm eki ("-beta.1") '_' olur.
RAW="$(sed -n 's/^version: *//p' "$APP/pubspec.yaml" | tr -d '[:space:]')"
[[ -n "$RAW" ]] || { echo "pubspec.yaml'da sürüm yok" >&2; exit 1; }
PKGVER="${RAW%%+*}"
PKGVER="${PKGVER//-/_}"
PKGREL="1"
[[ "$RAW" == *+* ]] && PKGREL="${RAW##*+}"

# Paketleyici: INKEN_MAINTAINER, yoksa git kullanıcısı, o da yoksa yer tutucu.
PACKAGER="${INKEN_MAINTAINER:-}"
if [[ -z "$PACKAGER" ]]; then
  name="$(git -C "$ROOT" config user.name || true)"
  email="$(git -C "$ROOT" config user.email || true)"
  if [[ -n "$name" && -n "$email" ]]; then
    PACKAGER="$name <$email>"
  else
    PACKAGER="Inken PDF <noreply@invalid>"
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/packaging/arch/PKGBUILD" "$WORK/"
mkdir -p "$OUT"

(cd "$WORK" && \
  INKEN_ROOT="$ROOT" INKEN_PKGVER="$PKGVER" INKEN_PKGREL="$PKGREL" \
  PACKAGER="$PACKAGER" PKGDEST="$OUT" PKGEXT=".pkg.tar.zst" \
  BUILDDIR="$WORK/build" SRCDEST="$WORK/src" \
  makepkg -f --nodeps --noconfirm)

PKG="$OUT/inken-pdf-${PKGVER}-${PKGREL}-x86_64.pkg.tar.zst"
echo "Paket: $PKG ($(du -h "$PKG" | cut -f1))"
echo "Kurmak için: sudo pacman -U \"$PKG\""
