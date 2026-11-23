import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_session.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

final _bytes = Uint8List.fromList([1, 2, 3]);

InkenReadResult _read({String? json, int pages = 2, bool protected = false}) =>
    (
      displayPdf: _bytes,
      inkenJson: json,
      pageCount: pages,
      isProtected: protected,
      images: const {},
    );

String _json(int pages) => encodeInkenDocument(
  InkenDocument.forPdf([
    for (var i = 0; i < pages; i++) (width: 10, height: 10),
  ]),
);

void main() {
  group('açılış doğrulaması', () {
    test('düz PDF: model yok', () {
      final d = documentFromRead(name: 'a.pdf', bytes: _bytes, read: _read());
      expect(d.model, isNull);
      expect(d.isInkenFile, isFalse);
    });

    test('Inken dosyası: model yüklenir', () {
      final d = documentFromRead(
        name: 'a.pdf',
        bytes: _bytes,
        read: _read(json: _json(2)),
      );
      expect(d.model!.pages, hasLength(2));
    });

    OpenFailure? failureOf(InkenReadResult r) {
      try {
        documentFromRead(name: 'a.pdf', bytes: _bytes, read: r);
        return null;
      } on OpenDocumentException catch (e) {
        return e.failure;
      }
    }

    test('bozuk, yeni sürüm ve sayfa uyuşmazlığı açılmaz', () {
      expect(failureOf(_read(json: '{oops')), OpenFailure.corruptData);
      expect(
        failureOf(_read(json: '{"formatVersion": 999, "pages": []}')),
        OpenFailure.newerFormat,
      );
      expect(failureOf(_read(json: _json(3))), OpenFailure.pageMismatch);
    });
  });

  group('kayıt yolu', () {
    final sep = Platform.pathSeparator;
    final dir = '${sep}ders$sep';
    OpenDocument doc(
      String path, {
      bool inken = false,
      bool protected = false,
      bool writable = true,
    }) => OpenDocument(
      name: 'x.pdf',
      bytes: _bytes,
      path: path,
      writable: writable,
      model: inken ? const InkenDocument() : null,
      isProtected: protected,
    );

    test('düz PDF → yanına _inken.pdf', () {
      expect(
        saveTargetFor(doc('${dir}test.pdf'), exists: (_) => false),
        '${dir}test_inken.pdf',
      );
      expect(
        saveTargetFor(doc('${dir}Test.PDF'), exists: (_) => false),
        '${dir}Test_inken.pdf',
      );
    });

    test('ad doluysa numara eklenir; hiçbir dosyanın üstüne yazılmaz', () {
      final taken = {'${dir}test_inken.pdf', '${dir}test_inken (2).pdf'};
      expect(
        saveTargetFor(doc('${dir}test.pdf'), exists: taken.contains),
        '${dir}test_inken (3).pdf',
      );
    });

    test('Inken dosyası kendi üstüne kaydedilir', () {
      expect(
        saveTargetFor(
          doc('${dir}test_inken.pdf', inken: true),
          exists: (_) => true,
        ),
        '${dir}test_inken.pdf',
      );
    });

    test('korumalı Inken dosyası yine kopyaya', () {
      expect(
        saveTargetFor(
          doc('${dir}x.pdf', inken: true, protected: true),
          exists: (_) => false,
        ),
        '${dir}x_inken.pdf',
      );
    });

    test('yeri bilinmeyen belge: sorulmalı', () {
      expect(saveTargetFor(OpenDocument(name: 'x.pdf', bytes: _bytes)), isNull);
    });

    group('Android (content:// URI)', () {
      const uri = 'content://com.android.providers.downloads/document/42';

      test('düz PDF: yanına yazılamaz, yer sorulmalı', () {
        expect(saveTargetFor(doc(uri)), isNull);
      });

      test('Inken dosyası aynı URI\'ye', () {
        expect(saveTargetFor(doc(uri, inken: true)), uri);
      });

      test('yazma izni yoksa Inken dosyası da sorulur', () {
        expect(saveTargetFor(doc(uri, inken: true, writable: false)), isNull);
        expect(
          canSaveAsOver(doc(uri, inken: true, writable: false), uri),
          isFalse,
        );
      });

      test('URI karşılaştırması birebir', () {
        expect(samePath(uri, uri), isTrue);
        expect(samePath(uri, '${uri}3'), isFalse);
        expect(samePath(uri, '/document/42'), isFalse);
      });
    });

    test('gösterilecek ad', () {
      expect(displayNameOf('${dir}ders.pdf', fallback: '?'), 'ders.pdf');
      expect(
        displayNameOf('content://a/document/42', fallback: 'ders.pdf'),
        'ders.pdf',
      );
      InkenBackup backup(String path, [String? name]) => InkenBackup(
        sourcePath: path,
        sourceName: name,
        sourceLength: 1,
        sourceModified: DateTime.utc(2026),
        savedAt: DateTime.utc(2026),
        document: const InkenDocument(),
      );
      expect(
        backupDisplayName(backup('content://a/b', 'limit.pdf')),
        'limit.pdf',
      );
      expect(
        backupDisplayName(
          backup('content://x/document/primary%3ADownload%2Fders.pdf'),
        ),
        'ders.pdf',
      );
      // Adı olmayan eski yedek, Türkçe harfli / % içeren düz yol: patlamaz.
      expect(
        backupDisplayName(
          backup('/home/öğretmen/İndirilenler/Limit Fasikülü_inken.pdf'),
        ),
        'Limit Fasikülü_inken.pdf',
      );
      expect(
        backupDisplayName(backup('/d/%50 indirim.pdf')),
        '%50 indirim.pdf',
      );
      expect(
        backupDisplayName(backup('content://x/document/bozuk%ZZ.pdf')),
        'bozuk%ZZ.pdf',
      );
    });
  });

  group('farklı kaydet', () {
    OpenDocument doc({bool inken = false, bool protected = false}) =>
        OpenDocument(
          name: 'ders.pdf',
          bytes: _bytes,
          path: '/d/ders.pdf',
          model: inken ? const InkenDocument() : null,
          isProtected: protected,
        );

    test('başka yol her zaman uygun', () {
      expect(canSaveAsOver(doc(), '/d/yeni.pdf'), isTrue);
    });

    test('açık dosyanın kendisi: yalnızca korumasız Inken dosyasıysa', () {
      expect(canSaveAsOver(doc(), '/d/ders.pdf'), isFalse);
      expect(canSaveAsOver(doc(inken: true), '/d/ders.pdf'), isTrue);
      expect(
        canSaveAsOver(doc(inken: true, protected: true), '/d/ders.pdf'),
        isFalse,
      );
    });
  });

  group('dışa aktarma yardımcıları', () {
    test('samePath: göreli / mutlak aynı dosya', () {
      final abs = File('ders.pdf').absolute.path;
      expect(samePath('ders.pdf', abs), isTrue);
      expect(samePath('ders.pdf', null), isFalse);
      expect(samePath('ders.pdf', 'ders (çizimli).pdf'), isFalse);
    });

    test('withoutPdfExtension', () {
      expect(withoutPdfExtension('Ders.PDF'), 'Ders');
      expect(withoutPdfExtension('ders_inken.pdf'), 'ders_inken');
      expect(withoutPdfExtension('notlar'), 'notlar');
    });
  });

  group('atomik yazma', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('inken_save'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('yeni dosya ve üstüne yazma; geçici dosya kalmaz', () async {
      final path = '${tmp.path}/a.pdf';
      await writeFileAtomically(path, Uint8List.fromList([1, 2]));
      await writeFileAtomically(path, Uint8List.fromList([3, 4, 5]));
      expect(File(path).readAsBytesSync(), [3, 4, 5]);
      expect(tmp.listSync(), hasLength(1));
    });

    test('yazılamayan klasörde hata, hedef oluşmaz', () async {
      final path = '${tmp.path}/yok/a.pdf';
      await expectLater(
        writeFileAtomically(path, Uint8List.fromList([1])),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(path).existsSync(), isFalse);
    });
  });

  test('yazdırma için güvenli dosya adı', () {
    expect(safeFileName('Limit: 1/2.pdf'), 'Limit_ 1_2.pdf');
    expect(safeFileName('ders.PDF'), 'ders.pdf');
    expect(safeFileName('  '), 'Inken.pdf');
    expect(
      safeFileName('ders - sayfa 1.png', extension: 'png'),
      'ders - sayfa 1.png',
    );
    expect(safeFileName('ders.pdf', extension: 'png'), 'ders.png');
    expect(safeFileName('a/b', extension: 'png'), 'a_b.png');
    expect(safeFileName('Türev ölçme'), 'Türev ölçme.pdf');
  });

  group('oturum kayıt işareti', () {
    InkSession session() =>
        InkSession(InkenDocument.forPdf(const [(width: 100, height: 100)]));

    void draw(InkSession s, {int page = 0}) {
      s.beginStroke(
        page: page,
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        minDistance: 0.1,
      );
      s.addPoint(1, 1, timeMs: 0, viewScale: 1);
      s.addPoint(9, 9, timeMs: 10, viewScale: 1);
      s.endStroke();
    }

    test('kaydedilince kirli değil, geri al korunur', () {
      final s = session();
      draw(s);
      expect(s.isDirty, isTrue);
      final snap = s.document;
      s.markSaved(snap, snap);
      expect(s.isDirty, isFalse);
      expect(s.canUndo, isTrue);
    });

    test('kayıt sürerken çizilen çizgi kirli kalır', () {
      final s = session();
      draw(s);
      final snap = s.document;
      draw(s);
      s.markSaved(snap, snap);
      expect(s.isDirty, isTrue);
    });

    test('sayfa sıraları yeniden numaralanınca model değişir', () {
      final s = session();
      final inserted = s.document.copyWith(
        pages: [
          ...s.document.pages,
          const PageLayer(template: PageTemplate.grid, width: 100, height: 100),
        ],
      );
      final s2 = InkSession(inserted);
      final saved = inserted.copyWith(
        pages: [
          for (final (i, p) in inserted.pages.indexed)
            p.copyWith(sourceIndex: i),
        ],
      );
      s2.markSaved(s2.document, saved);
      expect(s2.document.pages.map((p) => p.sourceIndex), [0, 1]);
      expect(s2.isDirty, isFalse);
    });

    test('döndürülen sayfa kaydedilince bekleyen döndürme sıfırlanır', () {
      final s = InkSession(
        InkenDocument.forPdf(const [(width: 100, height: 200)]),
      );
      draw(s);
      s.rotatePages({0}, 1);
      expect(s.document.pages[0].rotation, 1);
      expect(s.document.pages[0].width, 200);
      final snap = s.document;
      // Yazıcının döndürdüğü model: döndürme dosyaya yazıldı.
      final saved = snap.copyWith(
        pages: [snap.pages[0].copyWith(rotation: null)],
      );
      s.markSaved(snap, saved);
      expect(s.document.pages[0].rotation, isNull);
      expect(s.document.pages[0].width, 200);
      expect(s.isDirty, isFalse);
      // Geçmiş sıfırlandı: geri alma, dosyada olmayan döndürmeyi geri
      // getirmesin.
      expect(s.canUndo, isFalse);
    });

    test('birden çok sayfa tek adımda silinir; son sayfa silinmez', () {
      final s = InkSession(
        InkenDocument.forPdf(const [
          (width: 100, height: 100),
          (width: 100, height: 100),
          (width: 100, height: 100),
        ]),
      );
      s.removePages({0, 1, 2});
      expect(s.document.pages, hasLength(3));
      s.removePages({0, 2});
      expect(s.document.pages.single.sourceIndex, 1);
      s.undo();
      expect(s.document.pages.map((p) => p.sourceIndex), [0, 1, 2]);
    });

    test('kayıt sürerken çizilen, yeni sayfa numaralarına taşınır', () {
      final s = session();
      s.insertPage(
        0,
        const PageLayer(template: PageTemplate.grid, width: 100, height: 100),
      );
      final snap = s.document;
      s.saving = true;
      draw(s, page: 1); // kayıt sürerken çizim sürer
      s.undo(); // ama sayfa düzeni değişemez
      s.insertPage(0, snap.pages[0]);
      expect(s.document.pages.length, 2);
      final saved = snap.copyWith(
        pages: [
          for (final (i, p) in snap.pages.indexed) p.copyWith(sourceIndex: i),
        ],
      );
      s.markSaved(snap, saved);
      s.saving = false;
      expect(s.document.pages.map((p) => p.sourceIndex), [0, 1]);
      expect(s.document.pages[1].items, hasLength(1));
      expect(s.isDirty, isTrue);
    });
  });

  group('sayfa ekle / sil', () {
    InkSession session() => InkSession(
      InkenDocument.forPdf(const [
        (width: 100, height: 100),
        (width: 200, height: 100),
      ]),
    );

    test('ekle ve sil tek adımda geri alınır', () {
      final s = session();
      s.insertPage(1, newPageLike(s.document, 0, PageTemplate.dotted));
      expect(s.document.pages[1].template, PageTemplate.dotted);
      s.removePage(0);
      expect(s.document.pages.map((p) => p.sourceIndex), [null, 1]);
      s.undo();
      s.undo();
      expect(s.document.pages.map((p) => p.sourceIndex), [0, 1]);
      expect(s.document.pages[1].width, 200);
    });

    test('son kalan sayfa silinmez', () {
      final s = session()..removePage(0);
      s.removePage(0);
      expect(s.document.pages, hasLength(1));
    });
  });
}
