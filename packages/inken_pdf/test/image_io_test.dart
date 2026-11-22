// Görsel öğesi: PDF'e yazma, ek dosya, geri okuma, döndürülmüş sayfa,
// düzleştirme (gerçek PDFium ile).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import 'pdfium_test_helper.dart';

void _dump(String name, Uint8List pdf) {
  final dir = Platform.environment['INKEN_TEST_OUT'];
  if (dir != null) File('$dir/$name').writeAsBytesSync(pdf);
}

/// 2x2 görsel: sol üst kırmızı, sağ üst yeşil, sol alt mavi, sağ alt
/// saydam. Yön hatasını (yansıma / dönme) ve saydamlığı birlikte yakalar.
InkenImage _quadrants(Uint8List png) => InkenImage(
  png: png,
  width: 2,
  height: 2,
  rgba: Uint8List.fromList([
    255, 0, 0, 255, /**/ 0, 255, 0, 255, //
    0, 0, 255, 255, /**/ 0, 0, 0, 0,
  ]),
);

final _pngA = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
final _pngB = Uint8List.fromList([137, 80, 78, 71, 9, 9]);
final _idA = imageAssetId(_pngA);
final _idB = imageAssetId(_pngB);

ImageItem _image(String id, String imageId, double x, double y, double size) =>
    ImageItem(id: id, imageId: imageId, x: x, y: y, width: size, height: size);

InkenDocument _withItems(Uint8List pdf, List<List<InkItem>> perPage) {
  final base = InkenDocument.forPdf(pageSizes(pdf));
  return base.copyWith(
    pages: [
      for (final (i, p) in base.pages.indexed)
        p.copyWith(items: i < perPage.length ? perPage[i] : const []),
    ],
  );
}

/// Baskın renk: kırmızı / yeşil / mavi / beyaz.
String _tone(int rgb) {
  final r = rgb >> 16 & 0xFF, g = rgb >> 8 & 0xFF, b = rgb & 0xFF;
  if (r > 200 && g > 200 && b > 200) return 'beyaz';
  if (r > 200 && g < 80 && b < 80) return 'kırmızı';
  if (g > 200 && r < 80 && b < 80) return 'yeşil';
  if (b > 200 && r < 80 && g < 80) return 'mavi';
  return rgb.toRadixString(16);
}

/// Görselin dört çeyreğinin ekrandaki tonları (sol üst, sağ üst, sol alt,
/// sağ alt).
List<String> _quads(Rendered r, ImageItem g) {
  int px(double f) => f.round();
  final qx = g.width / 4, qy = g.height / 4;
  return [
    _tone(r.rgb(px(g.x + qx), px(g.y + qy))),
    _tone(r.rgb(px(g.x + 3 * qx), px(g.y + qy))),
    _tone(r.rgb(px(g.x + qx), px(g.y + 3 * qy))),
    _tone(r.rgb(px(g.x + 3 * qx), px(g.y + 3 * qy))),
  ];
}

const _expected = ['kırmızı', 'yeşil', 'mavi', 'beyaz'];

