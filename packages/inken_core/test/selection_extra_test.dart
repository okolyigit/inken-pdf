import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

const _pen = Stroke(
  id: 'p',
  tool: InkTool.pen,
  color: 0xFF000000,
  width: 2,
  points: [InkPoint(0, 0), InkPoint(10, 20)],
);
const _hl = Stroke(
  id: 'h',
  tool: InkTool.highlighter,
  color: 0x66FFE34D,
  width: 16,
  points: [InkPoint(0, 50), InkPoint(100, 50)],
);
const _rect = Shape(
  id: 'r',
  kind: ShapeKind.rectangle,
  color: 0xFF1F5AD6,
  width: 3,
  x1: 10,
  y1: 10,
  x2: 30,
  y2: 20,
);
const _text = TextItem(
  id: 't',
  text: 'a',
  color: 0xFF000000,
  fontSize: 20,
  x: 40,
  y: 40,
  width: 12,
  height: 24,
);
const _img = ImageItem(
  id: 'g',
  imageId: 'x',
  x: 50,
  y: 60,
  width: 40,
  height: 20,
);

InkenDocument _doc(List<InkItem> a, [List<InkItem> b = const []]) =>
    InkenDocument(
      pages: [
        PageLayer(sourceIndex: 0, width: 595, height: 842, items: a),
        PageLayer(sourceIndex: 1, width: 595, height: 842, items: b),
      ],
    );

void main() {
  group('orantısız ölçek', () {
    test('konumlar eksen eksen; görsel esner', () {
      final r = scaleItem(_rect, 2, 10, 10, 0.5) as Shape;
      expect((r.x1, r.y1, r.x2, r.y2), (10, 10, 50, 15));
      final g = scaleItem(_img, 2, 50, 60, 3) as ImageItem;
      expect((g.x, g.y, g.width, g.height), (50, 60, 80, 60));
      final p = scaleItem(_pen, 3, 0, 0, 0.5) as Stroke;
      expect(p.points.last, const InkPoint(30, 10));
    });

    test('kalınlık ve yazı boyutu geometrik ortalamayla', () {
      final r = scaleItem(_rect, 4, 0, 0, 1) as Shape;
      expect(r.width, closeTo(3 * 2, 1e-9));
      final t = scaleItem(_text, 4, 40, 40, 1) as TextItem;
      expect(t.fontSize, closeTo(40, 1e-9));
    });

    test('scaleY verilmezse eskisi gibi orantılı', () {
      expect(scaleItem(_rect, 2, 0, 0), scaleItem(_rect, 2, 0, 0, 2));
    });

    test('ScaleItems scaleY ile; geri alınır', () {
      final h = EditHistory(_doc([_rect, _img]));
      h.execute(ScaleItems(h.document, 0, {'r', 'g'}, 2, 0, 0, scaleY: 1));
      final g = h.document.pages[0].items[1] as ImageItem;
      expect((g.width, g.height), (80, 20));
      h.undo();
      expect(h.document.pages[0].items, [_rect, _img]);
    });
  });

  group('renk', () {
    test('saydamlık korunur; görsel değişmez', () {
      expect((recolorItem(_pen, 0xFFD42A3F) as Stroke).color, 0xFFD42A3F);
      expect(
        (recolorItem(_hl, 0xFF93F0A6) as Stroke).color,
        0x6693F0A6,
        reason: 'fosforlu yarı saydam kalır',
      );
      expect((recolorItem(_text, 0xFF178A47) as TextItem).color, 0xFF178A47);
      expect(recolorItem(_img, 0xFF178A47), _img);
      expect(hasColor(_img), isFalse);
    });

    test('RecolorItems tek adım; görseli saymaz', () {
      final h = EditHistory(_doc([_pen, _rect, _img]));
      final cmd = RecolorItems(h.document, 0, {'p', 'r', 'g'}, 0xFFE07F00);
      expect(cmd.before.keys, {'p', 'r'});
      h.execute(cmd);
      final items = h.document.pages[0].items;
      expect((items[0] as Stroke).color, 0xFFE07F00);
      expect((items[1] as Shape).color, 0xFFE07F00);
      expect(items[2], _img);
      h.undo();
      expect(h.document.pages[0].items, [_pen, _rect, _img]);
      expect(RecolorItems(h.document, 0, {'g'}, 0xFF000000).isEmpty, isTrue);
    });
  });

  group('sayfalar arası taşıma', () {
    test('kaynaktan çıkar, hedefe kaydırılarak eklenir; geri alınır', () {
      final h = EditHistory(_doc([_pen, _rect, _text], [_img]));
      h.execute(TransferItems(h.document, 0, 1, {'r', 'p'}, 5, -5));
      expect(h.document.pages[0].items, [_text]);
      final moved = h.document.pages[1].items;
      expect(moved.map((i) => i.id), ['g', 'p', 'r'], reason: 'sıra korunur');
      expect((moved[2] as Shape).x1, 15);
      expect((moved[2] as Shape).y1, 5);
      h.undo();
      expect(h.document.pages[0].items, [_pen, _rect, _text]);
      expect(h.document.pages[1].items, [_img]);
      h.redo();
      expect(h.document.pages[1].items, hasLength(3));
    });
  });
}
