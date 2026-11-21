import 'dart:math' as math;

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

InstrumentPose _pose(
  InstrumentKind kind, {
  double x = 300,
  double y = 400,
  double angle = 0,
  double radius = compassDefaultRadius,
}) => InstrumentPose(
  kind: kind,
  page: 0,
  x: x,
  y: y,
  angle: angle,
  radius: radius,
);

Matcher _at(double x, double y) => predicate<({double x, double y})>(
  (p) => (p.x - x).abs() < 1e-6 && (p.y - y).abs() < 1e-6,
  '($x, $y)',
);

void main() {
  group('yerleşim', () {
    test('yerel → sayfa → yerel', () {
      final p = _pose(InstrumentKind.ruler, angle: 0.7);
      final a = p.toPage(37, -12);
      expect(p.toLocal(a.x, a.y), _at(37, -12));
    });

    test('90° döndürünce yerel x aşağı bakar (y aşağı uzay)', () {
      final p = _pose(InstrumentKind.ruler, angle: math.pi / 2);
      expect(p.toPage(10, 0), _at(300, 410));
    });

    test('cetvel 1 cm sayfada 1 cm; gövde içi / dışı', () {
      expect(rulerLength, closeTo(16 * 72 / 2.54, 1e-9));
      final p = _pose(InstrumentKind.ruler);
      expect(instrumentContains(p, 300, 400), isTrue);
      expect(instrumentContains(p, 300 + rulerLength / 2 - 1, 400), isTrue);
      expect(instrumentContains(p, 300 + rulerLength / 2 + 1, 400), isFalse);
      expect(instrumentContains(p, 300, 400 + rulerHeight / 2 + 1), isFalse);
      // Döndürülmüş cetvelde de.
      final r = _pose(InstrumentKind.ruler, angle: math.pi / 2);
      expect(instrumentContains(r, 300, 400 + rulerLength / 2 - 1), isTrue);
      expect(instrumentContains(r, 300 + rulerLength / 2 - 1, 400), isFalse);
    });

    test('iletki yarım daire: merkezin üstü içeride, altı dışarıda', () {
      final p = _pose(InstrumentKind.protractor);
      expect(instrumentContains(p, 300, 400 - 10), isTrue);
      expect(instrumentContains(p, 300, 400 + 10), isFalse);
      expect(instrumentContains(p, 300, 400 - protractorRadius - 1), isFalse);
    });

    test('pergelin gövdesi yok', () {
      final p = _pose(InstrumentKind.compass);
      expect(instrumentOutline(p), isEmpty);
      expect(instrumentContains(p, 300, 400), isFalse);
      expect(instrumentEdges(p), isEmpty);
    });
  });

  group('kenara yaslama', () {
    test('cetvelin üst kenarı: dışa bakan normal, yakın nokta bulunur', () {
      final p = _pose(InstrumentKind.ruler);
      final top = 400 - rulerHeight / 2;
      final e = nearestInstrumentEdge([p], 320, top - 5, 8);
      expect(e, isA<LineEdge>());
      final line = e! as LineEdge;
      expect(line.ny, closeTo(-1, 1e-9));
      expect(nearestInstrumentEdge([p], 320, top - 20, 8), isNull);
      // Kalınlığın yarısı kadar dışarı: mürekkep cetvelin altına girmez.
      expect(snapToEdge(e, 333, top - 7, offset: 2), _at(333, top - 2));
      // İçeriden başlasa da dışa yaslanır.
      expect(snapToEdge(e, 333, top + 4, offset: 2), _at(333, top - 2));
    });

    test('kenarın ucundan öteye uzamaz', () {
      final p = _pose(InstrumentKind.ruler);
      final e = instrumentEdges(p).first;
      final end = 300 + rulerLength / 2;
      expect(snapToEdge(e, end + 50, 300).x, closeTo(end, 1e-9));
    });

    test('döndürülmüş cetvel: kenar boyunca düz çizgi', () {
      final p = _pose(InstrumentKind.ruler, angle: math.pi / 6);
      final e = instrumentEdges(p).first as LineEdge;
      final pts = [
        for (var i = 0; i < 10; i++)
          snapToEdge(e, 250 + i * 13.0, 330 + (i.isEven ? 3 : -3)),
      ];
      // Hepsi aynı doğruda: 30°'lik eğimle.
      for (var i = 1; i < pts.length; i++) {
        final angle = math.atan2(pts[i].y - pts[0].y, pts[i].x - pts[0].x);
        expect(angle, closeTo(math.pi / 6, 1e-9));
      }
    });

    test('gönyenin üç kenarı, hipotenüs 45°', () {
      final p = _pose(InstrumentKind.setSquare);
      final edges = instrumentEdges(p).cast<LineEdge>();
      expect(edges, hasLength(3));
      final hyp = edges.last;
      expect(
        math.atan2(hyp.by - hyp.ay, hyp.bx - hyp.ax).abs(),
        closeTo(3 * math.pi / 4, 1e-9),
      );
      // Normaller gövdeden dışarı: kenarın ortasından normal yönünde
      // biraz gidilince gövdenin dışındayız.
      for (final e in edges) {
        final mx = (e.ax + e.bx) / 2, my = (e.ay + e.by) / 2;
        expect(instrumentContains(p, mx - e.nx * 2, my - e.ny * 2), isTrue);
        expect(instrumentContains(p, mx + e.nx * 2, my + e.ny * 2), isFalse);
      }
    });

    test(
      'iletkinin yayı: yarıçapta, dışa kaydırılır, tabanın altına inmez',
      () {
        final p = _pose(InstrumentKind.protractor);
        const r = protractorRadius;
        // Merkezin sağ üstünde, yayın 3 pt dışında.
        final a = -math.pi / 4;
        final px = 300 + (r + 3) * math.cos(a),
            py = 400 + (r + 3) * math.sin(a);
        final e = nearestInstrumentEdge([p], px, py, 8);
        expect(e, isA<ArcEdge>());
        final s = snapToEdge(e!, px, py, offset: 1);
        expect(
          math.sqrt((s.x - 300) * (s.x - 300) + (s.y - 400) * (s.y - 400)),
          closeTo(r + 1, 1e-9),
        );
        // Tabanın altındaki nokta yayın ucuna sıkışır.
        final below = snapToEdge(e, 300 + r, 400 + 30);
        expect(below, _at(300 + r, 400));
      },
    );

    test('birden çok araçtan en yakını', () {
      final ruler = _pose(InstrumentKind.ruler);
      final square = _pose(InstrumentKind.setSquare, x: 100, y: 100);
      final top = 400 - rulerHeight / 2;
      expect(
        nearestInstrumentEdge([square, ruler], 300, top - 3, 8),
        isA<LineEdge>(),
      );
      expect(nearestInstrumentEdge([square, ruler], 300, top - 3, 2), isNull);
    });
  });

  group('döndürme', () {
    test('15° katlarına 2° içinde oturur', () {
      const deg = math.pi / 180;
      expect(snapInstrumentAngle(44 * deg), closeTo(45 * deg, 1e-12));
      expect(snapInstrumentAngle(-1.5 * deg), closeTo(0, 1e-12));
      expect(snapInstrumentAngle(37 * deg), 37 * deg);
    });

    test('gösterge açısı matematikteki gibi (saat yönünün tersi)', () {
      expect(displayDegrees(-math.pi / 6), closeTo(30, 1e-9));
      expect(displayDegrees(math.pi / 2), closeTo(270, 1e-9));
      expect(displayDegrees(-1e-6), 0);
    });
  });

  group('pergel', () {
    test('kalem ucu yarıçapta; menteşe bacak boyunda', () {
      final p = _pose(InstrumentKind.compass, angle: math.pi / 2);
      expect(compassPencil(p), _at(300, 400 + compassDefaultRadius));
      final h = compassHinge(p);
      final legNeedle = math.sqrt(
        (h.x - 300) * (h.x - 300) + (h.y - 400) * (h.y - 400),
      );
      final pen = compassPencil(p);
      final legPencil = math.sqrt(
        (h.x - pen.x) * (h.x - pen.x) + (h.y - pen.y) * (h.y - pen.y),
      );
      expect(legNeedle, closeTo(compassLegLength, 1e-9));
      expect(legPencil, closeTo(compassLegLength, 1e-9));
    });

    test('açıklık milimetreye yuvarlanır, aralıkta kalır', () {
      expect(compassRadiusFor(3.04 * ptPerCm), closeTo(3 * ptPerCm, 1e-9));
      expect(compassRadiusFor(0), compassMinRadius);
      expect(compassRadiusFor(1000 * ptPerCm), compassMaxRadius);
    });

    test('açı sıçraması açılır: −π / π geçişinde yay ters dönmez', () {
      expect(unwrapAngle(3.1, -3.1), closeTo(-3.1 + 2 * math.pi, 1e-12));
      expect(unwrapAngle(-3.1, 3.1), closeTo(3.1 - 2 * math.pi, 1e-12));
      expect(unwrapAngle(10, 10.2), 10.2);
    });

    test('yay noktaları yarıçapta, uçlar dahil, sık', () {
      final pts = arcPoints(0, 0, 100, 0, math.pi / 2);
      expect(pts.first, _at(100, 0));
      expect(pts.last, _at(0, 100));
      for (final p in pts) {
        expect(math.sqrt(p.x * p.x + p.y * p.y), closeTo(100, 1e-9));
      }
      for (var i = 1; i < pts.length; i++) {
        final d = math.sqrt(
          math.pow(pts[i].x - pts[i - 1].x, 2) +
              math.pow(pts[i].y - pts[i - 1].y, 2),
        );
        expect(d, lessThanOrEqualTo(2));
      }
      // Ters yön de.
      expect(arcPoints(0, 0, 50, math.pi, 0).last, _at(50, 0));
    });
  });
}
