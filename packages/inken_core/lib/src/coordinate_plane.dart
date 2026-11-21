import 'dart:math' as math;

import 'model.dart';

/// 1 cm, pt cinsinden.
const double ptPerCm = 72 / 2.54;

/// Doğru parçası (sayfa uzayı).
typedef Segment = ({double x1, double y1, double x2, double y2});

/// Koordinat düzleminin çizgileri: 1 cm'lik kare çizgileri ([grid]),
/// eksenler ve uçlarındaki ok başları ([axes]).
///
/// Orijin kutunun ortasıdır; kare çizgileri orijinden dışa doğru 1 cm
/// aralıkla, yalnızca kutunun içinde çizilir (eksenler her zaman bir kare
/// çizgisinin üstündedir). Kutu büyütülse de kareler 1 cm kalır.
({List<Segment> grid, List<Segment> axes}) coordinatePlaneLines(
  Shape s, {
  double step = ptPerCm,
}) {
  final l = math.min(s.x1, s.x2), r = math.max(s.x1, s.x2);
  final t = math.min(s.y1, s.y2), b = math.max(s.y1, s.y2);
  final cx = (l + r) / 2, cy = (t + b) / 2;
  const eps = 1e-6;
  final grid = <Segment>[];
  for (var k = 1; cx + k * step < r - eps; k++) {
    for (final x in [cx - k * step, cx + k * step]) {
      grid.add((x1: x, y1: t, x2: x, y2: b));
    }
  }
  for (var k = 1; cy + k * step < b - eps; k++) {
    for (final y in [cy - k * step, cy + k * step]) {
      grid.add((x1: l, y1: y, x2: r, y2: y));
    }
  }
  final axes = <Segment>[
    (x1: l, y1: cy, x2: r, y2: cy),
    (x1: cx, y1: t, x2: cx, y2: b),
  ];
  // Ok başları dört uçta; kanat açısı ok şekliyle aynı (150°).
  final head = math.min(math.max(s.width * 4, 8.0), math.min(r - l, b - t) / 4);
  for (final (ex, ey, angle) in [
    (r, cy, 0.0),
    (l, cy, math.pi),
    (cx, t, -math.pi / 2),
    (cx, b, math.pi / 2),
  ]) {
    for (final d in [math.pi * 5 / 6, -math.pi * 5 / 6]) {
      axes.add((
        x1: ex,
        y1: ey,
        x2: ex + math.cos(angle + d) * head,
        y2: ey + math.sin(angle + d) * head,
      ));
    }
  }
  return (grid: grid, axes: axes);
}

/// Kare çizgilerinin rengi: şeklin renginin açık tonu (beyazla karışım),
/// saydamlık korunur.
int coordinateGridColor(int argb) {
  int mix(int c) => (c + (255 - c) * 0.72).round().clamp(0, 255);
  final r = mix((argb >> 16) & 0xFF);
  final g = mix((argb >> 8) & 0xFF);
  final b = mix(argb & 0xFF);
  return (argb & 0xFF000000) | (r << 16) | (g << 8) | b;
}

/// Kare çizgilerinin kalınlığı: eksenlerden ince.
double coordinateGridWidth(double width) => math.max(0.5, width * 0.4);
