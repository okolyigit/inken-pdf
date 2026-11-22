import 'dart:convert';
import 'dart:typed_data';

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

const _img = ImageItem(
  id: 'g1',
  imageId: 'abc',
  x: 10,
  y: 20,
  width: 80,
  height: 40,
);

const _text = TextItem(
  id: 't1',
  text: 'Not',
  color: 0xFF1D4ED8,
  fontSize: 14,
  x: 0,
  y: 0,
  width: 40,
  height: 20,
);

PageLayer _page(List<InkItem> items) =>
    PageLayer(sourceIndex: 0, width: 595, height: 842, items: items);

/// 3×2 görsel; her pikselin kırmızısı kendi sırası (0..5), alfa 200.
Uint8List _pixels() => Uint8List.fromList([
  for (var i = 0; i < 6; i++) ...[i, 0, 0, 200],
]);

List<int> _reds(RgbaPixels p) => [
  for (var i = 0; i < p.width * p.height; i++) p.rgba[i * 4],
];

void main() {
  group('opaklık', () {
    test('metinde rengin alfası, görselde opacity alanı', () {
      final t = withOpacity(_text, 0.5) as TextItem;
      expect(t.color >>> 24, 128);
      expect(t.color & 0xFFFFFF, 0x1D4ED8, reason: 'renk korunur');
      expect(itemOpacity(t), closeTo(0.5, 0.01));
      final g = withOpacity(_img, 0.3) as ImageItem;
      expect(g.opacity, 0.3);
      expect(itemOpacity(_img), 1);
    });

    test('çizgi ve şeklin opaklığı yoktur', () {
      const s = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        points: [InkPoint(0, 0, 0.5)],
      );
      expect(hasOpacity(s), isFalse);
      expect(withOpacity(s, 0.2), s);
      expect(hasOpacity(_text), isTrue);
      expect(hasOpacity(_img), isTrue);
    });

    test('SetOpacity: uygula, geri al; değişmeyenler atlanır', () {
      final doc = InkenDocument(
        pages: [
          _page([_text, _img]),
        ],
      );
      final cmd = SetOpacity(doc, 0, {'t1', 'g1'}, 0.4);
      expect(cmd.isEmpty, isFalse);
      final after = cmd.apply(doc);
      expect(itemOpacity(after.pages[0].items[0]), closeTo(0.4, 0.01));
      expect((after.pages[0].items[1] as ImageItem).opacity, 0.4);
      expect(cmd.revert(after), doc);
      expect(SetOpacity(doc, 0, {'g1'}, 1).isEmpty, isTrue);
    });
  });

  group('kırpma ve döndürme', () {
    test('çeyrek tur: oranlar döner, ters dönüşüm aslını verir', () {
      const c = (left: 0.1, top: 0.2, right: 0.5, bottom: 0.9);
      final v = cropToView(c, 1);
      expect(v.left, closeTo(0.1, 1e-9));
      expect(v.top, closeTo(0.1, 1e-9));
      expect(v.right, closeTo(0.8, 1e-9));
      expect(v.bottom, closeTo(0.5, 1e-9));
      for (var t = -3; t <= 4; t++) {
        final back = cropToSource(cropToView(c, t), t);
        expect(back.left, closeTo(c.left, 1e-9), reason: 'tur $t');
        expect(back.bottom, closeTo(c.bottom, 1e-9), reason: 'tur $t');
      }
    });

    test('kırpma 0–1 içinde ve en küçük boyutta tutulur', () {
      final c = clampCrop((left: -0.5, top: 0.5, right: 2, bottom: 0.5));
      expect(c.left, 0);
      expect(c.right, 1);
      expect(c.bottom - c.top, closeTo(minCropSize, 1e-9));
    });

    test('kırpılmış ve döndürülmüş boyut', () {
      final s = croppedSize(400, 200, (
        left: 0,
        top: 0,
        right: 0.5,
        bottom: 1,
      ), 1);
      expect(s.width, 200);
      expect(s.height, 200);
      expect(croppedSize(400, 200, fullCrop, 3).width, 200);
    });

    test('pikseller: kırp, döndür, opaklık', () {
      // 0 1 2
      // 3 4 5
      final src = _pixels();
      expect(
        identical(transformImagePixels(src, 3, 2).rgba, src),
        isTrue,
        reason: 'değişiklik yoksa kopya yok',
      );
      final cw = transformImagePixels(src, 3, 2, turns: 1);
      expect((cw.width, cw.height), (2, 3));
      // Saat yönünde: 3 0 / 4 1 / 5 2
      expect(_reds(cw), [3, 0, 4, 1, 5, 2]);
      final half = transformImagePixels(src, 3, 2, turns: 2);
      expect(_reds(half), [5, 4, 3, 2, 1, 0]);
      final ccw = transformImagePixels(src, 3, 2, turns: -1);
      expect(_reds(ccw), [2, 5, 1, 4, 0, 3]);
      final cropped = transformImagePixels(
        src,
        3,
        2,
        crop: (left: 1 / 3, top: 0, right: 1, bottom: 0.5),
      );
      expect((cropped.width, cropped.height), (2, 1));
      expect(_reds(cropped), [1, 2]);
      final faded = transformImagePixels(src, 3, 2, opacity: 0.5);
      expect(faded.rgba[3], 100);
      expect(faded.rgba[0], 0, reason: 'renk değişmez');
    });

    test('düzenleme uygulanır: kutu sol üstten sabit', () {
      final g = applyImageEdit(
        _img,
        crop: (left: 0.1, top: 0, right: 0.9, bottom: 1),
        turns: 5,
        width: 50,
        height: 0,
        opacity: 1.5,
      );
      expect((g.x, g.y), (10, 20));
      expect(g.rotation, 1);
      expect(g.width, 50);
      expect(g.height, 1, reason: 'en az 1 pt');
      expect(g.opacity, 1);
      expect(cropOf(g), (left: 0.1, top: 0.0, right: 0.9, bottom: 1.0));
    });
  });

  group('kayıt', () {
    test('düzenlenmiş görsel JSON gidiş-dönüş', () {
      final g = applyImageEdit(
        _img,
        crop: (left: 0.25, top: 0.1, right: 0.75, bottom: 0.9),
        turns: 3,
        width: 30,
        height: 60,
        opacity: 0.6,
      );
      final doc = InkenDocument(
        pages: [
          _page([g, withOpacity(_text, 0.5)]),
        ],
      );
      final back = decodeInkenDocument(encodeInkenDocument(doc));
      expect(back, doc);
      expect(back.formatVersion, 4);
    });

    test('sürüm 3 dosyası: görsel opak, kırpılmamış, döndürülmemiş', () {
      final json = jsonEncode({
        'formatVersion': 3,
        'pages': [
          {
            'sourceIndex': 0,
            'width': 595.0,
            'height': 842.0,
            'items': [
              {
                'type': 'image',
                'id': 'g1',
                'imageId': 'abc',
                'x': 10.0,
                'y': 20.0,
                'width': 80.0,
                'height': 40.0,
              },
            ],
          },
        ],
      });
      final doc = decodeInkenDocument(json);
      expect(doc.formatVersion, currentFormatVersion);
      expect(doc.pages[0].items.single, _img);
    });
  });
}
