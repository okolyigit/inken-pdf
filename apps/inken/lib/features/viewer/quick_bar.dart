import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../settings/settings_store.dart';
import 'app_menus.dart';
import 'page_templates.dart';

/// Hızlı erişim çubuğu açık mı (Görünüm menüsü ve Ayarlar; kalıcı).
class QuickBarNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).get<bool>('quickBar') ?? true;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('quickBar', on);
  }
}

final quickBarProvider = NotifierProvider<QuickBarNotifier, bool>(
  QuickBarNotifier.new,
);

/// Menü çubuğunun altında simgeli hızlı erişim çubuğu: dosya (aç, kaydet,
/// dışa aktar, yazdır) · sayfa (ekle, sil, git) · tam ekran … ayarlar.
/// Komutlar menüdekilerle aynıdır ([DocumentMenuActions]); `null` olan
/// pasif görünür (açılış ekranında belgeye bağlı olanlar).
///
/// Araçlar ve geri al / yinele burada değil, yüzen araç kutusundadır.
class QuickBar extends StatelessWidget {
  const QuickBar({
    super.key,
    required this.onOpen,
    required this.onSettings,
    this.actions = const DocumentMenuActions(),
    this.framed = true,
  });

  final VoidCallback onOpen;
  final VoidCallback onSettings;
  final DocumentMenuActions actions;

  /// Kendi zemini ve alt çizgisi (masaüstü); tablette üst çubuğun içinde
  /// `false`.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final a = actions;

    Widget button(
      String id,
      IconData icon,
      String label,
      VoidCallback? onPressed,
    ) => IconButton(
      key: ValueKey('quick-$id'),
      tooltip: label,
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: c.ink,
        disabledForegroundColor: c.inkFaint,
        hoverColor: c.surfaceHover,
        fixedSize: const Size.square(Sizes.target),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );

    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s2,
        vertical: Space.s3,
      ),
      child: VerticalDivider(width: 1, thickness: 1, color: c.line),
    );

    final row = Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                button('open', LucideIcons.folderOpen, l10n.openPdf, onOpen),
                button('save', LucideIcons.save, l10n.save, a.save),
                button(
                  'export',
                  LucideIcons.fileDown,
                  l10n.exportShort,
                  a.export,
                ),
                button(
                  'print',
                  LucideIcons.printer,
                  l10n.printDocument,
                  a.print,
                ),
                divider(),
                MenuAnchor(
                  menuChildren: pageInsertMenuChildren(
                    l10n,
                    orientation: a.newPageOrientation,
                    onOrientation: a.setNewPageOrientation,
                    color: a.newPageColor,
                    onColor: a.setNewPageColor,
                    onInsert: a.insertPage,
                    keyPrefix: 'quick-insert',
                  ),
                  builder: (context, menu, _) => button(
                    'insert-page',
                    LucideIcons.filePlus2,
                    l10n.insertPage,
                    a.insertPage == null
                        ? null
                        : () => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
                button(
                  'delete-page',
                  LucideIcons.fileMinus2,
                  l10n.deletePage,
                  a.deletePage,
                ),
                button(
                  'rotate-page',
                  LucideIcons.rotateCw,
                  l10n.rotateRight,
                  a.rotatePage == null ? null : () => a.rotatePage!(1),
                ),
                button('search', LucideIcons.search, l10n.searchHint, a.find),
                button(
                  'go-to-page',
                  LucideIcons.hash,
                  l10n.goToPageTitle,
                  a.goToPage,
                ),
                button(
                  'page-panel',
                  LucideIcons.panelLeft,
                  l10n.pagePanel,
                  a.pagePanel,
                ),
                divider(),
                button(
                  'fullscreen',
                  LucideIcons.maximize,
                  l10n.fullscreen,
                  a.fullscreen,
                ),
              ],
            ),
          ),
        ),
        button('share', LucideIcons.share2, l10n.shareDocument, a.share),
        button('settings', LucideIcons.settings, l10n.settings, onSettings),
      ],
    );
    if (!framed) return SizedBox(height: Sizes.quickbar, child: row);
    return Container(
      key: const ValueKey('quick-bar'),
      height: Sizes.quickbar + 1,
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: row,
    );
  }
}
