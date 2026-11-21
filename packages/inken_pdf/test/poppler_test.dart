// Görsel kontrol, PDFium'dan bağımsız ikinci bir motorla: kaydedilen dosya
// Poppler'ın `pdftoppm`'iyle (Okular, Evince ve birçok Linux okuyucusunun
// motoru) çizilir; çizgilerin ve görsellerin yerinde ve doğru yönde olduğu
// piksel piksel denetlenir. `pdftoppm` yoksa testler atlanır (CI'da kurulu).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'pdfium_test_helper.dart';

final bool _hasPoppler = () {
  try {
    return Process.runSync('pdftoppm', ['-v']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// Poppler'ın çizdiği sayfa (1 pt = 1 piksel, CropBox, RGB).
class _Ppm {
  _Ppm(this.width, this.height, this.rgb);
  final int width, height;
  final Uint8List rgb;

  int at(int x, int y) {
    final i = (y * width + x) * 3;
    return rgb[i] << 16 | rgb[i + 1] << 8 | rgb[i + 2];
  }
}

_Ppm _render(Uint8List pdf, int page) {
  final dir = Directory.systemTemp.createTempSync('inken_poppler');
  try {
    final input = File('${dir.path}/in.pdf')..writeAsBytesSync(pdf);
    final r = Process.runSync('pdftoppm', [
      '-r', '72', '-cropbox', '-singlefile', //
      '-f', '${page + 1}', '-l', '${page + 1}',
      input.path, '${dir.path}/out',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return _parsePpm(File('${dir.path}/out.ppm').readAsBytesSync());
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// P6 (ikili) PPM: `P6 en boy 255` başlığı, ardından RGB baytları.
_Ppm _parsePpm(Uint8List b) {
  var i = 0;
  String token() {
    while (true) {
      while (b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x0D || b[i] == 0x09) {
        i++;
      }
      if (b[i] != 0x23) break; // '#' yorum satırı
      while (b[i] != 0x0A) {
        i++;
      }
    }
    final start = i;
    while (b[i] > 0x20) {
      i++;
    }
    return String.fromCharCodes(b.sublist(start, i));
  }

  expect(token(), 'P6');
  final w = int.parse(token()), h = int.parse(token());
  expect(token(), '255');
  i++; // başlıktan sonraki tek boşluk
  return _Ppm(w, h, Uint8List.sublistView(b, i, i + w * h * 3));
}

/// [rgb] [target]'a kanal kanal [tolerance] içinde mi?
bool _near(int rgb, int target, {int tolerance = 24}) {
  for (final shift in [16, 8, 0]) {
    if (((rgb >> shift & 0xFF) - (target >> shift & 0xFF)).abs() > tolerance) {
      return false;
    }
  }
  return true;
}

String _tone(int rgb) {
  final r = rgb >> 16 & 0xFF, g = rgb >> 8 & 0xFF, b = rgb & 0xFF;
  if (r > 200 && g > 200 && b > 200) return 'beyaz';
  if (r > 180 && g < 90 && b < 90) return 'kırmızı';
  if (g > 180 && r < 90 && b < 90) return 'yeşil';
  if (b > 180 && r < 90 && g < 90) return 'mavi';
  return rgb.toRadixString(16);
}

final _png = Uint8List.fromList([137, 80, 78, 71, 0]);
final _imageId = imageAssetId(_png);

/// 2x2 görsel: sol üst kırmızı, sağ üst yeşil, sol alt mavi, sağ alt saydam.
final _images = {
  _imageId: InkenImage(
    png: _png,
    width: 2,
    height: 2,
    rgba: Uint8List.fromList([
      ...[255, 0, 0, 255, 0, 255, 0, 255],
      ...[0, 0, 255, 255, 0, 0, 0, 0],
    ]),
  ),
};

void main() {
  setUpPdfium();

  test(
    'döndürülmüş ve kırpılmış sayfalarda çizgi ve görsel yerinde (Poppler)',
    () {
      final src = fixture('rotated.pdf');
      final sizes = pageSizes(src);
      final base = InkenDocument.forPdf(sizes);
      final doc = base.copyWith(
        pages: [
          for (final (i, p) in base.pages.indexed)
            p.copyWith(
              items: [
                Stroke(
                  id: 's$i',
                  tool: InkTool.pen,
                  color: 0xFFD32F2F,
                  width: 4,
                  points: [
                    InkPoint(p.width * 0.15, p.height * 0.2),
                    InkPoint(p.width * 0.35, p.height * 0.2),
                  ],
                ),
                ImageItem(
                  id: 'g$i',
                  imageId: _imageId,
                  x: p.width * 0.5,
                  y: p.height * 0.5,
                  width: 80,
                  height: 80,
                ),
              ],
            ),
        ],
      );
      final saved = writeInkenPdf(
        (src, encodeInkenDocument(doc)),
        null,
        _images,
      );
      for (final (i, p) in sizes.indexed) {
        final img = _render(saved.pdf, i);
        expect(
          (img.width, img.height),
          (p.width.round(), p.height.round()),
          reason: 'sayfa $i: boyut',
        );
        expect(
          _tone(img.at((p.width * 0.25).round(), (p.height * 0.2).round())),
          'kırmızı',
          reason: 'sayfa $i: çizgi yerinde değil',
        );
        expect(
          _tone(img.at((p.width * 0.75).round(), (p.height * 0.8).round())),
          'beyaz',
          reason: 'sayfa $i: ters köşe boş olmalı',
        );
        final gx = (p.width * 0.5).round(), gy = (p.height * 0.5).round();
        expect(
          [
            _tone(img.at(gx + 20, gy + 20)),
            _tone(img.at(gx + 60, gy + 20)),
            _tone(img.at(gx + 20, gy + 60)),
            _tone(img.at(gx + 60, gy + 60)),
          ],
          ['kırmızı', 'yeşil', 'mavi', 'beyaz'],
          reason: 'sayfa $i: görsel yerinde ve doğru yönde değil',
        );
      }
    },
    skip: _hasPoppler ? false : 'pdftoppm (Poppler) kurulu değil',
  );

  test('düzleştirilmiş dışa aktarma Poppler\'da da çizimli', () {
    final src = fixture('two_pages.pdf');
    final base = InkenDocument.forPdf(pageSizes(src));
    final doc = base.copyWith(
      pages: [
        base.pages.first.copyWith(
          items: const [
            Shape(
              id: 'r',
              kind: ShapeKind.rectangle,
              color: 0xFF1F5AD6,
              width: 6,
              x1: 100,
              y1: 100,
              x2: 300,
              y2: 200,
            ),
            Stroke(
              id: 'h',
              tool: InkTool.highlighter,
              color: 0x66FFE34D,
              width: 20,
              points: [InkPoint(100, 400), InkPoint(400, 400)],
            ),
          ],
        ),
        ...base.pages.skip(1),
      ],
    );
    final flat = writeFlattenedPdf((src, encodeInkenDocument(doc)));
    final img = _render(flat.pdf, 0);
    expect(
      _near(img.at(100, 150), 0x1F5AD6),
      isTrue,
      reason: 'dikdörtgenin kenarı: ${img.at(100, 150).toRadixString(16)}',
    );
    expect(_tone(img.at(200, 150)), 'beyaz', reason: 'dikdörtgenin içi');
    // Fosforlu yarı saydam: sarımsı, beyazdan koyu.
    final hl = img.at(250, 400);
    expect(hl >> 16 & 0xFF, greaterThan(200));
    expect(hl & 0xFF, lessThan(200), reason: 'fosforlu görünmeli');
  }, skip: _hasPoppler ? false : 'pdftoppm (Poppler) kurulu değil');
}
