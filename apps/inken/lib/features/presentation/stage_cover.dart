import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Belgenin üstündeki sunum örtüsü: spot ışığı ya da perde. Aynı anda
/// biri açık olur.
///
/// Örtü ekran uzayındadır (belge alanı), sayfaya bağlı değildir: kaydırınca
/// yerinde kalır, alttan geçen sayfa görünür. Açık kalan yerde (ışığın içi,
/// perdenin üstü) çizim ve kaydırma olağan çalışır; örtülü yeri sürüklemek
/// örtüyü oynatır. Yüzen kutular örtünün üstündedir.
enum StageCover { none, spotlight, curtain }

/// Spot ışığının en küçük yarıçapı (mantıksal piksel).
const double minSpotRadius = 40;

/// Perde en çok bu kadar açılır: alt kenarda tutamak çubuğu görünür kalır,
/// perde geri çekilebilsin.
const double curtainBarHeight = 56;

/// Örtünün konumu belge alanına göre oransaldır: pencere büyüyüp küçülünce
/// yerinde kalır.
@immutable
class StageCoverState {
  const StageCoverState({
    this.mode = StageCover.none,
    this.spotCenter = const Offset(0.5, 0.4),
    this.spotRadius = 0.22,
    this.curtainTop = 0,
  });

  final StageCover mode;

  /// Işığın merkezi, alanın genişlik / yüksekliğine oranla (0–1).
  final Offset spotCenter;

  /// Işığın yarıçapı, alanın kısa kenarına oranla.
  final double spotRadius;

  /// Perdenin üst kenarı, alanın yüksekliğine oranla: 0 tamamen örtülü.
  final double curtainTop;

  Offset spotCenterIn(Size size) =>
      Offset(spotCenter.dx * size.width, spotCenter.dy * size.height);

  double spotRadiusIn(Size size) =>
      math.max(minSpotRadius, spotRadius * size.shortestSide);

  /// Perdenin üst kenarı (piksel); tutamak çubuğu hep alanın içinde.
  double curtainTopIn(Size size) =>
      (curtainTop * size.height).clamp(0, _curtainMax(size));

  /// Işığı [delta] piksel kaydırır; merkez alanın dışına çıkmaz.
  StageCoverState movedSpot(Offset delta, Size size) {
    if (size.isEmpty) return this;
    final c = spotCenterIn(size) + delta;
    return _copy(
      spotCenter: Offset(
        (c.dx / size.width).clamp(0.0, 1.0),
        (c.dy / size.height).clamp(0.0, 1.0),
      ),
    );
  }

  /// Işığın yarıçapını [radius] piksel yapar: en az [minSpotRadius], en
  /// çok alanın kısa kenarı.
  StageCoverState resizedSpot(double radius, Size size) {
    if (size.isEmpty) return this;
    final r = radius.clamp(
      minSpotRadius,
      math.max(minSpotRadius, size.shortestSide),
    );
    return _copy(spotRadius: r / size.shortestSide);
  }

  /// Perdeyi [dy] piksel indirir (eksi: kaldırır).
  StageCoverState movedCurtain(double dy, Size size) {
    if (size.isEmpty) return this;
    final top = (curtainTopIn(size) + dy).clamp(0.0, _curtainMax(size));
    return _copy(curtainTop: top / size.height);
  }

  static double _curtainMax(Size size) =>
      math.max(0, size.height - curtainBarHeight);

  StageCoverState _copy({
    StageCover? mode,
    Offset? spotCenter,
    double? spotRadius,
    double? curtainTop,
  }) => StageCoverState(
    mode: mode ?? this.mode,
    spotCenter: spotCenter ?? this.spotCenter,
    spotRadius: spotRadius ?? this.spotRadius,
    curtainTop: curtainTop ?? this.curtainTop,
  );
}

/// Örtünün durumu. Işığın yeri ve büyüklüğü belge açık kaldıkça hatırlanır;
/// perde her açılışta tamamen örtülü başlar.
class StageCoverNotifier extends Notifier<StageCoverState> {
  @override
  StageCoverState build() => const StageCoverState();

