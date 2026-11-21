import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  test('penWidthAt: 0.5 basınç taban kalınlığı verir, basınçla artar', () {
    expect(penWidthAt(2, 0.5), closeTo(2, 1e-9));
    expect(penWidthAt(2, 1), greaterThan(penWidthAt(2, 0.5)));
    expect(penWidthAt(2, 0), greaterThan(0));
    expect(penWidthAt(2, 7), penWidthAt(2, 1));
  });

  test('ilk nokta olduğu gibi alınır, bitişte gerçek uç eklenir', () {
    final b = StrokeBuilder();
    b.add(10, 10, timeMs: 0);
    b.add(20, 10, timeMs: 10);
    b.add(30, 10, timeMs: 20);
    final pts = b.finish();
    expect(pts.first.x, 10);
    expect(pts.last.x, 30);
    expect(pts.last.y, 10);
    // Yumuşatma: ara noktalar ham noktanın gerisinde.
    expect(pts[1].x, lessThan(20));
  });

  test('çok yakın noktalar elenir', () {
    final b = StrokeBuilder(minDistance: 1);
    b.add(0, 0, timeMs: 0);
    for (var i = 1; i <= 20; i++) {
      b.add(0.01 * i, 0, timeMs: i.toDouble());
    }
    expect(b.points.length, 1);
  });

  test('tek dokunuş tek nokta üretir', () {
    final b = StrokeBuilder()..add(5, 5, timeMs: 0);
    expect(b.finish(), const [InkPoint(5, 5, 0.5)]);
  });

  test('cihaz basıncı kullanılır', () {
    final b = StrokeBuilder();
    b.add(0, 0, pressure: 0.2, timeMs: 0);
    for (var i = 1; i <= 30; i++) {
      b.add(i * 5.0, 0, pressure: 0.9, timeMs: i * 8.0);
    }
    expect(b.points.first.p, 0.2);
    expect(b.points.last.p, closeTo(0.9, 0.01));
  });

  test('basınç yoksa hızlı çizgi yavaş çizgiden ince olur', () {
    double finalPressure(double step) {
      final b = StrokeBuilder();
      for (var i = 0; i <= 60; i++) {
        b.add(i * step, 0, timeMs: i * 8.0);
      }
      return b.points.last.p;
    }

    final slow = finalPressure(1); // 0.125 px/ms
    final fast = finalPressure(24); // 3 px/ms
    expect(slow, greaterThan(fast));
    expect(fast, inInclusiveRange(0.2, 0.5));
    expect(slow, inInclusiveRange(0.5, 0.8));
  });

  test('hız ölçümü yakınlaştırmadan bağımsız', () {
    double finalPressure(double viewScale) {
      final b = StrokeBuilder();
      for (var i = 0; i <= 60; i++) {
        // Ekranda aynı hareket: sayfa uzayında 1/viewScale kadar.
        b.add(i * 10 / viewScale, 0, timeMs: i * 8.0, viewScale: viewScale);
      }
      return b.points.last.p;
    }

    expect(finalPressure(1), closeTo(finalPressure(4), 1e-9));
  });

  test('sabit basınç (fosforlu)', () {
    final b = StrokeBuilder(fixedPressure: 0.5);
    b.add(0, 0, pressure: 0.9, timeMs: 0);
    b.add(50, 0, pressure: 0.1, timeMs: 5);
    expect(b.finish().every((p) => p.p == 0.5), isTrue);
  });
}
