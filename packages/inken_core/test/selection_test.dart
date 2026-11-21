import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

Stroke _stroke(String id, List<(double, double)> pts, {double width = 2}) =>
    Stroke(
      id: id,
      tool: InkTool.pen,
      color: 0xFF000000,
      width: width,
      points: [for (final (x, y) in pts) InkPoint(x, y, 0.7)],
    );

const _rect = Shape(
  id: 'r',
  kind: ShapeKind.rectangle,
  color: 0xFF000000,
  width: 4,
  x1: 100,
  y1: 100,
  x2: 200,
  y2: 150,
);

const _text = TextItem(
  id: 't',
  text: 'x²',
  color: 0xFF000000,
  fontSize: 12,
  x: 300,
  y: 300,
  width: 40,
  height: 16,
);

PageLayer _page(List<InkItem> items) =>
    PageLayer(sourceIndex: 0, width: 600, height: 800, items: items);

void main() {
  group('translateItem', () {
    test('her öğe türünü kaydırır, kimlik ve basınç korunur', () {
      final s = translateItem(_stroke('a', [(0, 0), (10, 5)]), 3, -2) as Stroke;
      expect(s.id, 'a');
      expect(s.points, [
        const InkPoint(3, -2, 0.7),
        const InkPoint(13, 3, 0.7),
      ]);

      final r = translateItem(_rect, -100, 10) as Shape;
      expect((r.x1, r.y1, r.x2, r.y2), (0.0, 110.0, 100.0, 160.0));

      final t = translateItem(_text, 5, 5) as TextItem;
      expect((t.x, t.y, t.width, t.height), (305.0, 305.0, 40.0, 16.0));
    });
  });

  group('itemAt', () {
    final page = _page([
      _stroke('alt', [(0, 0), (100, 0)]),
      _stroke('üst', [(50, -20), (50, 20)]),
      _rect,
      _text,
    ]);

    test('kesişimde en üstteki öğe', () {
      expect(itemAt(page, 50, 0, 2), 'üst');
      expect(itemAt(page, 10, 0, 2), 'alt');
    });

    test('pay içinde yakalar, dışında boş', () {
      expect(itemAt(page, 10, 3, 3), 'alt');
      expect(itemAt(page, 10, 30, 3), isNull);
    });

    test('dikdörtgende kenar, metinde kutunun içi', () {
      expect(itemAt(page, 150, 100, 2), 'r');
      expect(itemAt(page, 150, 125, 2), isNull);
      expect(itemAt(page, 320, 308, 2), 't');
    });
  });

  group('itemsInRect', () {
    final page = _page([
      _stroke('a', [(10, 10), (40, 30)]),
      _stroke('b', [(30, 30), (90, 90)]),
      _rect,
    ]);

    test('yalnızca tamamen içeride kalanlar', () {
      expect(itemsInRect(page, 0, 0, 50, 50), {'a'});
      expect(itemsInRect(page, 0, 0, 250, 250), {'a', 'b', 'r'});
    });

    test('köşe sırası önemsiz', () {
      expect(itemsInRect(page, 50, 50, 0, 0), {'a'});
    });

    test('boş dikdörtgen bir şey seçmez', () {
      expect(itemsInRect(page, 20, 20, 20, 20), isEmpty);
    });
  });

  test('selectionBounds kalınlığın yarısını katar', () {
    final page = _page([
      _stroke('a', [(10, 10), (40, 30)]),
      _rect,
    ]);
    expect(selectionBounds(page, {'a', 'r'}), (
      left: 9.0,
      top: 9.0,
      right: 202.0,
      bottom: 152.0,
    ));
    expect(selectionBounds(page, {'yok'}), isNull);
  });

  group('MoveItems', () {
    final doc = InkenDocument(
      pages: [
        _page([
          _stroke('a', [(0, 0), (10, 10)]),
          _rect,
          _text,
        ]),
      ],
    );

    test('yalnızca seçilenleri taşır, sıra değişmez; geri alınır', () {
      final history = EditHistory(doc);
      history.execute(MoveItems(history.document, 0, {'a', 't'}, 5, 7));
      final items = history.document.pages[0].items;
      expect([for (final i in items) i.id], ['a', 'r', 't']);
      expect((items[0] as Stroke).points.first, const InkPoint(5, 7, 0.7));
      expect(items[1], _rect);
      expect((items[2] as TextItem).x, 305);

      history.undo();
      expect(history.document, doc);
      history.redo();
      expect(history.document.pages[0].items[0], items[0]);
    });

    test('geri alma yuvarlama hatasız eski hale döner', () {
      final history = EditHistory(doc);
      history.execute(MoveItems(history.document, 0, {'a'}, 0.1, 0.7));
      history.undo();
      expect(history.document, doc);
    });

    test('taşınan belge kayıt biçiminde gidiş-dönüş yapar', () {
      final moved = MoveItems(doc, 0, {'r'}, -50, 25).apply(doc);
      final back = decodeInkenDocument(encodeInkenDocument(moved));
      expect(back, moved);
    });
  });

  group('scaleItem', () {
    test('çizgi: noktalar sabit noktaya göre, kalınlık da ölçeklenir', () {
      final s = scaleItem(
        _stroke('a', [(10, 10), (20, 30)], width: 2),
        2,
        10,
        10,
      ) as Stroke;
      expect(s.id, 'a');
      expect(s.width, 4);
      expect(s.points, [
        const InkPoint(10, 10, 0.7),
        const InkPoint(30, 50, 0.7),
      ]);
    });

    test('şekil ve metin', () {
      final r = scaleItem(_rect, 0.5, 100, 100) as Shape;
      expect(
        (r.x1, r.y1, r.x2, r.y2, r.width),
        (100.0, 100.0, 150.0, 125.0, 2.0),
      );
      final t = scaleItem(_text, 2, 300, 300) as TextItem;
      expect(
        (t.x, t.y, t.width, t.height, t.fontSize),
        (300.0, 300.0, 80.0, 32.0, 24.0),
      );
    });

    test('kalınlık dahil sınır kutusu sabit noktaya göre ölçeklenir', () {
      final page = _page([
        _stroke('a', [(10, 10), (40, 30)]),
        _rect,
      ]);
      final b = selectionBounds(page, {'a', 'r'})!;
      final scaled = _page([
        for (final i in page.items) scaleItem(i, 1.5, b.left, b.top),
      ]);
      final b2 = selectionBounds(scaled, {'a', 'r'})!;
      expect(b2.left, closeTo(b.left, 1e-9));
      expect(b2.top, closeTo(b.top, 1e-9));
      expect(b2.right, closeTo(b.left + (b.right - b.left) * 1.5, 1e-9));
      expect(b2.bottom, closeTo(b.top + (b.bottom - b.top) * 1.5, 1e-9));
    });
  });

  group('ScaleItems', () {
    final doc = InkenDocument(
      pages: [
        _page([
          _stroke('a', [(0, 0), (10, 10)]),
          _rect,
        ]),
      ],
    );

    test('yalnızca seçilenleri ölçekler; geri alma birebir', () {
      final history = EditHistory(doc);
      history.execute(ScaleItems(history.document, 0, {'a'}, 1.3, 0.1, 0.1));
      final items = history.document.pages[0].items;
      expect((items[0] as Stroke).width, closeTo(2.6, 1e-9));
      expect(items[1], _rect);
      history.undo();
      expect(history.document, doc);
      history.redo();
      expect(history.document.pages[0].items, items);
    });

    test('ölçeklenen belge kayıt biçiminde gidiş-dönüş yapar', () {
      final scaled = ScaleItems(doc, 0, {'a', 'r'}, 2, 0, 0).apply(doc);
      expect(decodeInkenDocument(encodeInkenDocument(scaled)), scaled);
    });
  });
}
