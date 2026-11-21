import 'dart:math' as math;

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  group('constrainShapeEnd', () {
    test('dikdörtgen ve elips serbestken dokunulmaz', () {
      expect(constrainShapeEnd(ShapeKind.rectangle, 0, 0, 30, 10), (
        x: 30.0,
        y: 10.0,
      ));
    });

    test('Shift: dikdörtgen kare, elips daire; yön korunur', () {
      expect(
        constrainShapeEnd(ShapeKind.rectangle, 10, 10, 40, 20, constrain: true),
        (x: 40.0, y: 40.0),
      );
      expect(
        constrainShapeEnd(ShapeKind.ellipse, 10, 10, 0, -20, constrain: true),
        (x: -20.0, y: -20.0),
      );
    });

    test('çizgi yataya yakınsa yataya oturur, uzunluk korunur', () {
      final e = constrainShapeEnd(ShapeKind.line, 0, 0, 100, 3);
      expect(e.y, 0);
      expect(e.x, closeTo(math.sqrt(100 * 100 + 9), 1e-9));
    });

    test('ok dikeye ve 45°ye yakınsa oturur', () {
      final v = constrainShapeEnd(ShapeKind.arrow, 0, 0, -2, -50);
      expect(v.x, 0);
      expect(v.y, lessThan(0));
      final d = constrainShapeEnd(ShapeKind.arrow, 0, 0, 50, 47);
      expect(d.x, closeTo(d.y, 1e-9));
    });

    test('pay dışındaki eğik çizgiye dokunulmaz', () {
      expect(constrainShapeEnd(ShapeKind.line, 0, 0, 100, 30), (
        x: 100.0,
        y: 30.0,
      ));
    });

    test('Shift: çizgi 15° katlarına oturur', () {
      final e = constrainShapeEnd(
        ShapeKind.line,
        0,
        0,
        100,
        30,
        constrain: true,
      );
      final deg = math.atan2(e.y, e.x) * 180 / math.pi;
      expect(deg, closeTo(15, 1e-9));
    });

    test('sıfır uzunluk', () {
      expect(constrainShapeEnd(ShapeKind.arrow, 5, 5, 5, 5), (x: 5.0, y: 5.0));
    });
  });

  test('şekiller kayıt biçiminde gidiş-dönüş yapar', () {
    final doc = InkenDocument(
      pages: [
        PageLayer(
          sourceIndex: 0,
          width: 200,
          height: 300,
          items: [
            for (final (i, k) in ShapeKind.values.indexed)
              Shape(
                id: 's$i',
                kind: k,
                color: 0xFFD42A3F,
                width: 3,
                x1: 10,
                y1: 20 + i * 30,
                x2: 120.5,
                y2: 40 + i * 30,
              ),
          ],
        ),
      ],
    );
    expect(decodeInkenDocument(encodeInkenDocument(doc)), doc);
  });
}
