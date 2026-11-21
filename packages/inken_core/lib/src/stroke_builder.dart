import 'dart:math' as math;

import 'model.dart';

/// Kalem çizgisinin [p] basıncındaki kalınlığı. `p = 0.5` taban kalınlığı
/// verir; ekrandaki çizim ile PDF'e yazılan görünüm aynı formülü kullanır.
double penWidthAt(double baseWidth, double p) =>
    baseWidth * (0.35 + 1.3 * p.clamp(0.0, 1.0));

/// Ham girdi noktalarından bir çizginin noktalarını üretir:
/// çok yakın noktaları eler, titremeyi yumuşatır ve basınç bilgisi
/// yoksa hıza göre basınç taklidi yapar (hızlı çizgi ince, yavaş kalın).
class StrokeBuilder {
  StrokeBuilder({
    this.minDistance = 0.3,
    this.smoothing = 0.6,
    this.simulatePressure = true,
    this.fixedPressure,
  }) : assert(smoothing > 0 && smoothing <= 1);

  /// Sayfa uzayında, bundan yakın ardışık noktalar atlanır.
  final double minDistance;

  /// 1 = yumuşatma yok; küçüldükçe çizgi yumuşar ama kalemin gerisinde kalır.
  final double smoothing;

  /// Cihaz basınç bildirmediğinde hıza göre basınç üret.
  final bool simulatePressure;

  /// Doluysa bütün noktalar bu basıncı alır (fosforlu kalem).
  final double? fixedPressure;

  final List<InkPoint> _points = [];
  double _rawX = 0, _rawY = 0;
  double _lastTime = 0;
  double _pressure = 0.5;

  List<InkPoint> get points => _points;
  bool get isEmpty => _points.isEmpty;

  /// Ham nokta ekler.
  ///
  /// [x], [y] sayfa uzayında; [pressure] cihazdan geliyorsa 0..1, yoksa
  /// `null`; [timeMs] olayın zamanı; [viewScale] sayfa birimi başına ekran
  /// pikseli (hız, yakınlaştırmadan bağımsız ölçülsün diye).
  void add(
    double x,
    double y, {
    double? pressure,
    required double timeMs,
    double viewScale = 1,
  }) {
    if (_points.isEmpty) {
      _pressure = fixedPressure ?? pressure ?? 0.5;
      _points.add(InkPoint(x, y, _pressure));
      _rawX = x;
      _rawY = y;
      _lastTime = timeMs;
      return;
    }
    final last = _points.last;
    final sx = last.x + (x - last.x) * smoothing;
    final sy = last.y + (y - last.y) * smoothing;
    final rawDist = math.sqrt(
      (x - _rawX) * (x - _rawX) + (y - _rawY) * (y - _rawY),
    );
    _rawX = x;
    _rawY = y;
    final dist = math.sqrt(
      (sx - last.x) * (sx - last.x) + (sy - last.y) * (sy - last.y),
    );
    if (dist < minDistance) return;

    final double p;
    if (fixedPressure != null) {
      p = fixedPressure!;
    } else if (pressure != null) {
      // Cihaz basıncını da hafifçe yumuşat: ani sıçramalar boğum yapar.
      p = _pressure + (pressure - _pressure) * 0.6;
    } else if (simulatePressure) {
      final dt = math.max(timeMs - _lastTime, 1.0);
      final speed = rawDist * viewScale / dt; // ekran pikseli / ms
      final target = 0.72 - 0.42 * math.min(speed / 2.0, 1.0);
      p = _pressure + (target - _pressure) * 0.25;
    } else {
      p = 0.5;
    }
    _pressure = p;
    _lastTime = timeMs;
    _points.add(InkPoint(sx, sy, p));
  }

  /// Çizgiyi bitirir: yumuşatma yüzünden geride kalan ucu, kalemin
  /// gerçekten kalktığı noktaya tamamlar.
  List<InkPoint> finish() {
    if (_points.isNotEmpty) {
      final last = _points.last;
      if (last.x != _rawX || last.y != _rawY) {
        _points.add(InkPoint(_rawX, _rawY, _pressure));
      }
    }
    return List.unmodifiable(_points);
  }
}
