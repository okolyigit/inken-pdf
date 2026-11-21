import 'dart:math' as math;

import 'coordinate_plane.dart';

/// Ölçme araçları: sayfanın üstünde duran, taşınıp döndürülen cetvel,
/// gönye, iletki ve pergel. Modele / dosyaya girmezler; yalnızca onlarla
/// çizilenler kaydedilir.
///
/// Her aracın kendi yerel uzayı vardır (pt, y aşağı); [InstrumentPose]
/// yerel uzayı sayfa uzayına taşır: önce [InstrumentPose.angle] kadar
/// döndürür, sonra ([InstrumentPose.x], [InstrumentPose.y])'ye öteler.
/// Ölçüler gerçek boyuttadır: cetvelin 1 cm'si sayfada 1 cm'dir.
enum InstrumentKind { ruler, setSquare, protractor, compass }

/// Cetvelin ölçeği (cm) ve gövdesi.
const double rulerScaleCm = 15;
const double rulerLength = (rulerScaleCm + 1) * ptPerCm;
const double rulerHeight = 2.6 * ptPerCm;

/// Gönye: dik kenarları eşit (45°) dik üçgen.
const double setSquareLeg = 12 * ptPerCm;

/// İletki: yarım daire.
const double protractorRadius = 7 * ptPerCm;

/// Pergelin bacak boyu ve açılabildiği aralık.
const double compassLegLength = 7 * ptPerCm;
const double compassMinRadius = 0.5 * ptPerCm;
const double compassMaxRadius = 13 * ptPerCm;
const double compassDefaultRadius = 4 * ptPerCm;

/// Aracın sayfadaki yeri.
class InstrumentPose {
  const InstrumentPose({
    required this.kind,
    required this.page,
    required this.x,
    required this.y,
    this.angle = 0,
    this.radius = compassDefaultRadius,
  });

  final InstrumentKind kind;

  /// Bağlı olduğu sayfa; konum bu sayfanın uzayında (sayfanın dışına
  /// taşabilir).
  final int page;

  /// Yerel orijinin sayfadaki yeri: cetvel ve gönyede gövdenin ortası,
  /// iletkide merkez, pergelde iğnenin ucu.
  final double x, y;

  /// Radyan, saat yönünde (y aşağı).
  final double angle;

  /// Pergelin açıklığı (iğne ile kalem ucu arası, pt). Diğerlerinde
  /// kullanılmaz.
  final double radius;

  InstrumentPose copyWith({
    int? page,
    double? x,
    double? y,
    double? angle,
    double? radius,
  }) => InstrumentPose(
    kind: kind,
    page: page ?? this.page,
    x: x ?? this.x,
    y: y ?? this.y,
    angle: angle ?? this.angle,
    radius: radius ?? this.radius,
  );

  /// Yerel noktayı sayfa uzayına çevirir.
  ({double x, double y}) toPage(double lx, double ly) {
    final c = math.cos(angle), s = math.sin(angle);
    return (x: x + lx * c - ly * s, y: y + lx * s + ly * c);
  }

  /// Sayfa noktasını yerel uzaya çevirir.
  ({double x, double y}) toLocal(double px, double py) {
    final c = math.cos(angle), s = math.sin(angle);
    final dx = px - x, dy = py - y;
    return (x: dx * c + dy * s, y: -dx * s + dy * c);
  }

  /// Yerel yönü sayfa uzayına döndürür (öteleme yok).
  ({double x, double y}) rotate(double lx, double ly) {
    final c = math.cos(angle), s = math.sin(angle);
    return (x: lx * c - ly * s, y: lx * s + ly * c);
  }

  @override
  bool operator ==(Object other) =>
      other is InstrumentPose &&
      other.kind == kind &&
      other.page == page &&
      other.x == x &&
      other.y == y &&
      other.angle == angle &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(kind, page, x, y, angle, radius);

  @override
  String toString() =>
      'InstrumentPose($kind, page $page, $x, $y, '
      '${(angle * 180 / math.pi).toStringAsFixed(1)}°, r $radius)';
}

// ------------------------------------------------------------- gövde

/// Gönyenin köşeleri, yerelde (ağırlık merkezi orijinde): dik açı, yatay
/// kenarın ucu, dikey kenarın ucu.
const List<({double x, double y})> _setSquareCorners = [
  (x: -setSquareLeg / 3, y: setSquareLeg / 3),
  (x: setSquareLeg * 2 / 3, y: setSquareLeg / 3),
  (x: -setSquareLeg / 3, y: -setSquareLeg * 2 / 3),
];

