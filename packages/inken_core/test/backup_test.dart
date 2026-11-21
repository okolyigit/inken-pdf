import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

InkenDocument _doc() {
  final doc = InkenDocument.forPdf(const [
    (width: 595, height: 842),
    (width: 595, height: 842),
  ]);
  return doc.copyWith(
    pages: [
      doc.pages[0].copyWith(
        items: const [
          InkItem.stroke(
            id: 'a',
            tool: InkTool.pen,
            color: 0xFF000000,
            width: 2,
            points: [InkPoint(10, 20, 0.5), InkPoint(30, 40, 1)],
          ),
        ],
      ),
      doc.pages[1],
    ],
  );
}

void main() {
  group('yedek kaydı', () {
    final modified = DateTime.utc(2026, 11, 11, 10, 30, 15, 123);
    final backup = InkenBackup(
      sourcePath: '/home/öğretmen/Ders Notları/limit_inken.pdf',
      sourceName: 'limit_inken.pdf',
      sourceLength: 69163716,
      sourceModified: modified,
      savedAt: DateTime.utc(2026, 11, 11, 10, 31),
      document: _doc(),
    );

    test('gidiş-dönüş', () {
      final back = InkenBackup.decode(backup.encode());
      expect(back.sourcePath, backup.sourcePath);
      expect(back.sourceName, 'limit_inken.pdf');
      expect(back.sourceLength, backup.sourceLength);
      expect(back.sourceModified, modified);
      expect(back.savedAt, backup.savedAt);
      expect(back.document, backup.document);
    });

    test(
      'dosya değişmediyse eşleşir; boyut ya da zaman farklıysa eşleşmez',
      () {
        expect(
          backup.matchesSource(length: 69163716, modified: modified.toLocal()),
          isTrue,
        );
        expect(
          backup.matchesSource(length: 69163717, modified: modified),
          isFalse,
        );
        expect(
          backup.matchesSource(
            length: 69163716,
            modified: modified.add(const Duration(seconds: 1)),
          ),
          isFalse,
        );
      },
    );

    test('bozuk ya da bilinmeyen sürüm FormatException', () {
      expect(() => InkenBackup.decode('[]'), throwsFormatException);
      expect(() => InkenBackup.decode('{'), throwsFormatException);
      expect(
        () => InkenBackup.decode(
          backup.encode().replaceFirst(
            '"backupVersion":1',
            '"backupVersion":9',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => InkenBackup.decode(
          backup.encode().replaceFirst(
            '"sourceLength":69163716',
            '"sourceLength":"x"',
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('fitsSourcePages', () {
    test('dosya sayfaları sırayla; eklenen sayfalar sayılmaz', () {
      final doc = _doc();
      expect(fitsSourcePages(doc, 2), isTrue);
      expect(fitsSourcePages(doc, 3), isFalse);
      expect(fitsSourcePages(doc, 1), isFalse);
      final inserted = doc.copyWith(
        pages: [
          doc.pages[0],
          const PageLayer(width: 595, height: 842, template: PageTemplate.grid),
          doc.pages[1],
        ],
      );
      expect(fitsSourcePages(inserted, 2), isTrue);
    });

    test('sırası bozuk sayfalar uymaz', () {
      final doc = _doc();
      expect(
        fitsSourcePages(doc.copyWith(pages: doc.pages.reversed.toList()), 2),
        isFalse,
      );
    });
  });

  test('ReplaceDocument tek adımda geri alınır ve yinelenir', () {
    final empty = InkenDocument.forPdf(const [
      (width: 595, height: 842),
      (width: 595, height: 842),
    ]);
    final recovered = _doc();
    final history = EditHistory(empty)
      ..execute(ReplaceDocument(empty, recovered));
    expect(history.document, recovered);
    expect(history.isDirty, isTrue);
    expect(history.undo(), isTrue);
    expect(history.document, empty);
    expect(history.redo(), isTrue);
    expect(history.document, recovered);
  });
}
