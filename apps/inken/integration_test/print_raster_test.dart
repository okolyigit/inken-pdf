// Yazdırma görüntüleri gerçek PDFium'la (Windows'ta yazıcıya giden sayfalar):
// boyut, yön ve döndürmenin doğruluğu.
// Çalıştır: flutter test integration_test/print_raster_test.dart -d linux
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

Future<PdfPrintRasterizer> _open(String name) async {
  await initInkenPdf();
  return PdfPrintRasterizer.open(
    File('../../test/fixtures/$name').readAsBytesSync(),
  );
}

/// (x, y) pikselinin parlaklığı (0..255).
int _luma(PrintRaster r, int x, int y) {
  final i = (y * r.width + x) * 4;
  return (r.bgra[i] + r.bgra[i + 1] + r.bgra[i + 2]) ~/ 3;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dikey kâğıtta sayfalar alana sığar, BGRA boyutu doğru', (
    t,
  ) async {
    final pdf = await _open('mixed_sizes.pdf');
    addTearDown(pdf.dispose);
    expect(pdf.pageCount, 5);
    const boxW = 1000, boxH = 1400;
    for (var i = 0; i < pdf.pageCount; i++) {
      final r = await pdf.render(i, boxW, boxH);
      expect(r.bgra.length, r.width * r.height * 4);
      expect(r.width, lessThanOrEqualTo(boxW));
      expect(r.height, lessThanOrEqualTo(boxH));
      expect(r.width == boxW || r.height == boxH, isTrue, reason: 'sayfa $i');
      expect(r.height, greaterThanOrEqualTo(r.width), reason: 'sayfa $i dik');
    }
  });

  testWidgets('yatay sayfa dikey kâğıda saat yönünde çeyrek tur döner', (
    t,
  ) async {
    final pdf = await _open('mixed_sizes.pdf');
    addTearDown(pdf.dispose);
    // 2. sayfa yatay A4. Yatay alanda olduğu gibi, dikey alanda döndürülmüş.
    final flat = await pdf.render(1, 1400, 989);
    final turned = await pdf.render(1, 989, 1400);
    expect((flat.width, flat.height), (1400, 989));
    expect((turned.width, turned.height), (989, 1400));

    // Saat yönünde: turned(x, y) = flat(y, H - 1 - x).
    var diff = 0, wrong = 0, ink = 0, samples = 0;
    for (var y = 5; y < turned.height - 5; y += 23) {
      for (var x = 5; x < turned.width - 5; x += 23) {
        final a = _luma(turned, x, y);
        final b = _luma(flat, y, flat.height - 1 - x);
        diff += (a - b).abs();
        // Ters yön (saat yönünün tersi): flat(W - 1 - y, x).
        wrong += (a - _luma(flat, flat.width - 1 - y, x)).abs();
        if (a < 200) ink++;
        samples++;
      }
    }
    expect(ink, greaterThan(0), reason: 'sayfada çizili bir şey olmalı');
    expect(diff / samples, lessThan(6), reason: 'döndürme yönü');
    expect(wrong, greaterThan(diff * 3), reason: 'test ters yönü ayırt eder');
  });

  testWidgets('/Rotate 90 sayfa dikey kâğıtta dik çıkar', (t) async {
    final pdf = await _open('rotated.pdf');
    addTearDown(pdf.dispose);
    for (var i = 0; i < pdf.pageCount; i++) {
      final r = await pdf.render(i, 1000, 1400);
      expect(r.height, greaterThan(r.width), reason: 'sayfa $i');
    }
  });
}
