import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  group('sayfa aralığı', () {
    test('tek, aralık, karışık; boşluk ve en tire', () {
      expect(parsePageRanges('2', 5), [1]);
      expect(parsePageRanges('1-3, 5', 5), [0, 1, 2, 4]);
      expect(parsePageRanges(' 2 – 4 ;1', 5), [1, 2, 3, 0]);
      expect(parsePageRanges('3-1', 5), [2, 1, 0], reason: 'geriye doğru');
    });

    test('geçersiz ya da sınır dışı: null', () {
      expect(parsePageRanges('', 5), isNull);
      expect(parsePageRanges('0', 5), isNull);
      expect(parsePageRanges('6', 5), isNull);
      expect(parsePageRanges('1-', 5), isNull);
      expect(parsePageRanges('a', 5), isNull);
      expect(parsePageRanges('1-9', 5), isNull);
    });
  });

  group('yazdırma sırası', () {
    test('kopya, harmanlama, ters', () {
      expect(printSequence([0, 1, 2]), [0, 1, 2]);
      expect(printSequence([0, 1], copies: 2), [0, 1, 0, 1]);
      expect(printSequence([0, 1], copies: 2, collate: false), [0, 0, 1, 1]);
      expect(printSequence([0, 1, 2], reverse: true), [2, 1, 0]);
      expect(printSequence([0, 1], copies: 0), [0, 1]);
    });
  });

  group('kâğıda yerleştirme', () {
    final a4 = PaperSize.a4;

    test('A4 sayfa A4 kâğıda sığdırılınca tam kaplar', () {
      final p = placeOnPaper(
        pageWidth: a4.widthPt,
        pageHeight: a4.heightPt,
        paperWidth: a4.widthPt,
        paperHeight: a4.heightPt,
        unitsPerPt: 1,
        fit: true,
      );
      expect(p.rotate, isFalse);
      expect(p.x, closeTo(0, 1e-6));
      expect(p.width, closeTo(a4.widthPt, 1e-6));
    });

    test(
      'otomatik yön: yatay sayfa dikey kâğıtta döner; elle yönde dönmez',
      () {
        final auto = placeOnPaper(
          pageWidth: 842,
          pageHeight: 595,
          paperWidth: 595,
          paperHeight: 842,
          unitsPerPt: 1,
          fit: true,
        );
        expect(auto.rotate, isTrue);
        expect(auto.width, closeTo(595, 1e-6));
        final manual = placeOnPaper(
          pageWidth: 842,
          pageHeight: 595,
          paperWidth: 595,
          paperHeight: 842,
          unitsPerPt: 1,
          fit: true,
          orientation: PrintOrientation.portrait,
        );
        expect(manual.rotate, isFalse);
        expect(manual.width, closeTo(595, 1e-6));
        expect(manual.height, closeTo(595 * 595 / 842, 1e-6));
        expect(manual.y, greaterThan(0), reason: 'dikeyde ortalanır');
      },
    );

    test('yazdırılabilir alana sığdırma ve ortalama', () {
      final p = placeOnPaper(
        pageWidth: 100,
        pageHeight: 100,
        paperWidth: 300,
        paperHeight: 400,
        unitsPerPt: 1,
        fit: true,
        area: (x: 10, y: 20, width: 280, height: 360),
      );
      expect((p.x, p.y, p.width, p.height), (10, 60, 280, 280));
    });

    test('gerçek boyut: dpi ile ölçeklenir, kâğıtta ortalanır', () {
      // A5 sayfa, A4 kâğıt, 300 dpi.
      const dpi = 300.0;
      final paper = (
        width: a4.widthPt * dpi / 72,
        height: a4.heightPt * dpi / 72,
      );
      final p = placeOnPaper(
        pageWidth: PaperSize.a5.widthPt,
        pageHeight: PaperSize.a5.heightPt,
        paperWidth: paper.width,
        paperHeight: paper.height,
        unitsPerPt: dpi / 72,
        fit: false,
      );
      expect(p.width, closeTo(148 / 25.4 * dpi, 0.01));
      expect(p.x, closeTo((paper.width - p.width) / 2, 1e-6));
    });

    test('kâğıt yönü', () {
      final l = orientedPaper(210, 297, PrintOrientation.landscape);
      expect((l.width, l.height), (297, 210));
      final p = orientedPaper(297, 210, PrintOrientation.auto);
      expect((p.width, p.height), (210, 297));
    });
  });
}
