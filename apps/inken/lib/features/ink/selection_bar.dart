import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

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
    this.onEditImage,
    this.barKey,
  });

  /// Çubuğun kendisi (çizim katmanı içine düşen dokunuşu reddetsin diye).
  final GlobalKey? barKey;

  final PageGeometry geometry;
  final InkSession session;

  /// Seçim kutusunun öğelerden uzaklığı (ekran pikseli).
  final double pad;
  final VoidCallback onCopy;

  /// Tek görsel seçiliyken "Görseli düzenle".
  final VoidCallback? onEditImage;

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
          onEditImage: session.selectedImage == null ? null : onEditImage,
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
    this.onEditImage,
  });

  final InkSession session;
  final VoidCallback onCopy;
  final VoidCallback? onEditImage;
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
                if (onEditImage case final edit?)
                  IconButton(
                    key: const ValueKey('selection-edit-image'),
                    tooltip: l10n.editImage,
                    icon: const Icon(LucideIcons200.crop),
                    onPressed: edit,
                  ),
                if (session.selectionOpacityPercent case final percent?)
                  _OpacityButton(session: session, percent: percent),
                IconButton(
                  key: const ValueKey('selection-copy'),
                  tooltip: '${l10n.copy} (Ctrl+C)',
                  icon: const Icon(LucideIcons200.copy),
                  onPressed: onCopy,
                ),
                IconButton(
                  key: const ValueKey('selection-delete'),
                  tooltip: '${l10n.deleteSelection} (Delete)',
                  icon: const Icon(LucideIcons200.trash2),
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

/// Seçili metin ve görsellerin opaklığı: dokununca kaydırıcı açılır;
/// bırakınca tek geri alma adımıyla uygulanır.
class _OpacityButton extends StatefulWidget {
  const _OpacityButton({required this.session, required this.percent});

  final InkSession session;
  final int percent;

  @override
  State<_OpacityButton> createState() => _OpacityButtonState();
}

class _OpacityButtonState extends State<_OpacityButton> {
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        SizedBox(
          width: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.s3,
              Space.s2,
              Space.s2,
              Space.s1,
            ),
            child: StatefulBuilder(
              builder: (context, setLocal) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.opacity, style: InkenText.label),
                  OpacitySlider(
                    key: const ValueKey('selection-opacity-slider'),
                    percent: _dragging ?? widget.percent,
                    onChanged: (v) => setLocal(() => _dragging = v),
                    onChangeEnd: (v) {
                      _dragging = null;
                      widget.session.setSelectionOpacity(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        key: const ValueKey('selection-opacity'),
        tooltip: '${l10n.opacity} (${l10n.percent(widget.percent)})',
        icon: const Icon(LucideIcons200.blend),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
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
