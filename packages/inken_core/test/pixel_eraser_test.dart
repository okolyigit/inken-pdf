import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

Stroke _line(List<(double, double)> pts, {double width = 2}) => Stroke(
  id: 's',
  tool: InkTool.pen,
  color: 0xFF000000,
  width: width,
  points: [for (final (x, y) in pts) InkPoint(x, y)],
);

void main() {
  group('piksel silgisi', () {
    test('dokunmuyorsa null', () {
      final s = _line([(0, 0), (100, 0)]);
      expect(eraseStrokePoints(s, 50, 50, 50, 60, 5), isNull);
    });

    test('ortadan silmek iki parça bırakır; uzun aralık da kesilir', () {
      // Yalnızca iki nokta: silgi ara noktalar sayesinde ortadan keser.
      final s = _line([(0, 0), (100, 0)]);
      final pieces = eraseStrokePoints(s, 50, -10, 50, 10, 5)!;
      expect(pieces, hasLength(2));
      expect(pieces[0].first, const InkPoint(0, 0));
      expect(pieces[1].last, const InkPoint(100, 0));
      // Kesim uçları silginin dışında (yarıçap + yarım kalınlık).
      expect(pieces[0].last.x, lessThan(50 - 5));
      expect(pieces[1].first.x, greaterThan(50 + 5));
      // Ara noktalar kalmaz: parça başına özgün nokta + kesim ucu.
      expect(pieces[0], hasLength(2));
      expect(pieces[1], hasLength(2));
    });

    test('ucu silmek tek parça bırakır, tamamı silinirse boş', () {
      final s = _line([(0, 0), (10, 0), (20, 0), (30, 0)]);
      final end = eraseStrokePoints(s, 30, 0, 30, 0, 4)!;
      expect(end, hasLength(1));
      expect(end.single.first, const InkPoint(0, 0));
      expect(eraseStrokePoints(s, -10, 0, 40, 0, 4), isEmpty);
    });

    test('basınç ara noktalarda doğrusal', () {
      final s = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0,
        width: 0,
        points: const [InkPoint(0, 0, 0), InkPoint(100, 0, 1)],
      );
      final pieces = eraseStrokePoints(s, 50, -5, 50, 5, 10)!;
      final cut = pieces[0].last;
      expect(cut.p, closeTo(cut.x / 100, 1e-9));
    });
  });

  group('SetPageItems', () {
    test('uygula / geri al / yinele ve gidiş-dönüş', () {
      final doc = InkenDocument.forPdf(const [(width: 100, height: 100)]);
      final s = _line([(0, 0), (100, 0)]);
      final history = EditHistory(doc)..execute(AddItems(0, [s]));
      final pieces = eraseStrokePoints(s, 50, -10, 50, 10, 5)!;
      final after = [
        for (final p in pieces) s.copyWith(id: newItemId(), points: p),
      ];
      history.execute(SetPageItems(0, history.document.pages[0].items, after));
      expect(history.document.pages[0].items, hasLength(2));

      final restored = decodeInkenDocument(
        encodeInkenDocument(history.document),
      );
      // Koordinatlar kayıtta yuvarlanır; kodlanmış hali kararlı olmalı.
      expect(restored.pages[0].items, hasLength(2));
      expect(
        encodeInkenDocument(restored),
        encodeInkenDocument(history.document),
      );

      history.undo();
      expect(history.document.pages[0].items, [s]);
      history.redo();
      expect(history.document.pages[0].items, after);
    });
  });
}
