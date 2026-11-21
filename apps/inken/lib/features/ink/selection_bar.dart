import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'ink_painter.dart';
import 'ink_session.dart';
import 'tool_options.dart';
import 'tool_state.dart';

/// Seçimin hemen üstünde (yer yoksa altında) duran küçük çubuk: seçilenin
/// rengi (kalem paleti; rengi olan öğe varsa), Kopyala, Sil. Tahtada
/// parmakla, menüye gitmeden. Taşırken ve boyutlandırırken gizlenir.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.geometry,
    required this.session,
    required this.pad,
    required this.onCopy,
    this.barKey,
  });

  /// Çubuğun kendisi (çizim katmanı içine düşen dokunuşu reddetsin diye).
  final GlobalKey? barKey;

  final PageGeometry geometry;
  final InkSession session;

  /// Seçim kutusunun öğelerden uzaklığı (ekran pikseli).
  final double pad;
  final VoidCallback onCopy;

  /// Çubukla seçim kutusu arası (ekran pikseli).
  static const double gap = Space.s3;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([geometry, session, session.live]),
    builder: (context, _) {
      final page = session.selectionPage;
      if (page == null ||
          session.isMoving ||
          session.isResizing ||
          !geometry.isReady) {
        return const SizedBox.shrink();
      }
      final view = geometry.viewportOf(page);
      final r = view == null ? null : selectionScreenRect(view, session, pad);
      if (r == null) return const SizedBox.shrink();
      return CustomSingleChildLayout(
        delegate: _BarLayout(r),
        child: _Bar(
          key: barKey,
          session: session,
          onCopy: onCopy,
          colors: session.selectionHasColor,
        ),
      );
    },
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.session,
    required this.onCopy,
    required this.colors,
  });

  final InkSession session;
  final VoidCallback onCopy;
  final bool colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final names = colorNames(l10n, Tool.pen);
    return Semantics(
      container: true,
      label: l10n.selectionBar,
      child: Material(
        key: const ValueKey('selection-bar'),
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.pill),
        elevation: 0,
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
                if (colors) ...[
                  for (final (i, color) in penColors.indexed)
                    ColorSwatchButton(
                      key: ValueKey('selection-color-$i'),
                      color: Color(color),
                      label: l10n.recolorSelection(names[i]),
                      selected: false,
                      small: true,
                      onTap: () => session.recolorSelection(color),
                    ),
                  SizedBox(
                    height: 24,
                    child: VerticalDivider(width: Space.s3, color: c.line),
                  ),
                ],
                IconButton(
                  key: const ValueKey('selection-copy'),
                  tooltip: '${l10n.copy} (Ctrl+C)',
                  icon: const Icon(LucideIcons.copy),
                  onPressed: onCopy,
                ),
                IconButton(
                  key: const ValueKey('selection-delete'),
                  tooltip: '${l10n.deleteSelection} (Delete)',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: session.deleteSelection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Çubuğu seçimin üstüne, sığmazsa altına, o da sığmazsa kutunun içine
/// üstten yerleştirir; yatayda seçime ortalı, ekrandan taşmaz.
class _BarLayout extends SingleChildLayoutDelegate {
  _BarLayout(this.selection);

  final Rect selection;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    const gap = SelectionBar.gap;
    final x = (selection.center.dx - child.width / 2)
        .clamp(gap, math.max(gap, size.width - child.width - gap))
        .toDouble();
    double y;
    if (selection.top - gap - child.height >= 0) {
      y = selection.top - gap - child.height;
    } else if (selection.bottom + gap + child.height <= size.height) {
      y = selection.bottom + gap;
    } else {
      y = math.max(0, selection.top + gap);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BarLayout old) => old.selection != selection;
}
