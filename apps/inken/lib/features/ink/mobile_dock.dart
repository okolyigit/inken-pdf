import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'tool_options.dart';
import 'tool_state.dart';

/// Telefonda başparmak hizasındaki araç rafı (tasarım sistemi →
/// MobileLayout): ikon + etiket. Seçili araca ikinci dokunuş seçenekleri
/// alt sayfada açar. Yatay telefonda sol kenarda dikey ray olur.
class MobileDock extends ConsumerWidget {
  const MobileDock({super.key, this.vertical = false});

  final bool vertical;

  static const tools = [
    Tool.hand,
    Tool.select,
    Tool.pen,
    Tool.highlighter,
    Tool.laser,
    Tool.eraser,
    Tool.shape,
    Tool.text,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final state = ref.watch(toolProvider);

    // Seç düğmesi seçme türlerinin ikisini de temsil eder (son kullanılan).
    final selectKind = ref.watch(selectKindProvider);

    void tap(Tool tool) {
      if (tool == Tool.select) {
        if (selectTools.contains(state.tool)) {
          showToolOptionsSheet(context, Tool.select);
        } else {
          ref.read(toolProvider.notifier).select(selectKind);
        }
        return;
      }
      if (state.tool == tool && hasOptions(tool)) {
        showToolOptionsSheet(context, tool);
      } else {
        ref.read(toolProvider.notifier).select(tool);
      }
    }

    final items = [
      for (final t in tools)
        _DockTool(
          key: ValueKey('tool-${t.name}'),
          icon: t == Tool.select
              ? toolIcon(selectKind)
              : toolIcon(t, state.shapeKind),
          label: toolLabel(l10n, t),
          shortLabel: toolShortLabel(l10n, t),
          selected: t == Tool.select
              ? selectTools.contains(state.tool)
              : state.tool == t,
          ink: toolInkColor(state, t),
          onTap: () => tap(t),
        ),
    ];

    return Container(
      width: vertical ? Sizes.dockM : null,
      height: vertical ? null : Sizes.dockM,
      decoration: BoxDecoration(
        color: c.surface,
        border: vertical
            ? Border(right: BorderSide(color: c.line))
            : Border(top: BorderSide(color: c.line)),
      ),
      child: vertical
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final i in items) Expanded(child: i)],
            )
          : Row(children: [for (final i in items) Expanded(child: i)]),
    );
  }
}

class _DockTool extends StatelessWidget {
  const _DockTool({
    super.key,
    required this.icon,
    required this.label,
    required this.shortLabel,
    required this.selected,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// Rafta görünen ad (dar yer); [label] ipucunda ve ekran okuyucuda.
  final String shortLabel;
  final bool selected;
  final Color? ink;
  final VoidCallback onTap;

  /// İkon (32), boşluk ve tek satır adın sığdığı en küçük yükseklik.
  static const double _labeledHeight = 56;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          hoverColor: c.surfaceHover,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: Sizes.dockM),
            // Yer darsa (yatay telefonda dikey raf) yalnızca ikon; ad
            // ipucunda ve ekran okuyucuda kalır.
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? c.brand : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          selected ? selectedIcon(icon) : icon,
                          color: selected ? c.onBrand : c.ink,
                        ),
                        // Kalem / fosforlu: köşede o anki rengin noktası.
                        if (ink != null)
                          Positioned(
                            right: 8,
                            bottom: 3,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: ink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? c.brand : c.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (constraints.maxHeight >= _labeledHeight) ...[
                    const SizedBox(height: Space.s1),
                    Text(
                      shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InkenText.caption.copyWith(
                        color: selected ? c.brand : c.inkMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
