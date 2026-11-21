import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  final doc = InkenDocument.forPdf([
    (width: 595, height: 842),
    (width: 842, height: 595),
    (width: 595, height: 842),
  ]);
  const stroke = Stroke(
    id: 'a',
    tool: InkTool.pen,
    color: 0xFF000000,
    width: 2,
    points: [InkPoint(1, 2), InkPoint(3, 4)],
  );

  group('sayfa ekleme / silme', () {
    test('yeni sayfa yanındakinin boyutunda, şablonuyla', () {
      final p = newPageLike(doc, 1, PageTemplate.grid);
      expect(p.isInserted, isTrue);
      expect((p.width, p.height), (842.0, 595.0));
      expect(p.template, PageTemplate.grid);
      expect(p.items, isEmpty);
    });

    test('silme geri alınınca sayfa çizimleriyle geri gelir', () {
      final withInk = AddItems(1, [stroke]).apply(doc);
      final h = EditHistory(withInk);
      h.execute(RemovePage(1, withInk.pages[1]));
      expect(h.document.pages.map((p) => p.sourceIndex), [0, 2]);
      h.undo();
      expect(h.document, withInk);
      h.redo();
      expect(h.document.pages.length, 2);
    });

    test('ekle → sil → geri al zinciri', () {
      final h = EditHistory(doc);
      final blank = newPageLike(doc, 0, PageTemplate.blank);
      h.execute(InsertPage(1, blank));
      h.execute(RemovePage(0, h.document.pages[0]));
      expect(h.document.pages.map((p) => p.sourceIndex), [null, 1, 2]);
      h.undo();
      h.undo();
      expect(h.document, doc);
    });
  });

  group('düzen anahtarı', () {
    test('çizimler anahtarı değiştirmez, düzen değiştirir', () {
      final key = pageLayoutKey(doc);
      expect(pageLayoutKey(AddItems(0, [stroke]).apply(doc)), key);
      final inserted = InsertPage(
        1,
        newPageLike(doc, 0, PageTemplate.dotted),
      ).apply(doc);
      expect(pageLayoutKey(inserted), isNot(key));
      final removed = RemovePage(2, doc.pages[2]).apply(doc);
      expect(pageLayoutKey(removed), isNot(key));
    });

    test('dosyanın kendi düzeni', () {
      expect(isSourceLayout(doc, 3), isTrue);
      expect(isSourceLayout(doc, 4), isFalse);
      expect(
        isSourceLayout(RemovePage(1, doc.pages[1]).apply(doc), 3),
        isFalse,
      );
      expect(
        isSourceLayout(
          InsertPage(3, newPageLike(doc, 2, PageTemplate.blank)).apply(doc),
          3,
        ),
        isFalse,
      );
    });

    test('yalnızca düzen: çizimler boşaltılır', () {
      final only = pageLayoutOnly(AddItems(0, [stroke]).apply(doc));
      expect(only.pages.every((p) => p.items.isEmpty), isTrue);
      expect(pageLayoutKey(only), pageLayoutKey(doc));
    });
  });

  group('silinmiş sayfalı model ve dosya', () {
    final removed = RemovePage(1, doc.pages[1]).apply(doc);

    test('silmeye izin verilince uyar, verilmeyince uymaz', () {
      expect(fitsSourcePages(removed, 3), isFalse);
      expect(fitsSourcePages(removed, 3, allowRemoved: true), isTrue);
      expect(fitsSourcePages(removed, 2, allowRemoved: true), isFalse);
      final reversed = removed.copyWith(
        pages: removed.pages.reversed.toList(),
      );
      expect(fitsSourcePages(reversed, 3, allowRemoved: true), isFalse);
    });

    test('yedek sayfa sayısını saklar; eski yedek eski kuralla', () {
      final backup = InkenBackup(
        sourcePath: '/a.pdf',
        sourceLength: 1,
        sourceModified: DateTime.utc(2026),
        savedAt: DateTime.utc(2026),
        document: removed,
        sourcePageCount: 3,
      );
      final back = InkenBackup.decode(backup.encode());
      expect(back.sourcePageCount, 3);
      expect(back.fitsFile(3), isTrue);
      expect(back.fitsFile(2), isFalse);
      final old = InkenBackup(
        sourcePath: '/a.pdf',
        sourceLength: 1,
        sourceModified: DateTime.utc(2026),
        savedAt: DateTime.utc(2026),
        document: doc,
      );
      final oldBack = InkenBackup.decode(old.encode());
      expect(oldBack.sourcePageCount, isNull);
      expect(oldBack.fitsFile(3), isTrue);
      expect(oldBack.fitsFile(4), isFalse);
    });
  });

  group('kâğıt boyutu adı', () {
    test('bilinen boyutlar, iki yönde', () {
      expect(paperSizeName(595.28, 841.89), 'A4');
      expect(paperSizeName(842, 595), 'A4');
      expect(paperSizeName(612, 792), 'Letter');
      expect(paperSizeName(1190.55, 841.89), 'A3');
    });

    test('bilinmeyen boyut', () {
      expect(paperSizeName(600, 800), isNull);
      expect(paperSizeName(595.28, 850), isNull);
    });

    test('pt → mm', () {
      expect(ptToMm(595.28), 210);
      expect(ptToMm(841.89), 297);
      expect(ptToMm(72), 25);
    });
  });

  group('sayfa rengi', () {
    final doc = InkenDocument.forPdf(const [(width: 595, height: 842)]);

    test('eklenen sayfa rengi; beyaz alan boş', () {
      final black = newPageLike(
        doc,
        0,
        PageTemplate.grid,
        color: PageColor.black,
      );
      expect(black.color, PageColor.black);
      expect(newPageLike(doc, 0, PageTemplate.grid).color, isNull);
      expect(
        newPageLike(doc, 0, PageTemplate.blank, color: PageColor.white).color,
        isNull,
      );
    });

    test('renk düzen anahtarına girer', () {
      InkenDocument withPage(PageColor c) => doc.copyWith(
        pages: [
          ...doc.pages,
          newPageLike(doc, 0, PageTemplate.blank, color: c),
        ],
      );
      expect(
        pageLayoutKey(withPage(PageColor.straw)),
        isNot(pageLayoutKey(withPage(PageColor.black))),
      );
    });

    test('kayıt gidiş-dönüş; beyazda alan yazılmaz', () {
      final d = doc.copyWith(
        pages: [
          ...doc.pages,
          newPageLike(doc, 0, PageTemplate.lined, color: PageColor.straw),
          newPageLike(doc, 0, PageTemplate.lined),
        ],
      );
      final json = encodeInkenDocument(d);
      expect('"color":"straw"'.allMatches(json), hasLength(1));
      expect(decodeInkenDocument(json), d);
    });

    test('renk değerleri', () {
      expect(pageColorArgb(PageColor.white), 0xFFFFFFFF);
      expect(pageColorArgb(PageColor.black) & 0xFFFFFF, lessThan(0x202020));
    });
  });
}
