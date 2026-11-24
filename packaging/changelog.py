#!/usr/bin/env python3
"""Sürüm notlarından (packaging/release-notes/v*.md) CHANGELOG.md üretir.

Her sürüm bir başlık: sürüm ve tarih, en yenisi üstte. Tarih sürümün git
etiketinden okunur. Etiketi olmayan sürüm yalnızca pubspec'teki sürümse
(yayın hazırlanırken) bugünün tarihiyle girer; taslaklar (ör. v0.1.0.md)
girmez. Notların "Not", "Kurulum", "Geri bildirim" bölümleri her sürümde
aynı olduğu için alınmaz.

Çalıştır (deponun kökünde): python3 packaging/changelog.py
Yalnızca denetle: python3 packaging/changelog.py --check
"""

import datetime
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
NOTES = ROOT / "packaging" / "release-notes"
PUBSPEC = ROOT / "apps" / "inken" / "pubspec.yaml"
OUT = ROOT / "CHANGELOG.md"

# Depo 21 Kasım 2026'da sıfırlandı; ilk iki betanın etiketleri eski
# geçmişte kaldı.
LOST_TAGS = {
    "v0.1.0-beta.1": datetime.date(2026, 11, 12),
    "v0.1.0-beta.2": datetime.date(2026, 11, 12),
}

SKIPPED_SECTIONS = {"Not", "Kurulum", "Geri bildirim", "Bilinen eksikler"}

MONTHS = [
    "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]

HEADER = """# Değişiklik günlüğü

Inken PDF'in bütün sürümleri, en yenisi üstte. Her sürümün ayrıntılı notu
ve indirme dosyaları GitHub'daki sürüm sayfasındadır.

Bu dosya `packaging/release-notes/` klasöründeki notlardan üretilir
(`python3 packaging/changelog.py`); elle düzenlenmez.
"""


def version_key(tag):
    """v0.1.0-beta.12 → ((0, 1, 0), 0, 12); kararlı sürüm betalardan sonra."""
    m = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))?", tag)
    if not m:
        raise SystemExit(f"tanınmayan sürüm adı: {tag}")
    base = tuple(int(x) for x in m.groups()[:3])
    beta = m.group(4)
    return (base, 0, int(beta)) if beta else (base, 1, 0)


def tag_dates():
    out = subprocess.run(
        ["git", "for-each-ref", "--format=%(refname:short) %(creatordate:short)",
         "refs/tags"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    dates = dict(LOST_TAGS)
    for line in out.splitlines():
        tag, day = line.split()
        dates[tag] = datetime.date.fromisoformat(day)
    return dates


def pubspec_tag():
    m = re.search(r"^version:\s*(\S+?)(?:\+(\d+))?\s*$",
                  PUBSPEC.read_text(encoding="utf-8"), re.M)
    version, build = m.group(1), m.group(2)
    # 0.1.0+12 → v0.1.0-beta.12 (betalarda derleme numarası beta sırası).
    return f"v{version}-beta.{build}" if build else f"v{version}"


def body(text):
    """Giriş paragrafını ve hep aynı olan bölümleri atar, başlıkları bir
    kademe indirir."""
    sections = re.split(r"(?m)^(?=## )", text.strip())
    kept = []
    for part in sections[1:]:  # ilki giriş paragrafı
        title = part.splitlines()[0][3:].strip()
        if title in SKIPPED_SECTIONS:
            continue
        kept.append(re.sub(r"(?m)^(#+) ", r"#\1 ", part.strip()))
    return "\n\n".join(kept)


def turkish(day):
    return f"{day.day} {MONTHS[day.month - 1]} {day.year}"


def build():
    dates = tag_dates()
    upcoming = pubspec_tag()
    entries = []
    for path in NOTES.glob("v*.md"):
        tag = path.stem
        day = dates.get(tag)
        if day is None and tag == upcoming:
            day = datetime.date.today()
        if day is None:
            continue  # taslak
        entries.append((version_key(tag), tag, day, path))
    entries.sort(reverse=True)

    parts = [HEADER.strip()]
    for _, tag, day, path in entries:
        parts.append(f"## {tag[1:]} · {turkish(day)}\n\n"
                     f"{body(path.read_text(encoding='utf-8'))}")
    return "\n\n".join(parts) + "\n"


def main():
    text = build()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("CHANGELOG.md güncel değil: python3 packaging/changelog.py")
            sys.exit(1)
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} yazıldı")


if __name__ == "__main__":
    main()
