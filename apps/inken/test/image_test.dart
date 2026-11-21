import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/document_io.dart';
import 'package:inken/features/ink/ink_images.dart';
import 'package:inken/features/ink/ink_painter.dart';
import 'package:inken/features/ink/ink_session.dart';
import 'package:inken_core/inken_core.dart';

/// [w]x[h] PNG: sol yarı kırmızı, sağ yarı yarı saydam mavi.
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  canvas.drawRect(
    Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()),
    Paint()..color = const Color(0x800000FF),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  group('görsel hazırlama', () {
    testWidgets('küçük görsel olduğu gibi; kimlik içerikten', (t) async {
      await t.runAsync(() async {
        final raw = await _png(40, 20);
        final p = (await prepareImage(raw))!;
        expect((p.image.width, p.image.height), (40, 20));
        expect(p.id, imageAssetId(p.png));
        final again = (await prepareImage(raw))!;
        expect(again.id, p.id, reason: 'aynı görsel aynı kimlik');
        p.image.dispose();
        again.image.dispose();
      });
    });

    testWidgets('büyük görsel uzun kenarı sınıra iner, oran korunur', (
      t,
    ) async {
      await t.runAsync(() async {
        final p = (await prepareImage(await _png(400, 100), maxSide: 200))!;
        expect((p.image.width, p.image.height), (200, 50));
        final decoded = await decodeImage(p.png);
        expect(decoded.width, 200, reason: 'PNG de küçültülmüş');
        decoded.dispose();
        p.image.dispose();
      });
    });

    testWidgets('görsel olmayan bayt: null', (t) async {
      await t.runAsync(() async {
        expect(await prepareImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
      });
    });
  });

  group('görsel deposu', () {
    testWidgets('yazıcıya: PNG ve ön çarpımsız RGBA', (t) async {
      await t.runAsync(() async {
        final png = await _png(4, 2);
        final images = InkImages({'a': png});
        final out = await images.forWriting({'a', 'yok'});
        expect(out.keys, ['a']);
        final g = out['a']!;
        expect((g.width, g.height, g.png), (4, 2, png));
        // Sol üst kırmızı opak; sağ üst mavi, alfa ~128 (ön çarpımsız:
        // mavi kanal tam).
        expect(g.rgba.sublist(0, 4), [255, 0, 0, 255]);
        final right = g.rgba.sublist(12, 16);
        expect(right[2], greaterThan(240));
        expect(right[3], inInclusiveRange(120, 136));
        images.dispose();
      });
    });

    testWidgets('çözülünce haber verir; sürüm artar', (t) async {
      await t.runAsync(() async {
        final images = InkImages({'a': await _png(4, 2)});
        var notified = 0;
        images.addListener(() => notified++);
        expect(images.image('a'), isNull, reason: 'henüz çözülmedi');
        await images.decode('a');
        expect(images.image('a'), isNotNull);
        expect(notified, 1);
        expect(images.version, 1);
        images.dispose();
      });
    });
  });

  group('oturum', () {
    testWidgets('görsel eklenir, seçilir; tek geri alma adımı', (t) async {
      final session = InkSession(
        InkenDocument.forPdf(const [(width: 595, height: 842)]),
      );
      const g = ImageItem(
        id: 'g',
        imageId: 'a',
        x: 10,
        y: 10,
        width: 100,
        height: 50,
      );
      session.insertImage(0, g);
      expect(session.document.pages[0].items, [g]);
      expect(session.selection, {'g'});
      expect(session.selectionPage, 0);
      session.undo();
      expect(session.document.pages[0].items, isEmpty);
      expect(session.hasSelection, isFalse);
      session.dispose();
    });

    testWidgets('silgi görsele dokunmaz', (t) async {
      final session = InkSession(
        InkenDocument.forPdf(const [(width: 595, height: 842)]),
      );
      session.insertImage(
        0,
        const ImageItem(
          id: 'g',
          imageId: 'a',
          x: 10,
          y: 10,
          width: 100,
          height: 50,
        ),
      );
      session.beginErase(0);
      session.eraseSegment(20, 20, 90, 40, 10);
      session.endErase();
      expect(session.document.pages[0].items, hasLength(1));
      session.dispose();
    });
  });

  testWidgets('çizim: görsel yerinde çizilir; çözülmeden önce yer tutucu', (
    t,
  ) async {
    await t.runAsync(() async {
      final images = InkImages({'a': await _png(4, 2)});
      const g = ImageItem(
        id: 'g',
        imageId: 'a',
        x: 10,
        y: 10,
        width: 40,
        height: 20,
      );
      Future<List<int>> pixel(int x, int y) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        paintItem(canvas, g, null, images);
        final img = await recorder.endRecording().toImage(60, 40);
        final data = await img.toByteData();
        img.dispose();
        final i = (y * 60 + x) * 4;
        return data!.buffer.asUint8List().sublist(i, i + 3);
      }

      final before = await pixel(15, 20);
      expect(before[0], lessThan(250), reason: 'yer tutucu soluk gri');
      expect(before, isNot([255, 0, 0]));
      await images.decode('a');
      expect(await pixel(15, 20), [255, 0, 0]);
      expect(await pixel(5, 5), [255, 255, 255], reason: 'görselin dışı');
      images.dispose();
    });
  });

  group('yedek', () {
    late Directory dir;
    late BackupStore store;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('inken_backup_img');
      store = BackupStore.at(dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    InkenBackup backup(String path, List<InkItem> items) => InkenBackup(
      sourcePath: path,
      sourceLength: 1,
      sourceModified: DateTime.utc(2026),
      savedAt: DateTime.utc(2026),
      document: InkenDocument(
        pages: [
          PageLayer(sourceIndex: 0, width: 595, height: 842, items: items),
        ],
      ),
    );
    ImageItem img(String imageId) => ImageItem(
      id: newItemId(),
      imageId: imageId,
      x: 0,
      y: 0,
      width: 10,
      height: 10,
    );

    test('görseller yedekle birlikte; kullanılmayan silinir', () async {
      final a = Uint8List.fromList([1, 2, 3]), b = Uint8List.fromList([4]);
      await store.write(backup('/x.pdf', [img('a')]), images: {'a': a, 'b': b});
      await store.write(backup('/y.pdf', [img('b')]), images: {'b': b});
      final list = await store.list();
      expect(
        await store.imagesFor(list.firstWhere((x) => x.sourcePath == '/x.pdf')),
        {'a': a},
      );
      // x'in yeni yedeğinde görsel yok: 'a' artık kimsenin değil.
      await store.write(backup('/x.pdf', const []));
      await store.list();
      expect(File('${dir.path}/images/a.png').existsSync(), isFalse);
      expect(File('${dir.path}/images/b.png').existsSync(), isTrue);
    });
  });

  test('görsel dosyası uzantısı', () {
    expect(isImageFile('/a/Resim.PNG'), isTrue);
    expect(isImageFile('foto.jpeg'), isTrue);
    expect(isImageFile('belge.pdf'), isFalse);
    expect(isImageFile('noext'), isFalse);
  });
}
