import 'dart:convert';

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

Stroke _stroke(String id, List<InkPoint> points, {double width = 2}) => Stroke(
  id: id,
  tool: InkTool.pen,
  color: 0xFF000000,
  width: width,
  points: points,
);

InkenDocument _sample() => InkenDocument(
  pages: [
    PageLayer(
      sourceIndex: 0,
      width: 595,
      height: 842,
      items: [
        _stroke('s1', const [
          InkPoint(10, 10, 0.25),
          InkPoint(50.5, 12.125, 1),
        ]),
        const InkItem.stroke(
          id: 'h1',
          tool: InkTool.highlighter,
          color: 0x6EFFE600,
          width: 22,
          points: [InkPoint(72, 77), InkPoint(250, 77)],
        ),
        const InkItem.shape(
          id: 'r1',
          kind: ShapeKind.rectangle,
          color: 0xFF008C3C,
          width: 2,
          x1: 80,
          y1: 342,
          x2: 240,
          y2: 462,
        ),
        const InkItem.shape(
          id: 'a1',
          kind: ShapeKind.arrow,
          color: 0xFF0000FF,
          width: 1.5,
          x1: 0,
          y1: 0,
          x2: 100,
          y2: 100,
        ),
        const InkItem.text(
          id: 't1',
          text: 'Türkçe: ığüşöç İĞÜŞÖÇ √2 ≈ 1,41',
          color: 0xFFC85000,
          fontSize: 16,
          x: 80,
          y: 530,
          width: 260,
          height: 20,
        ),
      ],
    ),
    const PageLayer(template: PageTemplate.grid, width: 595, height: 842),
    const PageLayer(sourceIndex: 1, width: 595, height: 842),
  ],
);

