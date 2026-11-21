import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  // 100 × 200 dikey sayfa.
  final doc = InkenDocument.forPdf([
    (width: 100, height: 200),
    (width: 300, height: 400),
  ]);
  const stroke = Stroke(
    id: 's',
    tool: InkTool.pen,
    color: 0xFF000000,
    width: 2,
    points: [InkPoint(0, 0, 0.3), InkPoint(10, 20)],
  );
  const line = Shape(
    id: 'l',
    kind: ShapeKind.line,
    color: 0xFF000000,
    width: 2,
    x1: 10,
    y1: 10,
    x2: 30,
    y2: 50,
  );
  const text = TextItem(
    id: 't',
    text: 'a',
    color: 0xFF000000,
    fontSize: 16,
    x: 0,
    y: 0,
    width: 40,
    height: 20,
  );
  final inked = AddItems(0, [stroke, line, text]).apply(doc);

  group('sayfa döndürme', () {
    test(
      'sağa döndürme: boyut yer değiştirir, noktalar saat yönünde döner',
      () {
        final p = rotatePage(inked.pages[0], 1);
        expect((p.width, p.height), (200.0, 100.0));
        expect(p.rotation, 1);
        final s = p.items[0] as Stroke;
        // Sol üst köşe sağ üste gider; basınç korunur.
        expect(s.points.first, const InkPoint(200, 0, 0.3));
        expect(s.points.last, const InkPoint(180, 10));
        final l = p.items[1] as Shape;
        expect((l.x1, l.y1, l.x2, l.y2), (190.0, 10.0, 150.0, 30.0));
      },
    );

    test('metin dik kalır, ortası döner', () {
      final t = rotatePage(inked.pages[0], 1).items[2] as TextItem;
      // Orta (20, 10) → (190, 20).
      expect((t.x, t.y, t.width, t.height), (170.0, 10.0, 40.0, 20.0));
      expect(t.fontSize, 16);
    });

    test('dört kez sağa ya da sağ + sol özgün hali verir', () {
      var p = inked.pages[0];
      for (var i = 0; i < 4; i++) {
        p = rotatePage(p, 1);
      }
      expect(p, inked.pages[0]);
      expect(rotatePage(rotatePage(inked.pages[0], 1), -1), inked.pages[0]);
    });

    test('sola döndürme bekleyen turu 3 yapar; 180° boyutu korur', () {
      expect(rotatePage(doc.pages[0], -1).rotation, 3);
      final half = rotatePage(doc.pages[0], 2);
      expect((half.width, half.height), (100.0, 200.0));
      expect(half.rotation, 2);
    });

    test('eklenen sayfada yalnızca boyut döner', () {
      final added = newPageLike(doc, 0, PageTemplate.lined);
      final p = rotatePage(added, 1);
      expect((p.width, p.height), (200.0, 100.0));
      expect(p.rotation, isNull);
      expect(p.template, PageTemplate.lined);
    });

    test('RotatePages tek adım; geri alınca eksiksiz döner', () {
      final h = EditHistory(inked);
      h.execute(RotatePages(inked, [0, 1], 1));
      expect(h.document.pages.map((p) => p.rotation), [1, 1]);
      expect(h.document.pages[1].width, 400);
      h.undo();
      expect(h.document, inked);
      h.redo();
      expect(h.document.pages[0].width, 200);
    });

    test('düzen anahtarı ve kaynak düzeni döndürmeyi görür', () {
      final rotated = RotatePages(doc, [1], 1).apply(doc);
      expect(pageLayoutKey(rotated), isNot(pageLayoutKey(doc)));
      expect(isSourceLayout(doc, 2), isTrue);
      expect(isSourceLayout(rotated, 2), isFalse);
      expect(doc.isEmpty, isTrue);
      expect(rotated.isEmpty, isFalse);
    });

    test('döndürme yoksa JSON\'da alan yok; varsa gidiş-dönüş', () {
      expect(encodeInkenDocument(inked), isNot(contains('rotation')));
      final rotated = RotatePages(inked, [0], 3).apply(inked);
      expect(decodeInkenDocument(encodeInkenDocument(rotated)), rotated);
    });
  });

  group('sayfa yönü', () {
    test('yeni sayfa istenen yönde, geçerli sayfanın kenarlarıyla', () {
      final land = newPageLike(
        doc,
        0,
        PageTemplate.grid,
        orientation: PageOrientation.landscape,
      );
      expect((land.width, land.height), (200.0, 100.0));
      expect(orientationOf(land), PageOrientation.landscape);
      final port = newPageLike(
        doc,
        0,
        PageTemplate.grid,
        orientation: PageOrientation.portrait,
      );
      expect((port.width, port.height), (100.0, 200.0));
      expect(
        orientationOf(newPageLike(doc, 0, PageTemplate.blank)),
        PageOrientation.portrait,
      );
    });
  });

  test('RemovePages birden çok sayfayı tek adımda siler ve geri getirir', () {
    final three = InsertPage(
      1,
      newPageLike(inked, 0, PageTemplate.grid),
    ).apply(inked);
    final h = EditHistory(three);
    h.execute(RemovePages(three, [2, 0]));
    expect(h.document.pages.single.template, PageTemplate.grid);
    h.undo();
    expect(h.document, three);
  });
}