  /// [mode]'u açar; zaten açıksa kapatır.
  void toggle(StageCover mode) => state = state.mode == mode
      ? state._copy(mode: StageCover.none)
      : state._copy(
          mode: mode,
          curtainTop: mode == StageCover.curtain ? 0 : null,
        );

  void close() {
    if (state.mode != StageCover.none) {
      state = state._copy(mode: StageCover.none);
    }
  }

  void update(StageCoverState next) => state = next;
}

final stageCoverProvider =
    NotifierProvider<StageCoverNotifier, StageCoverState>(
      StageCoverNotifier.new,
    );

/// Örtünün ikonu ve adı (araç kutusu, menü, tanıtım).
IconData stageCoverIcon(StageCover mode) => switch (mode) {
  StageCover.spotlight => LucideIcons.flashlight,
  StageCover.curtain => LucideIcons.blinds,
  StageCover.none => LucideIcons.eye,
};

String stageCoverLabel(AppLocalizations l10n, StageCover mode) =>
    switch (mode) {
      StageCover.spotlight => l10n.spotlight,
      StageCover.curtain => l10n.curtain,
      StageCover.none => '',
    };

/// Belge alanının üstüne serilen örtü; açık değilse hiçbir şey çizmez ve
/// dokunuşları geçirir.
class StageCoverLayer extends ConsumerWidget {
  const StageCoverLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stageCoverProvider);
    final notifier = ref.read(stageCoverProvider.notifier);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final Widget child = switch (state.mode) {
          StageCover.none => const SizedBox.shrink(key: ValueKey('no-cover')),
          StageCover.spotlight => _Spotlight(
            key: const ValueKey('spotlight'),
            center: state.spotCenterIn(size),
            radius: state.spotRadiusIn(size),
            onMove: (d) => notifier.update(
              ref.read(stageCoverProvider).movedSpot(d, size),
            ),
            onResize: (r) => notifier.update(
              ref.read(stageCoverProvider).resizedSpot(r, size),
            ),
            onClose: notifier.close,
          ),
          StageCover.curtain => _Curtain(
            key: const ValueKey('curtain'),
            top: state.curtainTopIn(size),
            onMove: (dy) => notifier.update(
              ref.read(stageCoverProvider).movedCurtain(dy, size),
            ),
            onClose: notifier.close,
          ),
        };
        return AnimatedSwitcher(
          duration: animate ? Motion.normal : Duration.zero,
          // Kapanan örtü solarken dokunuşları tutmasın.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [
              for (final p in previous) IgnorePointer(child: p),
              ?current,
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Karartılmış alanda dairesel ışık. Işığın içi dokunuşları alttaki belgeye
/// geçirir; karartıyı sürüklemek ışığı taşır, iki parmak büyütür, fare
/// tekerleği ve kenardaki tutamak boyutlandırır.
class _Spotlight extends StatefulWidget {
  const _Spotlight({
    super.key,
    required this.center,
    required this.radius,
    required this.onMove,
    required this.onResize,
    required this.onClose,
  });

  final Offset center;
  final double radius;
  final ValueChanged<Offset> onMove;
  final ValueChanged<double> onResize;
  final VoidCallback onClose;

  @override
  State<_Spotlight> createState() => _SpotlightState();
}

class _SpotlightState extends State<_Spotlight> {
  double _startRadius = 0;

  /// Tutamaklar ışığın çemberi üzerinde: sağ alt (boyut), sağ üst (kapat).
  static const _handle = 40.0;

  Offset _onRing(double angle) =>
      widget.center + Offset(math.cos(angle), math.sin(angle)) * widget.radius;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final resizeAt = _onRing(math.pi / 4);
    final closeAt = _onRing(-math.pi / 4);
    return Stack(
      fit: StackFit.expand,
      children: [
        _HolePassThrough(
          center: widget.center,
          radius: widget.radius,
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                widget.onResize(widget.radius - e.scrollDelta.dy / 4);
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => _startRadius = widget.radius,
                onScaleUpdate: (d) {
                  widget.onMove(d.focalPointDelta);
                  if (d.pointerCount > 1) {
                    widget.onResize(_startRadius * d.scale);
                  }
                },
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    center: widget.center,
                    radius: widget.radius,
                    scrim: c.scrim,
                    ring: c.surfaceRaised.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: resizeAt.dx - _handle / 2,
          top: resizeAt.dy - _handle / 2,
          child: Tooltip(
            message: l10n.spotlightResize,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpLeftDownRight,
              child: GestureDetector(
                key: const ValueKey('spotlight-resize'),
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  final box = context.findRenderObject();
                  if (box is! RenderBox) return;
                  final p = box.globalToLocal(d.globalPosition);
                  widget.onResize((p - widget.center).distance);
                },
                child: _RoundHandle(
                  size: _handle,
                  child: Icon(
                    LucideIcons.moveDiagonal2,
                    size: 18,
                    color: c.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: closeAt.dx - _handle / 2,
          top: closeAt.dy - _handle / 2,
          child: Tooltip(
            message: l10n.spotlightClose,
            child: GestureDetector(
              key: const ValueKey('spotlight-close'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: _RoundHandle(
                size: _handle,
                child: Icon(LucideIcons.x, size: 18, color: c.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundHandle extends StatelessWidget {
  const _RoundHandle({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        shape: BoxShape.circle,
        boxShadow: c.shadowPop,
      ),
      child: Center(child: child),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.center,
    required this.radius,
    required this.scrim,
    required this.ring,
  });

  final Offset center;
  final double radius;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCircle(center: center, radius: radius);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
    canvas.drawPath(path, Paint()..color = scrim);
    canvas.drawOval(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.scrim != scrim ||
      old.ring != ring;
}

/// Dairenin içindeki dokunuşları geçirir (isabet yok sayılır), dışını
/// çocuğa verir.
class _HolePassThrough extends SingleChildRenderObjectWidget {
  const _HolePassThrough({
    required this.center,
    required this.radius,
    super.child,
  });

  final Offset center;
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHolePassThrough(center, radius);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHolePassThrough renderObject,
  ) {
    renderObject
      ..center = center
      ..radius = radius;
  }
}

class _RenderHolePassThrough extends RenderProxyBox {
  _RenderHolePassThrough(this.center, this.radius);

  Offset center;
  double radius;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if ((position - center).distance <= radius) return false;
    return super.hitTest(result, position: position);
  }
}

/// Alanı yukarıdan aşağı örten perde. Perdeyi sürüklemek (ya da üstünde
/// tekerlek) onu indirip kaldırır; perdenin üstünde kalan yer olağan
/// çalışır. Üst kenarında tutamak çubuğu: ipucu ve kapat düğmesi.
class _Curtain extends StatelessWidget {
  const _Curtain({
    super.key,
    required this.top,
    required this.onMove,
    required this.onClose,
  });

  final double top;
  final ValueChanged<double> onMove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: top,
          bottom: 0,
          child: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) onMove(e.scrollDelta.dy);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                key: const ValueKey('curtain-sheet'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => onMove(d.delta.dy),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    boxShadow: c.shadowDock,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: curtainBarHeight,
                      child: Row(
                        children: [
                          const SizedBox(width: Space.s2),
                          IconButton(
                            key: const ValueKey('curtain-close'),
                            tooltip: l10n.curtainClose,
                            icon: const Icon(LucideIcons.x),
                            onPressed: onClose,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: c.lineStrong,
                                    borderRadius: BorderRadius.circular(
                                      Radii.pill,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.s1),
                                Text(
                                  l10n.curtainHint,
                                  style: InkenText.caption.copyWith(
                                    color: c.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Kapat düğmesini dengeler; ipucu ortada kalır.
                          const SizedBox(width: Space.s2 + Sizes.target),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