void main() {
  group('JSON gidiş-dönüş', () {
    test('belge kodlanıp çözülünce aynı kalır', () {
      final doc = _sample();
      final back = decodeInkenDocument(encodeInkenDocument(doc));
      expect(back, doc);
      expect(back.formatVersion, currentFormatVersion);
    });

    test('noktalar düz sayı listesi olarak yazılır', () {
      final json =
          jsonDecode(encodeInkenDocument(_sample())) as Map<String, dynamic>;
      final first = ((json['pages'] as List).first as Map)['items'][0] as Map;
      expect(first['type'], 'stroke');
      expect(first['points'], [10, 10, 0.25, 50.5, 12.125, 1]);
    });

    test('eklenen sayfa ve boş alanlar', () {
      final back = decodeInkenDocument(encodeInkenDocument(_sample()));
      expect(back.pages[1].isInserted, isTrue);
      expect(back.pages[1].template, PageTemplate.grid);
      expect(back.pages[2].sourceIndex, 1);
      expect(back.pages[2].items, isEmpty);
    });

    test('daha yeni sürüm reddedilir', () {
      expect(
        () => decodeInkenDocument('{"formatVersion": 999, "pages": []}'),
        throwsA(isA<UnsupportedFormatVersion>()),
      );
    });

    test('bozuk içerik FormatException verir', () {
      expect(() => decodeInkenDocument('[]'), throwsFormatException);
      expect(() => decodeInkenDocument('{"pages": []}'), throwsFormatException);
      expect(() => decodeInkenDocument('{bozuk'), throwsFormatException);
      expect(
        () => decodeInkenDocument(
          '{"formatVersion":1,"pages":[{"width":1,"height":1,'
          '"items":[{"type":"stroke","id":"x","tool":"pen","color":0,'
          '"width":1,"points":[1,2]}]}]}',
        ),
        throwsFormatException,
      );
    });

    test('forPdf boş katmanlar üretir', () {
      final doc = InkenDocument.forPdf([
        (width: 595, height: 842),
        (width: 842, height: 595),
      ]);
      expect(doc.pages.length, 2);
      expect(doc.pages[1].sourceIndex, 1);
      expect(doc.isEmpty, isTrue);
    });
  });

  group('geri al / yinele', () {
    test('ekle → geri al → yinele', () {
      final h = EditHistory(InkenDocument.forPdf([(width: 100, height: 100)]));
      final s = _stroke('a', const [InkPoint(1, 1), InkPoint(2, 2)]);
      expect(h.canUndo, isFalse);
      h.execute(AddItems(0, [s]));
      expect(h.document.pages[0].items, [s]);
      expect(h.isDirty, isTrue);
      expect(h.undo(), isTrue);
      expect(h.document.pages[0].items, isEmpty);
      expect(h.redo(), isTrue);
      expect(h.document.pages[0].items, [s]);
      expect(h.redo(), isFalse);
    });

    test('yeni işlem yinele yığınını temizler', () {
      final h = EditHistory(InkenDocument.forPdf([(width: 100, height: 100)]));
      h.execute(
        AddItems(0, [
          _stroke('a', const [InkPoint(1, 1)]),
        ]),
      );
      h.undo();
      h.execute(
        AddItems(0, [
          _stroke('b', const [InkPoint(2, 2)]),
        ]),
      );
      expect(h.canRedo, isFalse);
      expect(h.document.pages[0].items.single.id, 'b');
    });

    test('silinen öğeler geri alınca eski sırasına döner', () {
      final h = EditHistory(_sample());
      final before = h.document;
      final cmd = RemoveItems(h.document, 0, {'s1', 'r1', 'yok'});
      expect(cmd.removed.length, 2);
      h.execute(cmd);
      expect(h.document.pages[0].items.map((i) => i.id), ['h1', 'a1', 't1']);
      h.undo();
      expect(h.document, before);
    });

    test('öğe değiştirme', () {
      final h = EditHistory(_sample());
      final old = h.document.pages[0].items[2] as Shape;
      final moved = old.copyWith(x1: old.x1 + 10, x2: old.x2 + 10);
      h.execute(ReplaceItem(0, old, moved));
      expect(h.document.pages[0].items[2], moved);
      h.undo();
      expect(h.document.pages[0].items[2], old);
    });

    test('sayfa ekleme', () {
      final h = EditHistory(InkenDocument.forPdf([(width: 100, height: 100)]));
      const page = PageLayer(
        template: PageTemplate.blank,
        width: 100,
        height: 100,
      );
      h.execute(const InsertPage(1, page));
      expect(h.document.pages.length, 2);
      expect(h.document.pages[1], page);
      h.undo();
      expect(h.document.pages.length, 1);
    });

    test('kaydetme işareti ve sınır', () {
      final h = EditHistory(
        InkenDocument.forPdf([(width: 100, height: 100)]),
        limit: 3,
      );
      for (var i = 0; i < 5; i++) {
        h.execute(
          AddItems(0, [
            _stroke('s$i', const [InkPoint(1, 1)]),
          ]),
        );
      }
      h.markSaved();
      expect(h.isDirty, isFalse);
      var undone = 0;
      while (h.undo()) {
        undone++;
      }
      expect(undone, 3);
      expect(h.document.pages[0].items.length, 2);
      expect(h.isDirty, isTrue);
    });
  });

  group('silgi kesişimi', () {
    final page = _sample().pages[0];

    test('çizgiyi kesen silgi hareketi onu bulur', () {
      expect(itemsHitBySegment(page, 30, 0, 30, 30, 1), {'s1', 'a1'});
    });

    test('uzaktaki hareket hiçbir şey bulmaz', () {
      expect(itemsHitBySegment(page, 400, 700, 420, 720, 5), isEmpty);
    });

    test('yarıçap ve çizgi kalınlığı hesaba katılır', () {
      // s1 yaklaşık y=10..12'de, kalınlık 2. 6 pt aşağıdan geçen silgi:
      expect(itemsHitBySegment(page, 20, 18, 21, 18, 2), isNot(contains('s1')));
      expect(itemsHitBySegment(page, 20, 18, 21, 18, 7), contains('s1'));
      // Fosforlu 22 pt kalın: merkezden 10 pt uzakta bile dokunur.
      expect(itemsHitBySegment(page, 100, 87, 101, 87, 0.5), contains('h1'));
    });

    test('dikdörtgenin içi boş: yalnızca kenarı hedef', () {
      expect(itemsHitBySegment(page, 160, 400, 161, 401, 3), isEmpty);
      expect(itemsHitBySegment(page, 79, 400, 81, 400, 1), {'r1'});
    });

    test('metin kutusunun içi hedef', () {
      expect(itemsHitBySegment(page, 100, 540, 101, 540, 1), {'t1'});
    });

    test('tek noktalı çizgi', () {
      final p = PageLayer(
        width: 10,
        height: 10,
        items: [
          _stroke('nokta', const [InkPoint(5, 5)]),
        ],
      );
      expect(itemsHitBySegment(p, 0, 5, 10, 5, 1), {'nokta'});
      expect(itemsHitBySegment(p, 0, 9, 10, 9, 1), isEmpty);
    });

    test('elips dış hattı', () {
      const e = InkItem.shape(
        id: 'e',
        kind: ShapeKind.ellipse,
        color: 0,
        width: 1,
        x1: 0,
        y1: 0,
        x2: 100,
        y2: 50,
      );
      const p = PageLayer(width: 200, height: 200, items: [e]);
      expect(itemsHitBySegment(p, 50, 25, 51, 25, 2), isEmpty); // merkez
      expect(itemsHitBySegment(p, 99, 25, 101, 25, 1), {'e'}); // sağ uç
    });
  });

  test('kimlikler benzersiz', () {
    final ids = {for (var i = 0; i < 1000; i++) newItemId()};
    expect(ids.length, 1000);
    expect(ids.first.length, 32);
  });
}
