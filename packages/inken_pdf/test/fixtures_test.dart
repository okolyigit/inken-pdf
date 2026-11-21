// Kapı testi: test/fixtures/ içindeki her PDF'te gidiş-dönüş.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'pdfium_test_helper.dart';

final _png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
final _imageId = imageAssetId(_png);

/// 2x2 görsel; yarısı saydam.
final _images = {
  _imageId: InkenImage(
    png: _png,
    width: 2,
    height: 2,
    rgba: Uint8List.fromList([
      ...[30, 90, 200, 255, 30, 90, 200, 0],
      ...[200, 30, 30, 255, 200, 30, 30, 128],
    ]),
  ),
};

/// İlk ve son sayfaya birer kalem ve fosforlu çizgisi ve bir görsel.
InkenDocument _drawOn(Uint8List pdf) {
  final doc = InkenDocument.forPdf(pageSizes(pdf));
  final last = doc.pages.length - 1;
  return doc.copyWith(
    pages: [
      for (final (i, page) in doc.pages.indexed)
        if (i == 0 || i == last)
          page.copyWith(
            items: [
              Stroke(
                id: 'pen-$i',
                tool: InkTool.pen,
                color: 0xFFD32F2F,
                width: 3,
                points: [
                  InkPoint(page.width * 0.2, page.height * 0.3, 0.4),
                  InkPoint(page.width * 0.5, page.height * 0.35, 1),
                  InkPoint(page.width * 0.7, page.height * 0.3, 0.6),
                ],
              ),
              Stroke(
                id: 'hl-$i',
                tool: InkTool.highlighter,
                color: 0x6EFFE600,
                width: 18,
                points: [
                  InkPoint(page.width * 0.2, page.height * 0.5),
                  InkPoint(page.width * 0.8, page.height * 0.5),
                ],
              ),
              ImageItem(
                id: 'img-$i',
                imageId: _imageId,
                x: page.width * 0.1,
                y: page.height * 0.6,
                width: page.width * 0.3,
                height: page.width * 0.3,
              ),
            ],
          )
        else
          page,
    ],
  );
}

void main() {
  setUpAll(setUpPdfium);

  final fixtures =
      Directory('../../test/fixtures')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'))
          // Açılış parolalı dosyanın kendi testleri var (pdf_io_test).
          .where((f) => !f.path.endsWith('user_password.pdf'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('fixture listesi beklenen dosyaları içeriyor', () {
    expect(
      fixtures.map((f) => f.uri.pathSegments.last),
      containsAll(<String>[
        'encrypted.pdf',
        'form.pdf',
        'hundred_pages.pdf',
        'mixed_sizes.pdf',
        'rotated.pdf',
        'scanned.pdf',
        'single_page.pdf',
        'two_pages.pdf',
      ]),
    );
  });

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last;
    group(name, () {
      late Uint8List src;
      late InkenDocument model;
      late InkenWriteResult saved;
      late int foreign;

      setUpAll(() {
        src = file.readAsBytesSync();
        model = _drawOn(src);
        foreign = listAnnotations(src).length;
        saved = writeInkenPdf((src, encodeInkenDocument(model)), null, _images);
      });

      test('kaydet → aç: model eşit, açıklamalar yerinde', () {
        final r = readInkenPdf(saved.pdf);
        expect(r.pageCount, model.pages.length);
        expect(
          decodeInkenDocument(r.inkenJson!),
          decodeInkenDocument(encodeInkenDocument(model)),
        );
        final annots = listAnnotations(saved.pdf);
        final ours = annots.where((a) => a.name.startsWith('inken:'));
        expect(
          ours,
          hasLength(model.pages.fold<int>(0, (n, p) => n + p.items.length)),
        );
        expect(ours.every((a) => a.hasAp), isTrue);
        expect(r.images, {_imageId: _png});
        expect(saved.skippedItems, 0);
        expect(
          annots.length - ours.length,
          foreign,
          reason: 'yabancı açıklamalar',
        );
      });

      test('yeniden kayıtta çoğalmaz', () {
        final again = writeInkenPdf(
          (saved.pdf, saved.inkenJson),
          null,
          _images,
        );
        expect(
          listAnnotations(again.pdf),
          hasLength(listAnnotations(saved.pdf).length),
        );
        expect(attachmentCount(again.pdf), attachmentCount(saved.pdf));
      });

      test('görüntüleme kopyası orijinalle piksel piksel aynı', () {
        final shown = readInkenPdf(saved.pdf).displayPdf;
        final last = model.pages.length - 1;
        for (final i in {0, last}) {
          expect(
            render(shown, i).bgra,
            render(src, i).bgra,
            reason: 'sayfa $i',
          );
          expect(
            render(saved.pdf, i).bgra,
            isNot(render(src, i).bgra),
            reason: 'sayfa $i: çizim görünmeli',
          );
        }
      });

      test('düzleştirilmiş dışa aktarma', () {
        final flat = writeFlattenedPdf(
          (src, encodeInkenDocument(model)),
          null,
          _images,
        );
        expect(listAnnotations(flat.pdf), isEmpty);
        expect(attachmentCount(flat.pdf), attachmentCount(src));
        expect(readInkenPdf(flat.pdf).inkenJson, isNull);
      });
    });
  }

  test('şifreli dosya: korumalı sayılır, kayıt şifreyi korur', () {
    final src = File('../../test/fixtures/encrypted.pdf').readAsBytesSync();
    expect(readInkenPdf(src).isProtected, isTrue);
    final saved = writeInkenPdf(
      (src, encodeInkenDocument(_drawOn(src))),
      null,
      _images,
    );
    // ignore: avoid_print
    print(
      'şifreli: kaynak ${securityRevision(src)}, kayıt ${securityRevision(saved.pdf)}',
    );
    final r = readInkenPdf(saved.pdf);
    expect(r.inkenJson, isNotNull);
    expect(r.isProtected, securityRevision(saved.pdf) != -1);
    final dir = Platform.environment['INKEN_TEST_OUT'];
    if (dir != null) {
      File('$dir/encrypted_saved.pdf').writeAsBytesSync(saved.pdf);
    }
  });
}
