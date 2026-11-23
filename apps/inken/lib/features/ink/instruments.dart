import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'ink_session.dart';
import 'tool_state.dart';

/// Açık ölçme araçları (her türden en çok bir tane). Yeni açılan aracın
/// yeri henüz belli değildir (`page == -1`): [InstrumentLayer] onu
/// ekranın ortasına koyar.
class InstrumentsNotifier
    extends Notifier<Map<InstrumentKind, InstrumentPose>> {
  @override
  Map<InstrumentKind, InstrumentPose> build() => const {};

  bool isOpen(InstrumentKind kind) => state.containsKey(kind);

  void toggle(InstrumentKind kind) => isOpen(kind) ? close(kind) : open(kind);

  void open(InstrumentKind kind) => state = {
    ...state,
    kind: InstrumentPose(kind: kind, page: -1, x: 0, y: 0),
  };

  void close(InstrumentKind kind) {
    if (!isOpen(kind)) return;
    state = {...state}..remove(kind);
  }

  void closeAll() {
    if (state.isNotEmpty) state = const {};
  }

  /// Açık aracın yerini değiştirir (kapalıysa bir şey yapmaz).
  void update(InstrumentPose pose) {
    if (!isOpen(pose.kind)) return;
    state = {...state, pose.kind: pose};
  }
}

final instrumentsProvider =
    NotifierProvider<InstrumentsNotifier, Map<InstrumentKind, InstrumentPose>>(
      InstrumentsNotifier.new,
    );

IconData instrumentIcon(InstrumentKind kind) => switch (kind) {
  InstrumentKind.ruler => LucideIcons200.ruler,
  InstrumentKind.setSquare => LucideIcons200.triangleRight,
  InstrumentKind.protractor => LucideIcons200.gauge,
  InstrumentKind.compass => LucideIcons200.draftingCompass,
};

String instrumentLabel(AppLocalizations l10n, InstrumentKind kind) =>
    switch (kind) {
      InstrumentKind.ruler => l10n.instrumentRuler,
      InstrumentKind.setSquare => l10n.instrumentSetSquare,
      InstrumentKind.protractor => l10n.instrumentProtractor,
      InstrumentKind.compass => l10n.instrumentCompass,
    };

/// Araçların kenarına yaslanan araçlar: kalem, fosforlu, geçici kalem.
bool snapsToInstruments(Tool tool) =>
    tool == Tool.pen || tool == Tool.highlighter || tool == Tool.laser;

/// Kalemin kenara yaslanmaya başladığı uzaklık (ekran pikseli, kenarın
/// dışından). Gövdenin içinde bu bant [_innerBand] kadardır.
const double instrumentSnapDistance = 24;

/// Bir çizginin yaslandığı kenar. Noktalar ekran (görüntüleyici)
/// konumundan ekran konumuna yaslanır; çizgi başka bir sayfadaysa da
/// doğru yere düşer.
class InstrumentSnap {
  InstrumentSnap._(this._geometry, this._page, this.edge);

  final PageGeometry _geometry;
  final int _page;
  final InstrumentEdge edge;

  /// [local]'i kenara yaslar; [offsetPx] çizginin ekrandaki yarı kalınlığı
  /// (mürekkep aracın altına girmesin).
  Offset apply(Offset local, double offsetPx) {
    final v = _geometry.viewportOf(_page);
    if (v == null) return local;
    final p = v.toPage(local);
    final q = snapToEdge(edge, p.dx, p.dy, offset: offsetPx / v.scale);
    return v.toView(Offset(q.x, q.y));
  }

  /// [local]'in yakınında ([instrumentSnapDistance]) bir kenar varsa ona
  /// yaslanma; yoksa `null`.
  static InstrumentSnap? find(
    Iterable<InstrumentPose> poses,
    PageGeometry geometry,
    Offset local,
  ) {
    for (final pose in poses) {
      if (pose.page < 0) continue;
      final v = geometry.viewportOf(pose.page);
      if (v == null) continue;
      final p = v.toPage(local);
      final e = nearestInstrumentEdge(
        [pose],
        p.dx,
        p.dy,
        instrumentSnapDistance / v.scale,
      );
      if (e != null) return InstrumentSnap._(geometry, pose.page, e);
    }
    return null;
  }
}

