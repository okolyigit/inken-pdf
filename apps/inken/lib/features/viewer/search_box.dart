import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Belgede arama kutusu (Ctrl+F): metin, "3 / 12", önceki / sonraki,
/// kapat. Yazdıkça arar; Enter sonraki, Shift+Enter önceki eşleşme, Esc
/// kapatır. Eşleşmeler sayfalarda vurgulanır ([InkenTextSearch]).
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.search,
    required this.currentPage,
    required this.onClose,
  });

  final InkenTextSearch search;

  /// Arama bu sayfadan (0'dan) başlar: ilk eşleşme ekrandakine en yakını.
  final int? Function() currentPage;
  final VoidCallback onClose;

  @override
  State<SearchBox> createState() => SearchBoxState();
}

class SearchBoxState extends State<SearchBox> {
  late final TextEditingController _text = TextEditingController(
    text: widget.search.query,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus());
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Kutuya odaklanır ve yazılanı seçer (yeniden Ctrl+F).
  void focus() {
    if (!mounted) return;
    _focus.requestFocus();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
  }

  /// Düğmeyle gezinince yazmaya devam edilebilsin: odak kutuda kalır.
  void _step(Future<void> Function() go) {
    go();
    _focus.requestFocus();
  }

  void _changed(String text) =>
      widget.search.find(text, fromPage: widget.currentPage());

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.search.previous();
      } else {
        widget.search.next();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final pill = IconButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    );
    return Container(
      key: const ValueKey('search-box'),
      height: Sizes.target,
      padding: const EdgeInsets.only(left: Space.s4, right: 2),
      decoration: BoxDecoration(
        color: c.surfaceRaised.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: c.shadowPop,
      ),
      child: ListenableBuilder(
        listenable: widget.search,
        builder: (context, _) {
          final s = widget.search;
          final hasQuery = s.query.trim().isNotEmpty;
          final count = s.matchCount;
          final index = s.currentIndex;
          final String? status = !hasQuery
              ? null
              : count == 0
              ? (s.isSearching ? l10n.searchSearching : l10n.searchNoResults)
              : l10n.searchCount(index == null ? 0 : index + 1, count);
          return Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: c.inkMuted),
              const SizedBox(width: Space.s2),
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    key: const ValueKey('search-field'),
                    controller: _text,
                    focusNode: _focus,
                    onChanged: _changed,
                    textInputAction: TextInputAction.search,
                    style: InkenText.body.copyWith(color: c.ink),
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.searchHint,
                      hintStyle: InkenText.body.copyWith(color: c.inkFaint),
                    ),
                  ),
                ),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                  child: Text(
                    status,
                    key: const ValueKey('search-status'),
                    style: InkenText.numeric.copyWith(
                      fontSize: 13,
                      color: count == 0 && !s.isSearching
                          ? c.danger
                          : c.inkMuted,
                    ),
                  ),
                ),
              IconButton(
                key: const ValueKey('search-previous'),
                tooltip: '${l10n.searchPrevious} (Shift+Enter)',
                style: pill,
                icon: const Icon(LucideIcons.chevronUp),
                onPressed: count > 0 ? () => _step(s.previous) : null,
              ),
              IconButton(
                key: const ValueKey('search-next'),
                tooltip: '${l10n.searchNext} (Enter)',
                style: pill,
                icon: const Icon(LucideIcons.chevronDown),
                onPressed: count > 0 ? () => _step(s.next) : null,
              ),
              IconButton(
                key: const ValueKey('search-close'),
                tooltip: '${l10n.searchClose} (Esc)',
                style: pill,
                icon: const Icon(LucideIcons.x),
                onPressed: widget.onClose,
              ),
            ],
          );
        },
      ),
    );
  }
}