void main() {
  setUpPdfium();

  group('görsel kaydı', () {
    final src = fixture('two_pages.pdf');
    final g = _image('g1', _idA, 100, 200, 80);
    final model = _withItems(src, [
      [g, _image('g2', _idA, 300, 200, 40)],
    ]);
    late InkenWriteResult saved;

    setUpAll(() {
      saved = writeInkenPdf(
        (src, encodeInkenDocument(model)),
        null,
        {_idA: _quadrants(_pngA)},
      );
      _dump('image.pdf', saved.pdf);
    });

    test('Stamp açıklaması, inken: adıyla, görünüm akışıyla', () {
      expect(saved.skippedItems, 0);
      final annots = listAnnotations(saved.pdf);
      expect(annots.map((a) => a.name), ['inken:g1', 'inken:g2']);
      for (final a in annots) {
        expect(a.subtype, FPDF_ANNOT_STAMP);
        expect(a.hasAp, isTrue);
      }
    });

    test('ekranda yerinde ve doğru yönde; saydam kısım saydam', () {
      expect(_quads(render(saved.pdf, 0), g), _expected);
    });

    test(
      'geri okunur: model ve PNG baytları aynı; görsel bir kez saklanır',
      () {
        final r = readInkenPdf(saved.pdf);
        expect(decodeInkenDocument(r.inkenJson!), model);
        expect(r.images.keys, [_idA]);
        expect(r.images[_idA], _pngA);
        // inken.json + tek görsel eki.
        expect(attachmentCount(saved.pdf), 2);
        // Görüntüleme kopyasında Inken görseli gizlidir (katman çizer).
        expect(_quads(render(r.displayPdf, 0), g), List.filled(4, 'beyaz'));
      },
    );

    test('yeniden kayıt çoğaltmaz; dosyadaki görsel yeniden verilmese de '
        'eki korunur', () {
      final again = writeInkenPdf(
        (saved.pdf, encodeInkenDocument(model)),
        null,
        {_idA: _quadrants(_pngA)},
      );
      expect(listAnnotations(again.pdf), hasLength(2));
      expect(attachmentCount(again.pdf), 2);

      // Görsel verilmezse görünüm yazılamaz (atlanır) ama ek kaybolmaz.
      final noPixels = writeInkenPdf((saved.pdf, encodeInkenDocument(model)));
      expect(noPixels.skippedItems, 2);
      expect(readInkenPdf(noPixels.pdf).images[_idA], _pngA);
    });

    test('kullanılmayan görselin eki silinir, yenisi eklenir', () {
      final replaced = _withItems(src, [
        [_image('g3', _idB, 100, 200, 80)],
      ]);
      final out = writeInkenPdf(
        (saved.pdf, encodeInkenDocument(replaced)),
        null,
        {_idB: _quadrants(_pngB)},
      );
      final r = readInkenPdf(out.pdf);
      expect(r.images.keys, [_idB]);
      expect(attachmentCount(out.pdf), 2);
      expect(listAnnotations(out.pdf).map((a) => a.name), ['inken:g3']);

      final empty = writeInkenPdf((
        out.pdf,
        encodeInkenDocument(_withItems(src, const [])),
      ));
      expect(readInkenPdf(empty.pdf).images, isEmpty);
      expect(attachmentCount(empty.pdf), 1);
    });

    test('düzleştirilmiş dışa aktarmada görünür, hiç ek kalmaz', () {
      final flat = writeFlattenedPdf(
        (saved.pdf, encodeInkenDocument(model)),
        null,
        {_idA: _quadrants(_pngA)},
      );
      _dump('image-flat.pdf', flat.pdf);
      expect(listAnnotations(flat.pdf), isEmpty);
      expect(attachmentCount(flat.pdf), 0);
      expect(_quads(render(flat.pdf, 0), g), _expected);
    });
  });

  group('görsel düzenleme: kırpma, döndürme, opaklık', () {
    final src = fixture('two_pages.pdf');
    final turned = _image('r', _idA, 60, 100, 80).copyWith(rotation: 1);
    // Sol yarı (kırmızı üstte, mavi altta), kutuya esnetilir.
    final cropped = _image('c', _idA, 200, 100, 80).copyWith(cropRight: 0.5);
    final faded = _image('o', _idA, 340, 100, 80).copyWith(opacity: 0.5);
    late InkenWriteResult saved;

    setUpAll(() {
      saved = writeInkenPdf(
        (
          src,
          encodeInkenDocument(
            _withItems(src, [
              [turned, cropped, faded],
            ]),
          ),
        ),
        null,
        {_idA: _quadrants(_pngA)},
      );
      _dump('image-edit.pdf', saved.pdf);
    });

    test('saat yönünde çeyrek tur', () {
      expect(_quads(render(saved.pdf, 0), turned), [
        'mavi',
        'kırmızı',
        'beyaz',
        'yeşil',
      ]);
    });

    test('kırpılan yarı kutuyu doldurur', () {
      expect(_quads(render(saved.pdf, 0), cropped), [
        'kırmızı',
        'kırmızı',
        'mavi',
        'mavi',
      ]);
    });

    test('yarı saydam görsel beyaz zeminde açık görünür', () {
      final r = render(saved.pdf, 0);
      final rgb = r.rgb((faded.x + 20).round(), (faded.y + 20).round());
      expect(rgb >> 16 & 0xFF, greaterThan(230));
      expect(rgb >> 8 & 0xFF, inInclusiveRange(100, 160));
      expect(rgb & 0xFF, inInclusiveRange(100, 160));
    });

    test('düzenleme geri okunur; orijinal görsel baytları değişmez', () {
      final r = readInkenPdf(saved.pdf);
      final items = decodeInkenDocument(r.inkenJson!).pages[0].items;
      expect(items, [turned, cropped, faded]);
      expect(r.images[_idA], _pngA);
    });
  });

  test('döndürülmüş ve kırpılmış sayfalarda yerinde ve doğru yönde', () {
    final src = fixture('rotated.pdf');
    final sizes = pageSizes(src);
    final items = [
      for (final p in sizes)
        [_image('r', _idA, p.width * 0.2, p.height * 0.2, 80)],
    ];
    final saved = writeInkenPdf(
      (src, encodeInkenDocument(_withItems(src, items))),
      null,
      {_idA: _quadrants(_pngA)},
    );
    _dump('image-rotated.pdf', saved.pdf);
    for (final (i, it) in items.indexed) {
      expect(
        _quads(render(saved.pdf, i), it.single),
        _expected,
        reason: 'sayfa $i',
      );
    }
  });
}