/// Belgenin üstünde ölçme araçları. Görüntüleyiciyle ve çizim katmanıyla
/// aynı kutuyu doldurur; yalnızca araçların gövdesi ve tutamakları
/// dokunuş alır, gerisi alttaki katmanlara geçer.
class InstrumentLayer extends ConsumerStatefulWidget {
  const InstrumentLayer({
    super.key,
    required this.geometry,
    required this.session,
  });

  final PageGeometry geometry;
  final InkSession session;

  @override
  ConsumerState<InstrumentLayer> createState() => _InstrumentLayerState();
}

class _InstrumentLayerState extends ConsumerState<InstrumentLayer> {
  Size _size = Size.zero;
  bool _placing = false;

  /// Yeni açılan araçları ekranın ortasındaki sayfaya yerleştirir.
  void _placeNew() {
    _placing = false;
    if (!mounted || !widget.geometry.isReady) return;
    final notifier = ref.read(instrumentsProvider.notifier);
    final center = _size.center(Offset.zero);
    final view =
        widget.geometry.pageAt(center) ??
        (widget.geometry.visiblePages.isEmpty
            ? null
            : widget.geometry.visiblePages.first);
    if (view == null) return;
    final c = view.toPage(center);
    for (final pose in ref.read(instrumentsProvider).values) {
      if (pose.page >= 0) continue;
      final (x, y) = switch (pose.kind) {
        InstrumentKind.ruler || InstrumentKind.setSquare => (c.dx, c.dy),
        // İletki: yarım dairenin ortası ekranın ortasında.
        InstrumentKind.protractor => (c.dx, c.dy + protractorRadius / 2),
        // Pergel: iğneden tutamağa ortada, iğne solda.
        InstrumentKind.compass => (
          c.dx - pose.radius / 2,
          c.dy - compassKnob(pose.copyWith(x: 0, y: 0, angle: 0)).y / 2,
        ),
      };
      notifier.update(pose.copyWith(page: view.index, x: x, y: y));
    }
  }

