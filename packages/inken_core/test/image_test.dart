import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

const _img = ImageItem(
  id: 'g1',
  imageId: 'abc',
  x: 100,
  y: 200,
  width: 80,
  height: 40,
);

PageLayer _page(List<InkItem> items) =>
    PageLayer(sourceIndex: 0, width: 595, height: 842, items: items);

void main() {
  group('görsel öğesi', () {
    test('JSON gidiş-dönüş', () {
      final doc = InkenDocument(
        pages: [
          _page([_img]),
        ],
      );
      final back = decodeInkenDocument(encodeInkenDocument(doc));
      expect(back, doc);
      expect(back.formatVersion, currentFormatVersion);
      expect(encodeInkenDocument(doc), contains('"type":"image"'));
    });

    test('sürüm 1 dosyası güncel sürüme dönüştürülür, içerik aynı kalır', () {
      const v1 =
          '{"formatVersion":1,"pages":[{"sourceIndex":0,"width":595,'
          '"height":842,"items":[{"type":"shape","id":"s","kind":"line",'
          '"color":4278190080,"width":2,"x1":0,"y1":0,"x2":10,"y2":10}]}]}';
      final doc = decodeInkenDocument(v1);
      expect(doc.formatVersion, currentFormatVersion);
      expect(doc.pages.single.items.single, isA<Shape>());
    });

    test('daha yeni sürüm reddedilir', () {
      expect(
        () => decodeInkenDocument(
          '{"formatVersion":${currentFormatVersion + 1},"pages":[]}',
        ),
        throwsA(isA<UnsupportedFormatVersion>()),
      );
    });

    test('ek adı ↔ kimlik', () {
      expect(imageAttachmentName('abc'), 'inken-image-abc.png');
      expect(imageIdOfAttachment('inken-image-abc.png'), 'abc');
      expect(imageIdOfAttachment('inken.json'), isNull);
      expect(imageIdOfAttachment('inken-image-.png'), isNull);
    });

    test('kimlik içerikten türer', () {
      final a = imageAssetId([1, 2, 3]);
      expect(a, hasLength(16));
      expect(imageAssetId([1, 2, 3]), a);
      expect(imageAssetId([1, 2, 4]), isNot(a));
    });

    test('kullanılan görseller', () {
      final doc = InkenDocument(
        pages: [
          _page([
            _img,
            _img.copyWith(id: 'g2'),
            _img.copyWith(id: 'g3', imageId: 'x'),
          ]),
          _page(const []),
        ],
      );
      expect(referencedImageIds(doc), {'abc', 'x'});
    });
  });

  group('görsel geometrisi', () {
    test('sınır kutusu, taşıma, orantılı ölçek', () {
      expect(itemBounds(_img), (left: 100, top: 200, right: 180, bottom: 240));
      final moved = translateItem(_img, 10, -5) as ImageItem;
      expect((moved.x, moved.y, moved.width), (110, 195, 80));
      final scaled = scaleItem(_img, 2, 100, 200) as ImageItem;
      expect(
        (scaled.x, scaled.y, scaled.width, scaled.height),
        (100, 200, 160, 80),
      );
      expect(scaled.imageId, 'abc');
    });

    test('içine dokunmak seçer; dikdörtgenle seçilir', () {
      final page = _page([_img]);
      expect(itemAt(page, 140, 220, 2), 'g1');
      expect(itemAt(page, 300, 300, 2), isNull);
      expect(itemsInRect(page, 90, 190, 200, 250), {'g1'});
      expect(selectionBounds(page, {'g1'}), (
        left: 100,
        top: 200,
        right: 180,
        bottom: 240,
      ));
    });

    test('silgi görsele dokunmaz; üstündeki çizgiyi siler', () {
      const stroke = InkItem.stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        points: [InkPoint(110, 220), InkPoint(170, 220)],
      );
      final page = _page([_img, stroke]);
      expect(itemsHitBySegment(page, 140, 215, 140, 225, 3, images: false), {
        's',
      });
      expect(
        itemsHitBySegment(page, 140, 230, 140, 235, 3, images: false),
        isEmpty,
      );
      expect(itemsHitBySegment(page, 140, 230, 140, 235, 3), {'g1'});
    });
  });

  group('görselin yeri', () {
    const page = (left: 0.0, top: 0.0, right: 595.0, bottom: 842.0);

    test('küçük görsel doğal boyutunda, görünen alanın ortasında', () {
      final r = placeImage(
        pageWidth: 595,
        pageHeight: 842,
        visible: (left: 0, top: 100, right: 595, bottom: 500),
        pixelWidth: 200,
        pixelHeight: 100,
      );
      expect((r.width, r.height), (150, 75));
      expect(r.x + r.width / 2, closeTo(297.5, 1e-9));
      expect(r.y + r.height / 2, closeTo(300, 1e-9));
    });

    test('büyük görsel görünen alanın %80\'ine sığdırılır, oran korunur', () {
      final r = placeImage(
        pageWidth: 595,
        pageHeight: 842,
        visible: page,
        pixelWidth: 4000,
        pixelHeight: 1000,
      );
      expect(r.width, closeTo(595 * 0.8, 1e-9));
      expect(r.width / r.height, closeTo(4, 1e-9));
    });

    test('görünen alan sayfanın kenarını aşıyorsa sayfayla kesişir; sayfa '
        'dışına taşmaz', () {
      final r = placeImage(
        pageWidth: 595,
        pageHeight: 842,
        visible: (left: -200, top: 700, right: 300, bottom: 1200),
        pixelWidth: 400,
        pixelHeight: 400,
      );
      expect(r.x, greaterThanOrEqualTo(0));
      expect(r.y + r.height, lessThanOrEqualTo(842 + 1e-9));
      expect(r.width, closeTo(142 * 0.8, 1e-9));
    });
  });

  group('görsel görünümü', () {
    test('döndürülmemiş sayfa: birim kare doğru yere', () {
      final ap = appearanceFor(_img, const PdfAffine.flipY(842))!;
      expect(ap.kind, AnnotationKind.image);
      expect(ap.image!.imageId, 'abc');
      expect(ap.image!.matrix, const PdfAffine(80, 0, 0, 40, 100, 602));
      expect(ap.rect, (left: 100, bottom: 602, right: 180, top: 642));
    });

    test('döndürülmüş sayfa: görselin sol üstü sayfanın sol üstüne gider', () {
      // 90° döndürülmüş sayfa: ekranda (x, y) → PDF (y, x).
      const t = PdfAffine(0, 1, 1, 0, 0, 0);
      final m = appearanceFor(_img, t)!.image!.matrix;
      // Görselin sol üst köşesi (u=0, v=1) → sayfada (100, 200).
      expect(m.apply(0, 1), t.apply(100, 200));
      // Sağ alt (u=1, v=0) → sayfada (180, 240).
      expect(m.apply(1, 0), t.apply(180, 240));
    });
  });
}
