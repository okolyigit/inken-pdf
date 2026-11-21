#!/usr/bin/env python3
"""Elle yazılmış küçük test PDF'leri üretir.

Dış Python bağımlılığı yok. Yalnızca encrypted.pdf ve user_password.pdf için
Ghostscript (`gs`) gerekir; yoksa o dosyalar atlanır.

rotated.pdf:      5 sayfa, MediaBox 400x600.
                  1-4: /Rotate 0, 90, 180, 270
                  5:   CropBox [50 100 350 500] (orijini kaydırılmış kutu)
                  Her sayfada kullanıcı uzayının sol alt köşesine yakın gri kare.
single_page.pdf:  tek A4 sayfa, metin.
hundred_pages.pdf: 100 A4 sayfa, her birinde sayfa numarası.
mixed_sizes.pdf:  A4 dikey, A4 yatay, Letter, A5, kare.
scanned.pdf:      2 sayfa, yalnızca resim (taranmış belge gibi; metin yok).
form.pdf:         AcroForm: doldurulmuş bir metin alanı ve işaretli onay kutusu
                  (başkasının açıklamaları: Widget).
encrypted.pdf:    two_pages.pdf'in yalnızca sahip parolalı (açmak için parola
                  gerekmez, düzenleme kısıtlı) kopyası; Ghostscript ile.
user_password.pdf: two_pages.pdf'in açılış parolalı kopyası (parola: 1234);
                  Ghostscript ile.
links.pdf:        3 sayfa. 1. sayfada "Bolum 2" / "Bolum 3" (sayfaya giden
                  bağlantılar) ve "Web sitesi" (https://example.org); yer
                  imleri ağacı: Bolum 1..3, Bolum 2'nin altında "Alt baslik";
                  belge bilgileri (başlık "Işık ve Gölge", yazar, tarih).

Yalnızca bazılarını üretmek için adlarını verin:
  python3 make_fixtures.py links.pdf
"""
import pathlib
import shutil
import subprocess
import sys
import zlib

here = pathlib.Path(__file__).parent

A4 = (595, 842)


class Pdf:
    """En küçük PDF yazıcı: nesneleri sırayla ekler, xref'i hesaplar."""

    def __init__(self):
        self.objs = [None, None]  # 1: Catalog, 2: Pages
        self.kids = []
        self.catalog_extra = b""
        self.trailer_extra = b""

    def add(self, body):
        self.objs.append(body)
        return len(self.objs)

    def stream(self, data, extra=b"", compress=False):
        if compress:
            data = zlib.compress(data)
            extra += b" /Filter /FlateDecode"
        return self.add(
            b"<< /Length %d%s >>\nstream\n%s\nendstream" % (len(data), extra, data))

    def page(self, size, content, resources=b"<< >>", extra=b""):
        cid = self.stream(content)
        pid = self.add(None)
        self.objs[pid - 1] = (
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] "
            b"/Resources %s /Contents %d 0 R %s >>"
            % (size[0], size[1], resources, cid, extra))
        self.kids.append(pid)
        return pid

    def bytes(self):
        self.objs[0] = b"<< /Type /Catalog /Pages 2 0 R %s >>" % self.catalog_extra
        self.objs[1] = b"<< /Type /Pages /Kids [%s] /Count %d >>" % (
            b" ".join(b"%d 0 R" % k for k in self.kids), len(self.kids))
        out = bytearray(b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
        offsets = []
        for i, body in enumerate(self.objs, 1):
            offsets.append(len(out))
            out += b"%d 0 obj\n%s\nendobj\n" % (i, body)
        xref = len(out)
        out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(self.objs) + 1)
        for o in offsets:
            out += b"%010d 00000 n \n" % o
        out += b"trailer\n<< /Size %d /Root 1 0 R %s>>\nstartxref\n%d\n%%%%EOF\n" % (
            len(self.objs) + 1, self.trailer_extra, xref)
        return bytes(out)


def helvetica(pdf):
    font = pdf.add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    return b"<< /Font << /F1 %d 0 R >> >>" % font


def text(x, y, size, s):
    return b"BT /F1 %d Tf %d %d Td (%s) Tj ET" % (size, x, y, s)


def rotated():
    pdf = Pdf()
    for extra in [b"/Rotate 0", b"/Rotate 90", b"/Rotate 180", b"/Rotate 270",
                  b"/CropBox [50 100 350 500]"]:
        pdf.page((400, 600), b"0.6 g 20 20 30 30 re f", extra=extra)
    return pdf.bytes()


def single_page():
    pdf = Pdf()
    res = helvetica(pdf)
    pdf.page(A4, text(72, 760, 24, b"Tek sayfa") + b"\n"
             + text(72, 720, 12, b"1) 3x - 5 = 10 denklemini cozunuz."), res)
    return pdf.bytes()