  @override
  Widget build(BuildContext context) {
    final poses = ref.watch(instrumentsProvider);
    if (poses.isEmpty) return const SizedBox.shrink();
    final tool = ref.watch(toolProvider.select((t) => t.tool));
    return LayoutBuilder(
      builder: (context, box) {
        _size = box.biggest;
        if (!_placing && poses.values.any((p) => p.page < 0)) {
          _placing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _placeNew());
        }
        return ListenableBuilder(
          listenable: widget.geometry,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              for (final pose in poses.values)
                if (pose.page >= 0 &&
                    pose.page < widget.session.document.pages.length &&
                    widget.geometry.viewportOf(pose.page) != null)
                  _InstrumentView(
                    key: ValueKey(pose.kind),
                    pose: pose,
                    geometry: widget.geometry,
                    session: widget.session,
                    drawingTool: snapsToInstruments(tool),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Aracın dokunulan parçası.
enum _Part { body, rotate, close, needle, pencil, knob }

/// Tutamakların dokunma yarıçapı ve çizim yarıçapı (ekran pikseli).
const double _handleHit = 20;
const double _handleSize = 13;

/// Gövdenin içinde, kalemin kenara yaslandığı bant (ekran pikseli); dar
/// gövdede gövdenin dörtte biri.
double _innerBand(double bodyPx) => math.min(16, bodyPx / 4);

class _InstrumentView extends ConsumerStatefulWidget {
  const _InstrumentView({
    super.key,
    required this.pose,
    required this.geometry,
    required this.session,
    required this.drawingTool,
  });

  final InstrumentPose pose;
  final PageGeometry geometry;
  final InkSession session;

  /// Seçili araç kenara yaslanıyor: gövdenin kenar bandı çizime kalır.
  final bool drawingTool;

  @override
  ConsumerState<_InstrumentView> createState() => _InstrumentViewState();
}

class _InstrumentViewState extends ConsumerState<_InstrumentView> {
  _Part? _active;
  _Part? _hover;

  /// Hareketin başındaki yer ve dokunuş (sayfa uzayı).
  InstrumentPose? _start;
  Offset? _startPoint;

  /// Döndürülürken açı göstergesi.
  bool _showAngle = false;

  /// Pergelle çizilen yayın şimdiye kadarki açısı (açılmış) ve başlangıcı.
  double? _arcAngle;
  double? _arcStart;
  double _arcTime = 0;

  InstrumentPose get pose => widget.pose;

  PageViewport? get _view => widget.geometry.viewportOf(pose.page);

  Offset _screen(PageViewport v, ({double x, double y}) p) =>
      v.toView(Offset(p.x, p.y));

  /// Tutamakların ekrandaki yerleri.
  Map<_Part, Offset> _handles(PageViewport v) {
    final px = 1 / v.scale;
    ({double x, double y}) local(double x, double y) => pose.toPage(x, y);
    switch (pose.kind) {
      case InstrumentKind.ruler:
        const w = rulerLength / 2, h = rulerHeight / 2;
        return {
          _Part.rotate: _screen(v, local(w + 26 * px, 0)),
          _Part.close: _screen(v, local(-w + 20 * px, h - 20 * px)),
        };
      case InstrumentKind.setSquare:
        final c = instrumentLocalOutline(pose.kind);
        // Hipotenüsün ortasının dışında döndürme, dik açının içinde kapat.
        final mx = (c[1].x + c[2].x) / 2, my = (c[1].y + c[2].y) / 2;
        const d = math.sqrt1_2;
        return {
          _Part.rotate: _screen(v, local(mx + d * 26 * px, my - d * 26 * px)),
          _Part.close: _screen(v, local(c[0].x + 22 * px, c[0].y - 22 * px)),
        };
      case InstrumentKind.protractor:
        return {
          _Part.rotate: _screen(v, local(0, -protractorRadius - 26 * px)),
          _Part.close: _screen(v, local(0, -protractorRadius * 0.42)),
        };
      case InstrumentKind.compass:
        final hinge = compassHinge(pose);
        final hl = pose.toLocal(hinge.x, hinge.y);
        return {
          _Part.knob: _screen(v, compassKnob(pose)),
          _Part.pencil: _screen(v, compassPencil(pose)),
          _Part.needle: _screen(v, (x: pose.x, y: pose.y)),
          _Part.close: _screen(v, local(hl.x + 30 * px, hl.y)),
        };
    }
  }

  /// [local]'deki parça; araca dokunmuyorsa `null`.
  _Part? _partAt(Offset local) {
    final v = _view;
    if (v == null) return null;
    for (final MapEntry(:key, :value) in _handles(v).entries) {
      if ((value - local).distance <= _handleHit) return key;
    }
    final p = v.toPage(local);
    if (pose.kind == InstrumentKind.compass) {
      // Bacaklar: tutup taşınır.
      final hinge = _screen(v, compassHinge(pose));
      final needle = _screen(v, (x: pose.x, y: pose.y));
      final pencil = _screen(v, compassPencil(pose));
      for (final (a, b) in [(needle, hinge), (hinge, pencil)]) {
        final d = pointSegmentDistance(
          local.dx,
          local.dy,
          a.dx,
          a.dy,
          b.dx,
          b.dy,
        );
        if (d <= 10) return _Part.body;
      }
      return null;
    }
    if (!instrumentContains(pose, p.dx, p.dy)) return null;
    if (widget.drawingTool) {
      // Kenar bandı kaleme kalır: kenar boyunca çizilir.
      final body = switch (pose.kind) {
        InstrumentKind.ruler => rulerHeight,
        InstrumentKind.setSquare => setSquareLeg / 3,
        _ => protractorRadius / 2,
      };
      final band = _innerBand(body * v.scale) / v.scale;
      if (nearestInstrumentEdge([pose], p.dx, p.dy, band) != null) return null;
    }
    return _Part.body;
  }

  /// Döndürme ekseni (sayfa uzayı): gövdenin ortası / iletkinin merkezi.
  Offset get _pivot => Offset(pose.x, pose.y);

  /// İlk parmağın / farenin dokunduğu yer. Ölçek tanıyıcısı hareketi
  /// kaydırma eşiği aşılınca başlatır; başlangıç olarak dokunulan yer
  /// alınır ki araç parmağın gerisinde kalmasın.
  Offset? _down;
  int _pointers = 0;

  void _onStart(ScaleStartDetails d) {
    final v = _view;
    final at = d.pointerCount == 1
        ? (_down ?? d.localFocalPoint)
        : d.localFocalPoint;
    final part = _partAt(at);
    if (v == null || part == null || part == _Part.close) return;
    _active = part;
    _start = pose;
    _startPoint = v.toPage(at);
    if (part == _Part.knob) _beginArc(v);
    if (part == _Part.rotate) setState(() => _showAngle = true);
  }

  void _onUpdate(ScaleUpdateDetails d) {
    final v = _view;
    final start = _start, from = _startPoint, part = _active;
    if (v == null || start == null || from == null || part == null) return;
    final p = v.toPage(d.localFocalPoint);
    final notifier = ref.read(instrumentsProvider.notifier);
    switch (part) {
      case _Part.body || _Part.needle:
        // Bir parmak / fare: taşı. İki parmak: dokunulan yer parmakların
        // altında kalacak şekilde döndür ve taşı.
        final turn = d.pointerCount >= 2 ? d.rotation : 0.0;
        final angle = turn == 0
            ? start.angle
            : snapInstrumentAngle(start.angle + turn);
        final da = angle - start.angle;
        final rel = Offset(start.x, start.y) - from;
        final c = math.cos(da), s = math.sin(da);
        final rotated = Offset(
          rel.dx * c - rel.dy * s,
          rel.dx * s + rel.dy * c,
        );
        notifier.update(
          start.copyWith(
            x: p.dx + rotated.dx,
            y: p.dy + rotated.dy,
            angle: angle,
          ),
        );
        if (turn != 0 && !_showAngle) setState(() => _showAngle = true);
      case _Part.rotate:
        final a0 = (from - _pivot).direction;
        final a1 = (p - _pivot).direction;
        notifier.update(
          start.copyWith(angle: snapInstrumentAngle(start.angle + a1 - a0)),
        );
      case _Part.pencil:
        final rel = p - _pivot;
        notifier.update(
          start.copyWith(
            radius: compassRadiusFor(rel.distance),
            angle: snapInstrumentAngle(rel.direction),
          ),
        );
      case _Part.knob:
        _continueArc(v, p, d);
      case _Part.close:
        break;
    }
  }

  void _onEnd(ScaleEndDetails d) {
    final part = _active;
    _active = null;
    _start = null;
    _startPoint = null;
    if (part == _Part.knob) _endArc();
    if (_showAngle) setState(() => _showAngle = false);
    if (part == _Part.body || part == _Part.needle) _reanchor();
  }

  /// Araç başka bir sayfanın üzerine taşındıysa o sayfaya bağlanır
  /// (kaydırınca onunla gitsin).
  void _reanchor() {
    final v = _view;
    if (v == null) return;
    final at = v.toView(_pivot);
    final over = widget.geometry.pageAt(at);
    if (over == null || over.index == pose.page) return;
    final q = over.toPage(at);
    ref
        .read(instrumentsProvider.notifier)
        .update(pose.copyWith(page: over.index, x: q.dx, y: q.dy));
  }

  // ---- pergel

  void _beginArc(PageViewport v) {
    final tools = ref.read(toolProvider);
    final pencil = compassPencil(pose);
    _arcStart = pose.angle;
    _arcAngle = pose.angle;
    _arcTime = 0;
    widget.session.beginStroke(
      page: pose.page,
      tool: InkTool.pen,
      color: tools.strokeColorFor(Tool.pen),
      width: tools.strokeWidthFor(Tool.pen),
      minDistance: 0.5 / v.scale,
      exact: true,
    );
    _addArcPoint(pencil.x, pencil.y, v);
  }

  void _addArcPoint(double x, double y, PageViewport v) {
    _arcTime += 8;
    widget.session.addPoint(x, y, timeMs: _arcTime, viewScale: v.scale);
  }

  void _continueArc(PageViewport v, Offset p, ScaleUpdateDetails d) {
    final prev = _arcAngle, start = _arcStart;
    if (prev == null || start == null) return;
    // Tutamak iğnenin çevresinde dönüyor: açısı tutamağın açısı; pergel
    // tutamağın yerel açısı kadar geride.
    final knob = compassKnob(pose);
    final knobOffset =
        math.atan2(knob.y - pose.y, knob.x - pose.x) - pose.angle;
    var next = unwrapAngle(prev, (p - _pivot).direction - knobOffset);
    // En fazla tam tur.
    next = next.clamp(start - 2 * math.pi, start + 2 * math.pi);
    if (next == prev) return;
    final pts = arcPoints(pose.x, pose.y, pose.radius, prev, next);
    for (final q in pts.skip(1)) {
      _addArcPoint(q.x, q.y, v);
    }
    _arcAngle = next;
    ref.read(instrumentsProvider.notifier).update(pose.copyWith(angle: next));
  }

  void _endArc() {
    final moved = _arcAngle != null && _arcAngle != _arcStart;
    _arcAngle = null;
    _arcStart = null;
    if (moved) {
      widget.session.endStroke();
    } else {
      widget.session.cancelStroke();
    }
  }

  void _lift() {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers == 0) _down = null;
  }

  @override
  void dispose() {
    if (_arcAngle != null) widget.session.cancelStroke();
    super.dispose();
  }

  MouseCursor get _cursor => switch (_active ?? _hover) {
    _Part.body || _Part.needle => SystemMouseCursors.move,
    _Part.rotate || _Part.knob || _Part.pencil =>
      _active == null ? SystemMouseCursors.grab : SystemMouseCursors.grabbing,
    _Part.close => SystemMouseCursors.click,
    null => MouseCursor.defer,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = instrumentLabel(l10n, pose.kind);
    final cm = NumberFormat('0.0', locale).format(pose.radius / ptPerCm);
    final degrees = NumberFormat(
      '0.#',
      locale,
    ).format(displayDegrees(pose.angle));
    final penColor = ref.watch(
      toolProvider.select((t) => t.strokeColorFor(Tool.pen)),
    );
    return Semantics(
      label: name,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapUp: (d) {
          if (_partAt(d.localPosition) == _Part.close) {
            ref.read(instrumentsProvider.notifier).close(pose.kind);
          }
        },
        onScaleStart: _onStart,
        onScaleUpdate: _onUpdate,
        onScaleEnd: _onEnd,
        child: Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: (e) {
            if (_pointers++ == 0) _down = e.localPosition;
          },
          onPointerUp: (_) => _lift(),
          onPointerCancel: (_) => _lift(),
          child: MouseRegion(
            hitTestBehavior: HitTestBehavior.deferToChild,
            cursor: _cursor,
            onHover: (e) {
              final part = _partAt(e.localPosition);
              if (part != _hover) setState(() => _hover = part);
            },
            onExit: (_) {
              if (_hover != null) setState(() => _hover = null);
            },
            child: CustomPaint(
              key: ValueKey('instrument-${pose.kind.name}'),
              painter: _InstrumentPainter(
                pose: pose,
                geometry: widget.geometry,
                handles: _view == null ? const {} : _handles(_view!),
                hitTest: (p) => _partAt(p) != null,
                showAngle: _showAngle,
                angleLabel: '$degrees°',
                radiusLabel: l10n.instrumentCentimeters(cm),
                penColor: Color(penColor),
                closeLabel: l10n.instrumentClose(name),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstrumentPainter extends CustomPainter {
  _InstrumentPainter({
    required this.pose,
    required this.geometry,
    required this.handles,
    required bool Function(Offset) hitTest,
    required this.showAngle,
    required this.angleLabel,
    required this.radiusLabel,
    required this.penColor,
    required this.closeLabel,
  }) : _hit = hitTest;

  final InstrumentPose pose;
  final PageGeometry geometry;
  final Map<_Part, Offset> handles;
  final bool Function(Offset) _hit;
  final bool showAngle;
  final String angleLabel;
  final String radiusLabel;
  final Color penColor;
  final String closeLabel;

  static const _body = Color(instrumentBody);
  static const _edge = Color(instrumentEdge);
  static const _ink = Color(instrumentInk);
  static const _accent = Color(instrumentHandle);
  static const _halo = Color(instrumentHalo);

  @override
  bool? hitTest(Offset position) => _hit(position);

  @override
  void paint(Canvas canvas, Size size) {
    final v = geometry.viewportOf(pose.page);
    if (v == null) return;
    final o = v.toView(Offset(pose.x, pose.y));
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(pose.angle);
    canvas.scale(v.scale);
    final px = 1 / v.scale;
    switch (pose.kind) {
      case InstrumentKind.ruler:
        _ruler(canvas, px);
      case InstrumentKind.setSquare:
        _setSquare(canvas, px);
      case InstrumentKind.protractor:
        _protractor(canvas, px);
      case InstrumentKind.compass:
        _compass(canvas, px);
    }
    canvas.restore();
    // Tutamaklar ekran boyutunda (yakınlaştırmadan bağımsız).
    for (final MapEntry(:key, :value) in handles.entries) {
      switch (key) {
        case _Part.rotate:
          _handle(canvas, value, LucideIcons200.rotateCw);
        case _Part.close:
          _handle(canvas, value, LucideIcons200.x, small: true);
        case _Part.knob:
          _handle(canvas, value, LucideIcons200.rotateCw);
        case _Part.pencil:
          canvas.drawCircle(value, 7, Paint()..color = _halo);
          canvas.drawCircle(value, 5, Paint()..color = penColor);
        case _Part.needle:
          canvas.drawCircle(value, 5, Paint()..color = _halo);
          canvas.drawCircle(value, 3, Paint()..color = _ink);
        case _Part.body:
          break;
      }
    }
    if (pose.kind == InstrumentKind.compass) {
      // Açıklık: iğne ile kalem ucunun ortasının altında.
      final mid = v.toView(
        Offset(
          (pose.x + compassPencil(pose).x) / 2,
          (pose.y + compassPencil(pose).y) / 2,
        ),
      );
      _badge(canvas, mid + const Offset(0, 22), radiusLabel);
    }
    if (showAngle) _badge(canvas, o - const Offset(0, 34), angleLabel);
  }

  // ---- parçalar (yerel uzayda, pt; [px] bir ekran pikseli)

  Paint _fill() => Paint()..color = _body;
  Paint _line(double px, [double w = 1]) => Paint()
    ..color = _edge
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * px;

  void _body_(Canvas canvas, Path path, double px) {
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _line(px, 1.2));
  }

  void _ruler(Canvas canvas, double px) {
    const w = rulerLength / 2, h = rulerHeight / 2;
    _body_(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-w, -h, w, h),
          Radius.circular(3 * px),
        ),
      ),
      px,
    );
    const mm = ptPerCm / 10;
    const x0 = -rulerScaleCm * ptPerCm / 2;
    final tick = _line(px);
    final showMm = mm / px >= 3;
    for (var i = 0; i <= rulerScaleCm * 10; i++) {
      final len = i % 10 == 0
          ? 0.55 * ptPerCm
          : i % 5 == 0
          ? 0.38 * ptPerCm
          : 0.22 * ptPerCm;
      if (i % 5 != 0 && !showMm) continue;
      final x = x0 + i * mm;
      canvas.drawLine(Offset(x, -h), Offset(x, -h + len), tick);
      if (i % 10 == 0) {
        _text(canvas, '${i ~/ 10}', Offset(x, -h + 0.62 * ptPerCm), 8.5);
      }
    }
    _text(canvas, 'cm', Offset(x0 + 0.55 * ptPerCm, -h + 1.15 * ptPerCm), 6);
  }

  void _setSquare(Canvas canvas, double px) {
    final c = instrumentLocalOutline(pose.kind);
    final path = Path()
      ..moveTo(c[0].x, c[0].y)
      ..lineTo(c[1].x, c[1].y)
      ..lineTo(c[2].x, c[2].y)
      ..close();
    _body_(canvas, path, px);
    // İçteki boşluk (gerçek gönyedeki gibi) ve iki dik kenarda cm ölçeği.
    const inset = 2.2 * ptPerCm;
    final inner = Path()
      ..moveTo(c[0].x + inset, c[0].y - inset)
      ..lineTo(c[1].x - inset * 2.414, c[1].y - inset)
      ..lineTo(c[2].x + inset, c[2].y + inset * 2.414)
      ..close();
    canvas.drawPath(inner, _line(px, 0.8));
    const mm = ptPerCm / 10;
    final tick = _line(px);
    final showMm = mm / px >= 3;
    const cms = 10;
    for (var i = 0; i <= cms * 10; i++) {
      if (i % 5 != 0 && !showMm) continue;
      final len = i % 10 == 0
          ? 0.5 * ptPerCm
          : i % 5 == 0
          ? 0.35 * ptPerCm
          : 0.2 * ptPerCm;
      final d = 0.5 * ptPerCm + i * mm;
      // Yatay kenar (alt): yukarı doğru çizgiler.
      canvas.drawLine(
        Offset(c[0].x + d, c[0].y),
        Offset(c[0].x + d, c[0].y - len),
        tick,
      );
      // Dikey kenar (sol): sağa doğru çizgiler.
      canvas.drawLine(
        Offset(c[0].x, c[0].y - d),
        Offset(c[0].x + len, c[0].y - d),
        tick,
      );
      if (i % 10 == 0 && i > 0) {
        _text(
          canvas,
          '${i ~/ 10}',
          Offset(c[0].x + d, c[0].y - 0.8 * ptPerCm),
          7.5,
        );
        _text(
          canvas,
          '${i ~/ 10}',
          Offset(c[0].x + 0.8 * ptPerCm, c[0].y - d),
          7.5,
        );
      }
    }
  }

  void _protractor(Canvas canvas, double px) {
    const r = protractorRadius;
    final path = Path()
      ..moveTo(-r, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: r),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    _body_(canvas, path, px);
    final tick = _line(px);
    // 1°'lik çizgiler yeterince seyrekse.
    final showOne = r * math.pi / 180 / px >= 3;
    for (var deg = 0; deg <= 180; deg++) {
      if (deg % 5 != 0 && !showOne) continue;
      final len = deg % 10 == 0
          ? 0.6 * ptPerCm
          : deg % 5 == 0
          ? 0.4 * ptPerCm
          : 0.22 * ptPerCm;
      // Yerelde açı: 0° sağda, saat yönünün tersine (y aşağı: −).
      final a = -deg * math.pi / 180;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(dir * r, dir * (r - len), tick);
      if (deg % 10 == 0) {
        // Dış ölçek soldan sağa artar (0 sağda), iç ölçek ters.
        _text(
          canvas,
          '$deg',
          dir * (r - 0.95 * ptPerCm),
          7,
          rotate: a + math.pi / 2,
        );
        _text(
          canvas,
          '${180 - deg}',
          dir * (r - 1.55 * ptPerCm),
          6,
          rotate: a + math.pi / 2,
          muted: true,
        );
      }
    }
    // Merkez: taban üzerinde artı.
    final center = _line(px, 1.2);
    canvas.drawLine(Offset(0, -0.5 * ptPerCm), Offset.zero, center);
    canvas.drawLine(
      Offset(-0.4 * ptPerCm, 0),
      Offset(0.4 * ptPerCm, 0),
      center,
    );
    canvas.drawCircle(Offset.zero, 2.5 * px, Paint()..color = _ink);
    // 90° çizgisi soluk.
    canvas.drawLine(
      Offset(0, -0.5 * ptPerCm),
      Offset(0, -(r - 1.9 * ptPerCm)),
      _line(px, 0.6),
    );
  }

  void _compass(Canvas canvas, double px) {
    final r = pose.radius;
    final hinge = pose.toLocal(compassHinge(pose).x, compassHinge(pose).y);
    final knob = pose.toLocal(compassKnob(pose).x, compassKnob(pose).y);
    final h = Offset(hinge.x, hinge.y);
    // Yarıçap: soluk kesikli değil, ince çizgi.
    canvas.drawLine(
      Offset.zero,
      Offset(r, 0),
      _line(px, 0.8)..color = _edge.withValues(alpha: 0.45),
    );
    final leg = Paint()
      ..color = _edge
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5 * px;
    final halo = Paint()
      ..color = _halo
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8 * px;
    for (final p in [halo, leg]) {
      canvas.drawLine(Offset.zero, h, p);
      canvas.drawLine(h, Offset(r, 0), p);
      canvas.drawLine(h, Offset(knob.x, knob.y), p);
    }
    canvas.drawCircle(h, 5 * px, Paint()..color = _accent);
  }

  // ---- yardımcılar

  static final Map<String, TextPainter> _labels = {};

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    double size, {
    double rotate = 0,
    bool muted = false,
  }) {
    final tp = _labels.putIfAbsent('$s|$size|$muted', () {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: InkenText.label.copyWith(
            fontSize: size,
            height: 1,
            color: muted ? _ink.withValues(alpha: 0.6) : _ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotate != 0) canvas.rotate(rotate);
    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  void _handle(Canvas canvas, Offset c, IconData icon, {bool small = false}) {
    final r = small ? _handleSize - 2 : _handleSize;
    canvas.drawCircle(c, r + 1.5, Paint()..color = _halo);
    canvas.drawCircle(c, r, Paint()..color = small ? _halo : _accent);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: r * 1.3,
          height: 1,
          color: small ? _ink : _halo,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  void _badge(Canvas canvas, Offset c, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: InkenText.label.copyWith(color: _halo, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: c,
      width: tp.width + Space.s3,
      height: tp.height + Space.s2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(Radii.sm)),
      Paint()..color = _ink.withValues(alpha: 0.85),
    );
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_InstrumentPainter old) => true;
}
