import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_pdf/inken_pdf.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../settings/settings_store.dart';

/// Sayfa kaydırma çubuğu gösterilsin mi (Görünüm menüsü)?
class PageScrollbarNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(settingsStoreProvider).get<bool>('pageScrollbar') ?? true;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('pageScrollbar', on);
  }
}

final pageScrollbarProvider = NotifierProvider<PageScrollbarNotifier, bool>(
  PageScrollbarNotifier.new,
);

/// Sağ kenarda dikey kaydırma çubuğu: tutamağı sürüklemek belgeyi kaydırır,
/// çubuğa dokunmak o konuma atlar. Sürüklerken yanında "42 / 107" görünür.
///
/// Görünen çubuk incedir; dokunma alanı [hitWidth] genişliğindedir (akıllı
/// tahtada parmakla tutulabilsin).
class PageScrollbar extends StatefulWidget {
  const PageScrollbar({super.key, required this.scroller});

  final PageScroller scroller;

  /// Dokunma alanının genişliği.
  static const double hitWidth = 24;

  /// Tutamağın en küçük yüksekliği.
  static const double minThumb = 40;

  @override
  State<PageScrollbar> createState() => _PageScrollbarState();
}

class _PageScrollbarState extends State<PageScrollbar> {
  bool _hovered = false;

  /// Sürükleme sürerken gösterilen konum (kaydırma gecikse de titremesin).
  double? _dragFraction;
  double _startFraction = 0;
  double _startY = 0;

  double _thumbHeight(double track) => (track * widget.scroller.visibleFraction)
      .clamp(PageScrollbar.minThumb, track / 2);

  void _jumpTo(double y, double track) {
    final thumb = _thumbHeight(track);
    final travel = track - thumb;
    if (travel <= 0) return;
    final f = ((y - thumb / 2) / travel).clamp(0.0, 1.0);
    setState(() => _dragFraction = f);
    widget.scroller.scrollToFraction(f);
  }

  void _dragStart(double y, double track) {
    final f = widget.scroller.scrollFraction ?? 0;
    final thumb = _thumbHeight(track);
    final top = f * (track - thumb);
    if (y < top || y > top + thumb) {
      // Tutamağın dışından başlayan sürükleme: önce oraya atla.
      _jumpTo(y, track);
    } else {
      setState(() => _dragFraction = f);
    }
    _startFraction = _dragFraction!;
    _startY = y;
  }

  void _dragUpdate(double y, double track) {
    final travel = track - _thumbHeight(track);
    if (travel <= 0) return;
    final f = (_startFraction + (y - _startY) / travel).clamp(0.0, 1.0);
    setState(() => _dragFraction = f);
    widget.scroller.scrollToFraction(f);
  }

  void _dragEnd() => setState(() => _dragFraction = null);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.scroller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final s = widget.scroller;
          final fraction = _dragFraction ?? s.scrollFraction;
          if (fraction == null) return const SizedBox.shrink();
          final track = constraints.maxHeight;
          final thumb = _thumbHeight(track);
          final top = fraction * (track - thumb);
          final dragging = _dragFraction != null;
          final active = dragging || _hovered;
          final page = s.currentPage;
          return Semantics(
            label: l10n.pageScrollbar,
            slider: true,
            value: page == null ? null : '${page + 1} / ${s.pageCount}',
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                key: const ValueKey('page-scrollbar'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  _jumpTo(d.localPosition.dy, track);
                  _dragEnd();
                },
                onVerticalDragStart: (d) =>
                    _dragStart(d.localPosition.dy, track),
                onVerticalDragUpdate: (d) =>
                    _dragUpdate(d.localPosition.dy, track),
                onVerticalDragEnd: (_) => _dragEnd(),
                onVerticalDragCancel: _dragEnd,
                child: SizedBox(
                  width: PageScrollbar.hitWidth,
                  height: track,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: top,
                        right: Space.s1,
                        height: thumb,
                        child: AnimatedContainer(
                          key: const ValueKey('page-scrollbar-thumb'),
                          duration: Motion.fast,
                          curve: Motion.curve,
                          width: active ? 8 : 5,
                          decoration: BoxDecoration(
                            color: active ? c.brand : c.lineStrong,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        ),
                      ),
                      if (dragging && page != null)
                        Positioned(
                          top: top + thumb / 2 - 14,
                          right: PageScrollbar.hitWidth + Space.s1,
                          child: Container(
                            key: const ValueKey('page-scrollbar-label'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.s3,
                              vertical: Space.s1,
                            ),
                            decoration: BoxDecoration(
                              color: c.ink.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              '${page + 1} / ${s.pageCount}',
                              style: InkenText.numeric.copyWith(
                                color: c.surface,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
