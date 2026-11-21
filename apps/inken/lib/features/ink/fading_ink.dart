import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'ink_painter.dart';
import 'tool_state.dart';

/// Geçici kalemin çizgileri: bittikten [laserHold] sonra [laserFade]
/// boyunca solar ve silinir. Modele, geri al geçmişine ve dosyaya girmez.
class FadingInk extends ChangeNotifier {
  FadingInk(TickerProvider vsync) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  final List<({int page, Stroke stroke, Duration end})> _done = [];
  StrokeBuilder? _builder;
  int? _page;
  int _color = laserColors.first;

  /// Saat: ticker'ın başladığı andan beri geçen süre (testte de işler).
  final Stopwatch _clock = Stopwatch()..start();

  bool get isEmpty => _done.isEmpty && _builder == null;

  void begin(int page, {required double minDistance, required int color}) {
    _page = page;
    _color = color;
    _builder = StrokeBuilder(minDistance: minDistance, fixedPressure: 0.5);
  }

  void add(double x, double y, double timeMs, double viewScale) {
    final b = _builder;
    if (b == null) return;
    b.add(x, y, timeMs: timeMs, viewScale: viewScale);
    notifyListeners();
  }

  void end() {
    final b = _builder;
    final page = _page;
    _builder = null;
    if (b == null || page == null || b.isEmpty) return;
    _done.add((
      page: page,
      stroke: _stroke(b.finish(), _color),
      end: _clock.elapsed,
    ));
    if (!_ticker.isActive) _ticker.start();
    notifyListeners();
  }

  static Stroke _stroke(List<InkPoint> points, int color) => Stroke(
    id: '',
    tool: InkTool.pen,
    color: color,
    width: laserWidth,
    points: points,
  );

  void _tick(Duration _) {
    final now = _clock.elapsed;
    _done.removeWhere((s) => now - s.end >= laserHold + laserFade);
    if (_done.isEmpty) _ticker.stop();
    notifyListeners();
  }

  /// [page] sayfasındaki çizgiler ve opaklıkları (0..1).
  Iterable<({Stroke stroke, double opacity})> on(int page) sync* {
    final now = _clock.elapsed;
    for (final s in _done) {
      if (s.page != page) continue;
      final age = now - s.end;
      final t = age <= laserHold
          ? 1.0
          : 1 - (age - laserHold).inMicroseconds / laserFade.inMicroseconds;
      if (t > 0) yield (stroke: s.stroke, opacity: t.clamp(0.0, 1.0));
    }
    final b = _builder;
    if (b != null && !b.isEmpty && _page == page) {
      yield (stroke: _stroke(b.points, _color), opacity: 1);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class FadingInkPainter extends CustomPainter {
  FadingInkPainter({required this.geometry, required this.ink})
    : super(repaint: Listenable.merge([geometry, ink]));

  final PageGeometry geometry;
  final FadingInk ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (!geometry.isReady || ink.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    for (final view in geometry.visiblePages) {
      final strokes = ink.on(view.index).toList();
      if (strokes.isEmpty) continue;
      canvas.save();
      canvas.clipRect(view.rect);
      canvas.translate(view.rect.left, view.rect.top);
      canvas.scale(view.scale);
      for (final s in strokes) {
        if (s.opacity >= 1) {
          paintItem(canvas, s.stroke);
        } else {
          canvas.saveLayer(
            null,
            Paint()..color = Color.fromRGBO(0, 0, 0, s.opacity),
          );
          paintItem(canvas, s.stroke);
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FadingInkPainter old) =>
      old.geometry != geometry || old.ink != ink;
}
