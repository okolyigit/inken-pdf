import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  group('captureRegion', () {
    test('ters yönde sürükleme düzgün dikdörtgen verir', () {
      final r = captureRegion(
        300,
        400,
        100,
        150,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(r, (left: 100.0, top: 150.0, right: 300.0, bottom: 400.0));
    });

    test('sayfa dışına taşan kısım kırpılır', () {
      final r = captureRegion(
        -50,
        -20,
        700,
        900,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(r, (left: 0.0, top: 0.0, right: 595.0, bottom: 842.0));
    });

    test('küçük sürükleme bölge değildir', () {
      expect(
        captureRegion(10, 10, 13, 200, pageWidth: 595, pageHeight: 842),
        isNull,
      );
      expect(
        captureRegion(10, 10, 10, 10, pageWidth: 595, pageHeight: 842),
        isNull,
      );
    });

    test('tamamen sayfa dışındaki sürükleme bölge değildir', () {
      expect(
        captureRegion(600, 10, 700, 200, pageWidth: 595, pageHeight: 842),
        isNull,
      );
    });

    test('wholePage sayfanın tamamı', () {
      const p = PageLayer(width: 595, height: 842);
      expect(wholePage(p), (left: 0.0, top: 0.0, right: 595.0, bottom: 842.0));
    });
  });

  group('captureSize', () {
    test('200 dpi: 72 pt = 200 px', () {
      final s = captureSize((left: 0, top: 0, right: 72, bottom: 36));
      expect((s.width, s.height), (200, 100));
      expect(s.scale, closeTo(200 / 72, 1e-9));
    });

    test('uzun kenar sınırı aşılmaz, oran korunur', () {
      // A4'ün tamamı 200 dpi'de 1653 × 2339; sınır 1000.
      final s = captureSize((
        left: 0,
        top: 0,
        right: 595,
        bottom: 842,
      ), maxPixels: 1000);
      expect(s.height, 1000);
      expect(s.width / s.height, closeTo(595 / 842, 0.002));
    });

    test('çok ince bölge en az 1 piksel', () {
      final s = captureSize((left: 0, top: 0, right: 0.01, bottom: 500));
      expect(s.width, 1);
    });

    test('boş bölge hata verir', () {
      expect(
        () => captureSize((left: 5, top: 5, right: 5, bottom: 10)),
        throwsArgumentError,
      );
    });
  });

  group('pageSubset', () {
    final doc = InkenDocument.forPdf([
      (width: 595, height: 842),
      (width: 842, height: 595),
      (width: 595, height: 842),
    ]);

    test('verilen sayfalar verilen sırayla', () {
      final s = pageSubset(doc, [2, 0]);
      expect(s.pages.map((p) => p.sourceIndex), [2, 0]);
      expect(s.formatVersion, doc.formatVersion);
    });

    test('eklenen sayfa da alınır', () {
      final withInserted = InsertPage(
        1,
        newPageLike(doc, 0, PageTemplate.grid),
      ).apply(doc);
      final s = pageSubset(withInserted, [1]);
      expect(s.pages.single.isInserted, isTrue);
      expect(s.pages.single.template, PageTemplate.grid);
    });

    test('geçersiz, tekrarlanan ya da boş liste hata verir', () {
      expect(() => pageSubset(doc, [3]), throwsRangeError);
      expect(() => pageSubset(doc, [0, 0]), throwsArgumentError);
      expect(() => pageSubset(doc, const []), throwsArgumentError);
    });

    test('kopya gidiş-dönüşte bozulmaz', () {
      final s = pageSubset(doc, [1]);
      expect(decodeInkenDocument(encodeInkenDocument(s)), s);
    });
  });

  group('placeCapture', () {
    test('küçük bölge kaynaktaki boyutunda, üstte ortalı', () {
      final p = placeCapture(
        regionWidth: 300,
        regionHeight: 100,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect((p.width, p.height), (300.0, 100.0));
      expect(p.x, closeTo((595 - 300) / 2, 1e-9));
      expect(p.y, 36);
    });

    test('geniş bölge sayfa genişliğine sığdırılır', () {
      final p = placeCapture(
        regionWidth: 842,
        regionHeight: 200,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(p.width, closeTo(595 - 72, 1e-9));
      expect(p.height / p.width, closeTo(200 / 842, 1e-9));
      expect(p.x, closeTo(36, 1e-9));
    });

    test('uzun bölge sayfa yüksekliğinin %60ına sığdırılır', () {
      final p = placeCapture(
        regionWidth: 400,
        regionHeight: 842,
        pageWidth: 595,
        pageHeight: 842,
      );
      expect(p.height, closeTo(842 * 0.6, 1e-9));
      expect(p.width / p.height, closeTo(400 / 842, 1e-9));
    });

    test('sayfanın dışına taşmaz', () {
      final p = placeCapture(
        regionWidth: 5000,
        regionHeight: 5000,
        pageWidth: 100,
        pageHeight: 80,
      );
      expect(p.x, greaterThanOrEqualTo(0));
      expect(p.x + p.width, lessThanOrEqualTo(100));
      expect(p.y + p.height, lessThanOrEqualTo(80));
    });
  });
}