/// Gövdenin dış hattı, yerel uzayda (kapalı çokgen; ilk nokta tekrarlanmaz).
/// Pergelin gövdesi yoktur (boş liste).
List<({double x, double y})> instrumentLocalOutline(InstrumentKind kind) {
  switch (kind) {
    case InstrumentKind.ruler:
      const w = rulerLength / 2, h = rulerHeight / 2;
      return const [(x: -w, y: -h), (x: w, y: -h), (x: w, y: h), (x: -w, y: h)];
    case InstrumentKind.setSquare:
      return _setSquareCorners;
    case InstrumentKind.protractor:
      const n = 64;
      return [
        for (var i = 0; i <= n; i++)
          (
            x: protractorRadius * math.cos(math.pi + math.pi * i / n),
            y: protractorRadius * math.sin(math.pi + math.pi * i / n),
          ),
      ];
    case InstrumentKind.compass:
      return const [];
  }
}

/// Gövdenin dış hattı, sayfa uzayında.
List<({double x, double y})> instrumentOutline(InstrumentPose pose) => [
  for (final p in instrumentLocalOutline(pose.kind)) pose.toPage(p.x, p.y),
];

/// (px, py) gövdenin içinde mi (sayfa uzayı)? Pergelde hep `false`.
bool instrumentContains(InstrumentPose pose, double px, double py) {
  final pts = instrumentLocalOutline(pose.kind);
  if (pts.length < 3) return false;
  final l = pose.toLocal(px, py);
  var inside = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final a = pts[i], b = pts[j];
    if ((a.y > l.y) != (b.y > l.y) &&
        l.x < (b.x - a.x) * (l.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

// ------------------------------------------------------------- kenarlar

/// Kalemin yaslanabildiği kenar (sayfa uzayı).
sealed class InstrumentEdge {
  const InstrumentEdge();
}

/// Düz kenar: a–b, dışa bakan birim normal (nx, ny).
final class LineEdge extends InstrumentEdge {
  const LineEdge(this.ax, this.ay, this.bx, this.by, this.nx, this.ny);
  final double ax, ay, bx, by, nx, ny;

  @override
  String toString() => 'LineEdge($ax, $ay → $bx, $by)';
}

/// Yay: merkez, yarıçap; [from] açısından [sweep] kadar (radyan, saat
/// yönünde pozitif). Dış yön merkezden uzağa.
final class ArcEdge extends InstrumentEdge {
  const ArcEdge(this.cx, this.cy, this.r, this.from, this.sweep);
  final double cx, cy, r, from, sweep;

  @override
  String toString() => 'ArcEdge($cx, $cy, r $r)';
}

/// Aracın yaslanılabilen kenarları: cetvelin iki uzun kenarı, gönyenin üç
/// kenarı, iletkinin tabanı ve yayı. Pergelin kenarı yoktur.
List<InstrumentEdge> instrumentEdges(InstrumentPose pose) {
  LineEdge line(double ax, double ay, double bx, double by) {
    final a = pose.toPage(ax, ay), b = pose.toPage(bx, by);
    // Yerel uzayda gövde orijin tarafında: normal orijinden uzağa bakar.
    var nx = -(by - ay), ny = bx - ax;
    final len = math.sqrt(nx * nx + ny * ny);
    nx /= len;
    ny /= len;
    final mx = (ax + bx) / 2, my = (ay + by) / 2;
    if (nx * mx + ny * my < 0) {
      nx = -nx;
      ny = -ny;
    }
    final n = pose.rotate(nx, ny);
    return LineEdge(a.x, a.y, b.x, b.y, n.x, n.y);
  }

  switch (pose.kind) {
    case InstrumentKind.ruler:
      const w = rulerLength / 2, h = rulerHeight / 2;
      return [line(-w, -h, w, -h), line(-w, h, w, h)];
    case InstrumentKind.setSquare:
      final c = _setSquareCorners;
      return [
        line(c[0].x, c[0].y, c[1].x, c[1].y),
        line(c[0].x, c[0].y, c[2].x, c[2].y),
        line(c[1].x, c[1].y, c[2].x, c[2].y),
      ];
    case InstrumentKind.protractor:
      const r = protractorRadius;
      return [
        line(-r, 0, r, 0),
        ArcEdge(pose.x, pose.y, r, math.pi + pose.angle, math.pi),
      ];
    case InstrumentKind.compass:
      return const [];
  }
}

/// (px, py)'nin [edge]'e uzaklığı ve kenar üzerindeki en yakın nokta.
/// Nokta kenarın uçlarının ötesindeyse uzaklık uca göredir.
({double distance, double x, double y}) _nearestOn(
  InstrumentEdge edge,
  double px,
  double py,
) {
  switch (edge) {
    case LineEdge(:final ax, :final ay, :final bx, :final by):
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0
          ? 0.0
          : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      return (distance: _dist(px, py, x, y), x: x, y: y);
    case ArcEdge(:final cx, :final cy, :final r, :final from, :final sweep):
      final a = _clampAngle(math.atan2(py - cy, px - cx), from, sweep);
      final x = cx + r * math.cos(a), y = cy + r * math.sin(a);
      return (distance: _dist(px, py, x, y), x: x, y: y);
  }
}

double _dist(double ax, double ay, double bx, double by) =>
    math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

/// [a]'yı [from]'dan başlayan [sweep] aralığına sıkıştırır (dışındaysa
/// yakın uca).
double _clampAngle(double a, double from, double sweep) {
  var d = (a - from) % (2 * math.pi);
  if (d < 0) d += 2 * math.pi;
  if (d <= sweep) return from + d;
  // Aralığın dışında: hangi uca daha yakın?
  final past = d - sweep, before = 2 * math.pi - d;
  return past < before ? from + sweep : from;
}

/// (px, py)'ye [tolerance] içinde en yakın kenar; yoksa `null`.
InstrumentEdge? nearestInstrumentEdge(
  List<InstrumentPose> poses,
  double px,
  double py,
  double tolerance,
) {
  InstrumentEdge? best;
  var bestD = tolerance;
  for (final pose in poses) {
    for (final e in instrumentEdges(pose)) {
      final d = _nearestOn(e, px, py).distance;
      if (d <= bestD) {
        best = e;
        bestD = d;
      }
    }
  }
  return best;
}

/// (px, py)'yi kenara yaslar: kenar üzerindeki en yakın nokta, dışa doğru
/// [offset] kadar kaydırılmış (çizginin yarı kalınlığı: mürekkep kenarın
/// dışında kalır, aracın altına girmez).
({double x, double y}) snapToEdge(
  InstrumentEdge edge,
  double px,
  double py, {
  double offset = 0,
}) {
  final n = _nearestOn(edge, px, py);
  switch (edge) {
    case LineEdge(:final nx, :final ny):
      return (x: n.x + nx * offset, y: n.y + ny * offset);
    case ArcEdge(:final cx, :final cy, :final r):
      final k = (r + offset) / r;
      return (x: cx + (n.x - cx) * k, y: cy + (n.y - cy) * k);
  }
}

// ------------------------------------------------------------- döndürme

/// Döndürürken açı 15°'nin katlarına [toleranceDegrees] kadar yakınsa
/// oraya oturur (yatay, dikey, 30°, 45°…).
double snapInstrumentAngle(double angle, {double toleranceDegrees = 2}) {
  const step = math.pi / 12;
  final snapped = (angle / step).roundToDouble() * step;
  return (angle - snapped).abs() <= toleranceDegrees * math.pi / 180
      ? snapped
      : angle;
}

/// Açıyı [0, 360) dereceye çevirir, onda bire yuvarlar (gösterge için;
/// saat yönünün tersi pozitif: matematikteki gibi). 359,96 → 0.
double displayDegrees(double angle) {
  final d = (-angle * 180 / math.pi * 10).roundToDouble() / 10 % 360;
  return d < 0 ? d + 360 : d;
}

// ------------------------------------------------------------- pergel

/// Pergelin kalem ucu (sayfa uzayı).
({double x, double y}) compassPencil(InstrumentPose pose) =>
    pose.toPage(pose.radius, 0);

/// Pergelin menteşesi: iki bacağın birleştiği yer (yerelde iğne–kalem
/// doğrusunun üstünde).
({double x, double y}) compassHinge(InstrumentPose pose) =>
    pose.toPage(pose.radius / 2, -_hingeHeight(pose.radius));

/// Pergelin tutamağı: menteşenin üstü; çevrilince yay çizilir.
({double x, double y}) compassKnob(InstrumentPose pose) =>
    pose.toPage(pose.radius / 2, -_hingeHeight(pose.radius) - ptPerCm);

double _hingeHeight(double radius) {
  final half = radius / 2;
  return math.sqrt(
    math.max(compassLegLength * compassLegLength - half * half, 0),
  );
}

/// Kalem ucunun [distance] uzaklığa çekildiği açıklık: aralığa sıkıştırılır,
/// milimetreye yuvarlanır.
double compassRadiusFor(double distance) {
  const mm = ptPerCm / 10;
  final r = (distance / mm).roundToDouble() * mm;
  return r.clamp(compassMinRadius, compassMaxRadius);
}

/// [next] açısını [previous]'a en yakın eşdeğerine çevirir (−π/π
/// sıçramasında yay ters dönmesin).
double unwrapAngle(double previous, double next) {
  var a = next;
  while (a - previous > math.pi) {
    a -= 2 * math.pi;
  }
  while (a - previous < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}

/// Yayın noktaları: merkez (cx, cy), yarıçap [r], [from]'dan [to]'ya
/// (radyan; [to] < [from] olabilir). Ardışık noktalar arası en fazla
/// [maxChord] pt; iki uç her zaman dahil.
List<({double x, double y})> arcPoints(
  double cx,
  double cy,
  double r,
  double from,
  double to, {
  double maxChord = 2,
}) {
  final sweep = to - from;
  final n = math.max(1, (sweep.abs() * r / maxChord).ceil());
  return [
    for (var i = 0; i <= n; i++)
      (
        x: cx + r * math.cos(from + sweep * i / n),
        y: cy + r * math.sin(from + sweep * i / n),
      ),
  ];
}
