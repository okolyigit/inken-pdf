import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Yakalanan alan: sayfa (0'dan) ve sayfadaki dikdörtgen (pt).
typedef CaptureSelection = ({int page, PageRegion region});

/// Yakalanan alanla yapılabilecekler.
enum CaptureAction { copy, save, share, newPage }

/// Bölge yakalama örtüsü: belgenin üstünde, bütün girdiyi alır. Sayfada
/// sürüklemek bir alan seçer (yalnızca sürüklemenin başladığı sayfada,
/// sayfa sınırına kırpılır); dokunmak sayfanın tamamını seçer. Seçimin
/// dışı karartılır, yanında eylem çubuğu çıkar. Üstte ipucu ve kapat
/// düğmesi (telefonda Esc yok).
class CaptureLayer extends StatefulWidget {
  const CaptureLayer({
    super.key,
    required this.geometry,
    required this.pageSize,
    required this.onAction,
    required this.onClose,
    this.busy = false,
    this.canAddPage = true,
  });

  final PageGeometry geometry;

  /// Sayfanın modeldeki boyutu (pt); sayfa yoksa `null`.
  final Size? Function(int page) pageSize;

  final void Function(CaptureAction action, CaptureSelection selection)
  onAction;
  final VoidCallback onClose;

  /// Görüntü hazırlanıyor: düğmeler pasif, çubukta ilerleme.
  final bool busy;

  /// "Yeni sayfaya al" kullanılabilir mi (sayfa düzeni değişebiliyor mu)?
  final bool canAddPage;

  @override
  State<CaptureLayer> createState() => _CaptureLayerState();
}

class _CaptureLayerState extends State<CaptureLayer> {
  int? _pointer;
  int? _dragPage;
  Offset? _from, _to; // sayfa uzayında
  CaptureSelection? _selection;

  void _down(PointerDownEvent e) {
    if (_pointer != null || widget.busy) return;
    final view = widget.geometry.pageAt(e.localPosition);
    if (view == null) return;
    _pointer = e.pointer;
    setState(() {
      _dragPage = view.index;
      _from = _to = view.toPage(e.localPosition);
      _selection = null;
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final view = widget.geometry.viewportOf(_dragPage!);
    if (view == null) return;
    setState(() => _to = view.toPage(e.localPosition));
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final page = _dragPage!;
    final size = widget.pageSize(page);
    final from = _from!, to = _to!;
    setState(() {
      _dragPage = null;
      _from = _to = null;
      if (size == null) return;
      final region =
          captureRegion(
            from.dx,
            from.dy,
            to.dx,
            to.dy,
            pageWidth: size.width,
            pageHeight: size.height,
          ) ??
          (left: 0.0, top: 0.0, right: size.width, bottom: size.height);
      _selection = (page: page, region: region);
    });
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    setState(() {
      _pointer = null;
      _dragPage = null;
      _from = _to = null;
    });
  }

  /// Ekrandaki dikdörtgen: sürüklenen ya da seçilen alan.
  Rect? _screenRect() {
    if (_dragPage case final page?) {
      final view = widget.geometry.viewportOf(page);
      final size = widget.pageSize(page);
      if (view == null || size == null) return null;
      final pageRect = view.rect;
      final r = Rect.fromPoints(view.toView(_from!), view.toView(_to!));
      return r.intersect(pageRect);
    }
    if (_selection case (:final page, :final region)) {
      final view = widget.geometry.viewportOf(page);
      if (view == null) return null;
      return Rect.fromPoints(
        view.toView(Offset(region.left, region.top)),
        view.toView(Offset(region.right, region.bottom)),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.geometry,
      builder: (context, _) {
        final rect = _screenRect();
        final selection = _selection;
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                key: const ValueKey('capture-layer'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: _cancel,
                child: MouseRegion(
                  cursor: SystemMouseCursors.precise,
                  child: CustomPaint(
                    painter: _ScrimPainter(
                      hole: rect,
                      scrim: c.scrim,
                      edge: c.accent,
                    ),
                  ),
                ),
              ),
            ),
            // İpucu ve kapat: üstte ortada; seçim varken de durur.
            Positioned(
              top: Space.s3,
              left: Space.s3,
              right: Space.s3,
              child: Center(
                child: _Hint(text: l10n.captureHint, onClose: widget.onClose),
              ),
            ),
            if (selection != null && rect != null && _dragPage == null)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _BarLayout(rect),
                  child: _Bar(
                    busy: widget.busy,
                    canAddPage: widget.canAddPage,
                    onAction: (a) => widget.onAction(a, selection),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Seçimin dışını karartır, seçimin çevresine çizgi çeker.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, required this.scrim, required this.edge});

  final Rect? hole;
  final Color scrim;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    final h = hole;
    final path = Path()..addRect(all);
    if (h != null && !h.isEmpty) {
      path
        ..addRect(h)
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = scrim);
    if (h != null && !h.isEmpty) {
      canvas.drawRect(
        h,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.scrim != scrim || old.edge != edge;
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: c.shadowPop,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.s4, right: Space.s1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons200.camera, size: 20, color: c.accent),
              const SizedBox(width: Space.s2),
              Flexible(
                child: Text(
                  text,
                  style: InkenText.body.copyWith(color: c.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: const ValueKey('capture-close'),
                tooltip: '${l10n.close} (Esc)',
                icon: const Icon(LucideIcons200.x),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.busy,
    required this.canAddPage,
    required this.onAction,
  });

  final bool busy;
  final bool canAddPage;
  final ValueChanged<CaptureAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    final actions = [
      (CaptureAction.copy, LucideIcons200.copy, l10n.copy, null),
      (CaptureAction.save, LucideIcons200.download, l10n.captureSave, null),
      (CaptureAction.share, LucideIcons200.share2, l10n.captureShare, null),
      (
        CaptureAction.newPage,
        LucideIcons200.filePlus2,
        l10n.captureToNewPage,
        l10n.captureToNewPageHint,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // Yer varsa simge + ad (tahtada okunur), yoksa yalnızca simge.
        final labels = box.maxWidth >= 640;
        return Semantics(
          container: true,
          label: l10n.captureBar,
          child: Material(
            key: const ValueKey('capture-bar'),
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                boxShadow: c.shadowPop,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (action, icon, label, hint) in actions)
                      _button(
                        action,
                        icon,
                        label,
                        hint,
                        labels: labels,
                        enabled:
                            !busy &&
                            (action != CaptureAction.newPage || canAddPage),
                      ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Space.s3),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _button(
    CaptureAction action,
    IconData icon,
    String label,
    String? hint, {
    required bool labels,
    required bool enabled,
  }) {
    final key = ValueKey('capture-${action.name}');
    final onPressed = enabled ? () => onAction(action) : null;
    if (!labels) {
      return IconButton(
        key: key,
        tooltip: hint == null ? label : '$label: $hint',
        icon: Icon(icon),
        onPressed: onPressed,
      );
    }
    return Tooltip(
      message: hint ?? '',
      child: TextButton.icon(
        key: key,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, Sizes.target),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

/// Çubuğu seçimin altına, sığmazsa üstüne, o da sığmazsa içine alttan
/// yerleştirir; yatayda seçime ortalı, ekrandan taşmaz. Üstteki ipucunun
/// altında kalır.
class _BarLayout extends SingleChildLayoutDelegate {
  _BarLayout(this.selection);

  final Rect selection;

  static const double _gap = Space.s3;

  /// İpucunun kapladığı üst bant.
  static const double _top = Space.s3 + Sizes.target + Space.s2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (selection.center.dx - child.width / 2)
        .clamp(_gap, math.max(_gap, size.width - child.width - _gap))
        .toDouble();
    double y;
    if (selection.bottom + _gap + child.height <= size.height - _gap) {
      y = selection.bottom + _gap;
    } else if (selection.top - _gap - child.height >= _top) {
      y = selection.top - _gap - child.height;
    } else {
      y = math.max(
        _top,
        math.min(selection.bottom, size.height) - _gap - child.height,
      );
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BarLayout old) => old.selection != selection;
}
