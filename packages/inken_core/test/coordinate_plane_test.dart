import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

const _plane = Shape(
  id: 'k',
  kind: ShapeKind.coordinate,
  color: 0xFF1B2233,
  width: 1.5,
  x1: 100,
  y1: 100,
  // 8 × 6 cm'den biraz büyük: kenarlar kare çizgisine denk gelmez.
  x2: 100 + 8.3 * ptPerCm,
  y2: 100 + 6.4 * ptPerCm,
);

PageLayer _page(List<InkItem> items) =>
    PageLayer(sourceIndex: 0, width: 595, height: 842, items: items);

void main() {
  group('koordinat düzlemi çizgileri', () {
    final lines = coordinatePlaneLines(_plane);
    final cx = (_plane.x1 + _plane.x2) / 2;
    final cy = (_plane.y1 + _plane.y2) / 2;

    test('eksenler kutunun ortasından, kenardan kenara', () {
      expect(lines.axes[0], (x1: _plane.x1, y1: cy, x2: _plane.x2, y2: cy));
      expect(lines.axes[1], (x1: cx, y1: _plane.y1, x2: cx, y2: _plane.y2));
      // İki eksen + dört uçta ikişer ok kanadı.
      expect(lines.axes, hasLength(2 + 8));
    });

    test('kareler 1 cm, orijinden simetrik, kutunun içinde', () {
      final xs = [
        for (final g in lines.grid)
          if (g.x1 == g.x2) g.x1,
      ]..sort();
      final ys = [
        for (final g in lines.grid)
          if (g.y1 == g.y2) g.y1,
      ]..sort();
      // 8,3 cm genişlik: ortadan iki yana 4'er çizgi; 6,4 cm: 3'er.
      expect(xs, hasLength(8));
      expect(ys, hasLength(6));
      for (final v in [xs, ys]) {
        for (var i = 1; i < v.length; i++) {
          // Eksenin olduğu yerde iki adım (eksen kare çizgisi sayılmaz).
          final gap = v[i] - v[i - 1];
          expect(
            (gap - ptPerCm).abs() < 1e-9 || (gap - 2 * ptPerCm).abs() < 1e-9,
            isTrue,
            reason: '$gap',
          );
        }
      }
      expect(xs.first + xs.last, closeTo(2 * cx, 1e-9));
      expect(ys.first + ys.last, closeTo(2 * cy, 1e-9));
      expect(xs.first, greaterThan(_plane.x1));
      expect(xs.last, lessThan(_plane.x2));
      // Eksen her zaman bir kare çizgisinin üstünde.
      expect(xs.contains(cx - ptPerCm) && xs.contains(cx + ptPerCm), isTrue);
    });

    test('kutu ters çizilse de aynı', () {
      final flipped = _plane.copyWith(
        x1: _plane.x2,
        x2: _plane.x1,
        y1: _plane.y2,
        y2: _plane.y1,
      );
      final other = coordinatePlaneLines(flipped);
      expect(other.grid.toSet(), lines.grid.toSet());
    });

    test('küçük kutuda kare yok, yalnızca eksenler', () {
      final small = _plane.copyWith(x2: 130, y2: 125);
      final l = coordinatePlaneLines(small);
      expect(l.grid, isEmpty);
      expect(l.axes, hasLength(10));
    });

    test('kare rengi açık ton, saydamlık korunur', () {
      expect(coordinateGridColor(0xFF000000), 0xFFB8B8B8);
      expect(coordinateGridColor(0x80FF0000) >>> 24, 0x80);
      expect(coordinateGridWidth(1.5), lessThan(1.5));
    });
  });

  group('koordinat düzlemi öğesi', () {
    test('içine dokunmak seçer; silgi dokunmaz', () {
      const stroke = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        points: [InkPoint(150, 150), InkPoint(160, 150)],
      );
      final page = _page([_plane, stroke]);
      expect(itemAt(page, 200, 200, 2), 'k');
      // Üstteki çizgi önce seçilir.
      expect(itemAt(page, 155, 150, 2), 's');
      final erased = itemsHitBySegment(
        page,
        150,
        150,
        cxOf(_plane),
        150,
        4,
        images: false,
      );
      expect(erased, {'s'});
      expect(isBackgroundItem(_plane), isTrue);
      expect(isBackgroundItem(_plane.copyWith(kind: ShapeKind.line)), isFalse);
    });

    test('Shift ile kare', () {
      final end = constrainShapeEnd(
        ShapeKind.coordinate,
        0,
        0,
        100,
        60,
        constrain: true,
      );
      expect(end, (x: 100.0, y: 100.0));
    });

    test('JSON gidiş-dönüş; sürüm 2 dosyası 3\'e dönüştürülür', () {
      final doc = InkenDocument(
        pages: [
          _page([_plane]),
        ],
      );
      final json = encodeInkenDocument(doc);
      expect(json, contains('"kind":"coordinate"'));
      expect(decodeInkenDocument(json), doc);
      expect(currentFormatVersion, greaterThanOrEqualTo(3));
      const v2 =
          '{"formatVersion":2,"pages":[{"sourceIndex":0,"width":595,'
          '"height":842,"items":[{"type":"shape","id":"s","kind":"ellipse",'
          '"color":4278190080,"width":2,"x1":0,"y1":0,"x2":10,"y2":10}]}]}';
      final old = decodeInkenDocument(v2);
      expect(old.formatVersion, currentFormatVersion);
      expect((old.pages.single.items.single as Shape).kind, ShapeKind.ellipse);
    });

    test('PDF görünümü: Ink, önce açık tonlu kareler, sonra eksenler', () {
      final ap = appearanceFor(_plane, const PdfAffine.flipY(842))!;
      expect(ap.kind, AnnotationKind.ink);
      // Ink listesi yalnızca eksenler ve ok kanatları.
      expect(ap.inkList, hasLength(10));
      final grid = ap.stream.indexOf(
        '${_rgb(coordinateGridColor(_plane.color))} RG',
      );
      final axes = ap.stream.lastIndexOf('${_rgb(_plane.color)} RG');
      expect(grid, greaterThan(0));
      expect(axes, greaterThan(grid));
      expect(
        ap.stream,
        contains('${pdfNum(coordinateGridWidth(_plane.width))} w'),
      );
      expect(RegExp(r'^S$', multiLine: true).allMatches(ap.stream).length, 2);
    });
  });
}

double cxOf(Shape s) => (s.x1 + s.x2) / 2;

String _rgb(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  return '${pdfNum(r / 255)} ${pdfNum(g / 255)} ${pdfNum(b / 255)}';
}