def hundred_pages():
    pdf = Pdf()
    res = helvetica(pdf)
    for i in range(1, 101):
        pdf.page(A4, text(72, 760, 24, b"Sayfa %d" % i) + b"\n"
                 + b"0.85 g 72 100 451 600 re f", res)
    return pdf.bytes()


def mixed_sizes():
    pdf = Pdf()
    res = helvetica(pdf)
    for (w, h), name in [(A4, b"A4 dikey"), ((842, 595), b"A4 yatay"),
                         ((612, 792), b"Letter"), ((420, 595), b"A5"),
                         ((500, 500), b"Kare")]:
        pdf.page((w, h), text(40, h - 60, 20, name)
                 + b"\n0 G 2 w 20 20 %d %d re S" % (w - 40, h - 40), res)
    return pdf.bytes()


def scanned():
    """Yalnızca resimden oluşan sayfalar: gri zemin üstünde koyu 'satırlar'."""
    pdf = Pdf()
    w, h = 300, 424  # ~A4 oranı, düşük çözünürlük
    for n in range(2):
        rows = bytearray()
        for y in range(h):
            line = (y // 12) % 3 == 0 and 30 < y < h - 30
            for x in range(w):
                ink = line and 25 < x < w - 25 - (y * 7 + n * 50) % 90
                rows.append(40 if ink else 235 - (x + y) % 7)
        img = pdf.add(None)
        data = zlib.compress(bytes(rows))
        pdf.objs[img - 1] = (
            b"<< /Type /XObject /Subtype /Image /Width %d /Height %d "
            b"/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode "
            b"/Length %d >>\nstream\n%s\nendstream" % (w, h, len(data), data))
        pdf.page(A4, b"q 595 0 0 842 0 0 cm /Im0 Do Q",
                 b"<< /XObject << /Im0 %d 0 R >> >>" % img)
    return pdf.bytes()


def form():
    pdf = Pdf()
    font = pdf.add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    res = b"<< /Font << /F1 %d 0 R >> >>" % font
    tx_ap = pdf.stream(
        b"/Tx BMC q BT /F1 12 Tf 0 g 4 6 Td (Ayse Yilmaz) Tj ET Q EMC",
        b" /Type /XObject /Subtype /Form /BBox [0 0 200 24] /Resources %s" % res)
    on_ap = pdf.stream(
        b"q 0 g 1 w 3 3 12 12 re S 5 9 m 8 5 l 14 14 l S Q",
        b" /Type /XObject /Subtype /Form /BBox [0 0 18 18]")
    off_ap = pdf.stream(
        b"q 0 g 1 w 3 3 12 12 re S Q",
        b" /Type /XObject /Subtype /Form /BBox [0 0 18 18]")
    page_id = len(pdf.objs) + 4  # aşağıdaki iki alan + içerik akışından sonra
    name = pdf.add(
        b"<< /Type /Annot /Subtype /Widget /FT /Tx /T (ad) /V (Ayse Yilmaz) "
        b"/DA (/F1 12 Tf 0 g) /Rect [150 700 350 724] /F 4 /P %d 0 R "
        b"/AP << /N %d 0 R >> >>" % (page_id, tx_ap))
    check = pdf.add(
        b"<< /Type /Annot /Subtype /Widget /FT /Btn /T (onay) /V /Yes /AS /Yes "
        b"/Rect [150 660 168 678] /F 4 /P %d 0 R "
        b"/AP << /N << /Yes %d 0 R /Off %d 0 R >> >> >>"
        % (page_id, on_ap, off_ap))
    pid = pdf.page(A4, text(72, 706, 12, b"Ad:") + b"\n"
                   + text(72, 664, 12, b"Onay:"), res,
                   extra=b"/Annots [%d 0 R %d 0 R]" % (name, check))
    assert pid == page_id, (pid, page_id)
    pdf.catalog_extra = (
        b"/AcroForm << /Fields [%d 0 R %d 0 R] /DR %s /DA (/F1 12 Tf 0 g) >>"
        % (name, check, res))
    return pdf.bytes()


def encrypted():
    gs = shutil.which("gs")
    if gs is None:
        print("gs bulunamadı; encrypted.pdf atlandı")
        return
    subprocess.run([
        gs, "-q", "-dNOPAUSE", "-dBATCH", "-dSAFER", "-sDEVICE=pdfwrite",
        "-sOwnerPassword=inken-sahip", "-dEncryptionR=3", "-dKeyLength=128",
        # Yazdırmaya izin ver, değiştirmeyi ve kopyalamayı kısıtla.
        "-dPermissions=-1852",
        "-sOutputFile=%s" % (here / "encrypted.pdf"),
        str(here / "two_pages.pdf"),
    ], check=True)


def user_password():
    gs = shutil.which("gs")
    if gs is None:
        print("gs bulunamadı; user_password.pdf atlandı")
        return
    subprocess.run([
        gs, "-q", "-dNOPAUSE", "-dBATCH", "-dSAFER", "-sDEVICE=pdfwrite",
        "-sUserPassword=1234", "-sOwnerPassword=inken-sahip",
        "-dEncryptionR=3", "-dKeyLength=128",
        "-sOutputFile=%s" % (here / "user_password.pdf"),
        str(here / "two_pages.pdf"),
    ], check=True)


def links():
    pdf = Pdf()
    res = helvetica(pdf)
    # Sayfa nesneleri önce ayrılır: bağlantılar ve yer imleri onlara işaret
    # eder.
    p1 = pdf.add(None)
    p2 = pdf.page(A4, text(72, 760, 24, b"Bolum 2") + b"\n"
                  + text(72, 500, 18, b"Alt baslik"), res)
    p3 = pdf.page(A4, text(72, 760, 24, b"Bolum 3"), res)
    pdf.kids.insert(0, p1)

    def goto(rect, page):
        return pdf.add(b"<< /Type /Annot /Subtype /Link /Rect [%s] /Border [0 0 0] "
                       b"/Dest [%d 0 R /XYZ 0 842 0] >>" % (rect, page))

    a2 = goto(b"72 690 200 714", p2)
    a3 = goto(b"72 650 200 674", p3)
    web = pdf.add(b"<< /Type /Annot /Subtype /Link /Rect [72 610 260 634] "
                  b"/Border [0 0 0] /A << /S /URI /URI (https://example.org) >> >>")
    content = (text(72, 760, 24, b"Icindekiler") + b"\n"
               + text(72, 696, 18, b"Bolum 2") + b"\n"
               + text(72, 656, 18, b"Bolum 3") + b"\n"
               + text(72, 616, 18, b"Web sitesi"))
    cid = pdf.stream(content)
    pdf.objs[p1 - 1] = (
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Resources %s "
        b"/Contents %d 0 R /Annots [%d 0 R %d 0 R %d 0 R] >>"
        % (A4[0], A4[1], res, cid, a2, a3, web))

    # Yer imleri: Bolum 1, Bolum 2 (altında Alt baslik), Bolum 3.
    root = pdf.add(None)
    b1, b2, b3, sub = (pdf.add(None) for _ in range(4))

    def item(title, page, y, parent, prev=None, nxt=None, kids=None):
        extra = b""
        if prev:
            extra += b" /Prev %d 0 R" % prev
        if nxt:
            extra += b" /Next %d 0 R" % nxt
        if kids:
            extra += b" /First %d 0 R /Last %d 0 R /Count %d" % (
                kids[0], kids[-1], len(kids))
        return (b"<< /Title (%s) /Parent %d 0 R /Dest [%d 0 R /XYZ 0 %d 0]%s >>"
                % (title, parent, page, y, extra))

    pdf.objs[b1 - 1] = item(b"Bolum 1", p1, 842, root, nxt=b2)
    pdf.objs[b2 - 1] = item(b"Bolum 2", p2, 842, root, prev=b1, nxt=b3,
                            kids=[sub])
    pdf.objs[sub - 1] = item(b"Alt baslik", p2, 530, b2)
    pdf.objs[b3 - 1] = item(b"Bolum 3", p3, 842, root, prev=b2)
    pdf.objs[root - 1] = (b"<< /Type /Outlines /First %d 0 R /Last %d 0 R "
                          b"/Count 4 >>" % (b1, b3))
    pdf.catalog_extra = b"/Outlines %d 0 R" % root
    # Belge bilgileri: başlık Türkçe harfli (UTF-16BE), tarih saat dilimli.
    title = "Işık ve Gölge".encode("utf-16-be").hex().upper().encode()
    info = pdf.add(b"<< /Title <FEFF%s> /Author (Inken Test) /Subject (Bagl"
                   b"antilar) /Creator (make_fixtures.py) /CreationDate "
                   b"(D:20261119093000+03'00') >>" % title)
    pdf.trailer_extra = b"/Info %d 0 R " % info
    return pdf.bytes()


builders = [("rotated.pdf", rotated), ("single_page.pdf", single_page),
            ("hundred_pages.pdf", hundred_pages),
            ("mixed_sizes.pdf", mixed_sizes), ("scanned.pdf", scanned),
            ("form.pdf", form), ("links.pdf", links)]
wanted = set(sys.argv[1:])
for name, build in builders:
    if not wanted or name in wanted:
        (here / name).write_bytes(build())
if not wanted or "encrypted.pdf" in wanted:
    encrypted()
if not wanted or "user_password.pdf" in wanted:
    user_password()
