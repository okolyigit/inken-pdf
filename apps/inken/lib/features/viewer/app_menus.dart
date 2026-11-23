import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/logo.dart';
import '../../theme/theme_mode.dart';
import '../../theme/tokens.dart';
import '../ink/tool_options.dart';
import '../ink/tool_state.dart';
import '../presentation/stage_cover.dart';
import '../../theme/ui_scale.dart';
import '../settings/language.dart';
import '../settings/settings_page.dart';
import '../settings/share_app.dart';
import 'home_intro.dart';
import 'night_mode.dart';
import 'page_panel.dart';
import 'page_templates.dart';
import 'idle_fade.dart';
import 'page_scrollbar.dart';
import 'quick_bar.dart';

/// Menüler arasındaki ince çizgi.
const menuSeparator = Padding(
  padding: EdgeInsets.symmetric(vertical: Space.s1, horizontal: Space.s2),
  child: Divider(height: 1),
);

List<(ThemeMode, String)> themeChoices(AppLocalizations l10n) => [
  (ThemeMode.light, l10n.themeLight),
  (ThemeMode.dark, l10n.themeDark),
  (ThemeMode.system, l10n.themeSystem),
];

/// Görünüm menüsünün belgeden bağımsız ayarları: tema, araç kutusu,
/// kaydırma çubuğu, soldurma. Açılış ekranında da kullanılır (belge
/// açmadan ayarlara ulaşılsın).
List<Widget> viewSettingsMenuItems(WidgetRef ref, AppLocalizations l10n) => [
  // Çubuklar ve paneller tek alt menüde: Görünüm menüsü kısa kalsın. En
  // üstte: alt menü aşağıya sığsın (sığmazsa Flutter satırın üstüne açar).
  SubmenuButton(
    key: const ValueKey('menu-bars'),
    leadingIcon: const Icon(LucideIcons.panelsTopLeft),
    menuChildren: [
      SubmenuButton(
        menuChildren: [
          for (final (edge, _, label) in dockEdgeChoices(l10n))
            RadioMenuButton<DockEdge>(
              value: edge,
              groupValue: ref.watch(toolDockProvider),
              onChanged: (e) => ref.read(toolDockProvider.notifier).set(e!),
              child: Text(label),
            ),
        ],
        child: Text(l10n.toolDock),
      ),
      menuSeparator,
      CheckboxMenuButton(
        value: ref.watch(quickBarProvider),
        onChanged: (v) => ref.read(quickBarProvider.notifier).set(v!),
        child: Text(l10n.quickBar),
      ),
      CheckboxMenuButton(
        key: const ValueKey('menu-page-panel'),
        value: ref.watch(pagePanelProvider),
        onChanged: (v) => ref.read(pagePanelProvider.notifier).set(v!),
        child: Text(l10n.pagePanel),
      ),
      CheckboxMenuButton(
        value: ref.watch(pageScrollbarProvider),
        onChanged: (v) => ref.read(pageScrollbarProvider.notifier).set(v!),
        child: Text(l10n.pageScrollbar),
      ),
      CheckboxMenuButton(
        value: ref.watch(floatingFadeProvider),
        onChanged: (v) => ref.read(floatingFadeProvider.notifier).set(v!),
        child: Text(l10n.fadeFloating),
      ),
      CheckboxMenuButton(
        value: ref.watch(homeIntroProvider),
        onChanged: (v) => ref.read(homeIntroProvider.notifier).set(v!),
        child: Text(l10n.introShowSetting),
      ),
    ],
    child: Text(l10n.menuBars),
  ),
  SubmenuButton(
    leadingIcon: const Icon(LucideIcons.palette),
    menuChildren: [
      for (final (mode, label) in themeChoices(l10n))
        RadioMenuButton<ThemeMode>(
          value: mode,
          groupValue: ref.watch(themeModeProvider),
          onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
          child: Text(label),
        ),
    ],
    child: Text(l10n.theme),
  ),
  CheckboxMenuButton(
    key: const ValueKey('menu-night-mode'),
    value: ref.watch(nightModeProvider),
    onChanged: (v) => ref.read(nightModeProvider.notifier).set(v!),
    trailingIcon: const Icon(LucideIcons.moon, size: 18),
    child: Text(l10n.nightMode),
  ),
  SubmenuButton(
    key: const ValueKey('menu-ui-scale'),
    leadingIcon: const Icon(LucideIcons.scaling),
    menuChildren: [
      for (final (s, label) in uiScaleChoices(l10n))
        RadioMenuButton<UiScale>(
          key: ValueKey('menu-ui-scale-${s.name}'),
          value: s,
          groupValue: ref.watch(uiScaleProvider),
          onChanged: (v) => ref.read(uiScaleProvider.notifier).set(v!),
          child: Text(label),
        ),
    ],
    child: Text(l10n.uiScale),
  ),
  SubmenuButton(
    key: const ValueKey('menu-language'),
    leadingIcon: const Icon(LucideIcons.languages),
    menuChildren: [
      for (final (language, label) in languageChoices(l10n))
        RadioMenuButton<AppLanguage>(
          key: ValueKey('menu-language-${language.name}'),
          value: language,
          groupValue: ref.watch(appLanguageProvider),
          onChanged: (l) => ref.read(appLanguageProvider.notifier).set(l!),
          child: Text(label),
        ),
    ],
    child: Text(l10n.language),
  ),
];

/// Klasik menü çubuğu (tasarım sistemi → MenuBar): solda 28 px logo ve
/// menüler, sağda [trailing] (kayıt durumu). Masaüstünde hem belge hem
/// açılış ekranında.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key, required this.menus, this.trailing});

  /// Üst düzey menüler; başlıkları [barItemStyle] ile.
  final List<Widget> Function(ButtonStyle barItemStyle) menus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final menuTheme = MenuTheme.of(context);
    final barStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, Sizes.menubarItem)),
      maximumSize: const WidgetStatePropertyAll(
        Size(double.infinity, Sizes.menubarItem),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Space.s3),
      ),
      textStyle: const WidgetStatePropertyAll(InkenText.menu),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      // Açık menünün başlığı üzerine gelinmiş gibi sade görünür; ayrıca
      // vurgu rengi ya da odak çerçevesi yok.
      foregroundColor: WidgetStatePropertyAll(c.ink),
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.focused) || s.contains(WidgetState.hovered)
            ? c.surfaceHover
            : null,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
    );
    const flat = MenuStyle(
      elevation: WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
    );
    return Container(
      height: Sizes.menubar,
      padding: const EdgeInsets.only(left: Space.s2, right: Space.s4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: Space.s1, right: Space.s2),
            child: InkenLogo(size: 28),
          ),
          // Uzun menü (Görünüm) alçak pencerede yukarı kayıp başlığını
          // örtmesin: boyu çubuğun altında kalan alanla sınırlı, gerisi kayar.
          MenuTheme(
            data: MenuThemeData(
              style: (menuTheme.style ?? const MenuStyle()).copyWith(
                maximumSize: WidgetStatePropertyAll(
                  Size(
                    double.infinity,
                    math.max(
                      Sizes.menuRow * 3,
                      MediaQuery.sizeOf(context).height -
                          Sizes.menubar -
                          Space.s4,
                    ),
                  ),
                ),
              ),
            ),
            child: MenuBar(style: flat, children: menus(barStyle)),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Belgeye bağlı menü komutları. `null` olan komut pasif (gri) görünür:
/// açılış ekranında hepsi `null`dur; menü yine tamdır, uygulamanın neler
/// yapabildiği belge açmadan da görülür.
class DocumentMenuActions {
  const DocumentMenuActions({
    this.save,
    this.saveAs,
    this.export,
    this.close,
    this.undo,
    this.redo,
    this.deleteSelection,
    this.zoomIn,
    this.zoomOut,
    this.fitPage,
    this.fitWidth,
    this.actualSize,
    this.fullscreen,
    this.previousPage,
    this.nextPage,
    this.goToPage,
    this.print,
    this.share,
    this.sharePageImage,
    this.capture,
    this.insertPage,
    this.appendPage,
    this.newPageTemplate = PageTemplate.blank,
    this.newPageOrientation = PageOrientation.portrait,
    this.setNewPageOrientation,
    this.newPageColor = PageColor.white,
    this.setNewPageColor,
    this.deletePage,
    this.rotatePage,
    this.spotlight,
    this.curtain,
    this.paste,
    this.insertImage,
    this.cut,
    this.copy,
    this.selectAll,
    this.find,
    this.properties,
    this.pagePanel,
  });

  final VoidCallback? save;
  final VoidCallback? saveAs;
  final VoidCallback? export;
  final VoidCallback? close;
  final VoidCallback? undo;
  final VoidCallback? redo;
  final VoidCallback? deleteSelection;
  final VoidCallback? zoomIn;
  final VoidCallback? zoomOut;

  /// Sayfaya / genişliğe sığdır, gerçek boyut (%100).
  final VoidCallback? fitPage;
  final VoidCallback? fitWidth;
  final VoidCallback? actualSize;
  final VoidCallback? fullscreen;
  final VoidCallback? previousPage;
  final VoidCallback? nextPage;
  final VoidCallback? goToPage;
  final VoidCallback? print;

  /// Belgeyi (düzenlenebilir PDF) sistemin paylaşma yoluna verir.
  final VoidCallback? share;

  /// Geçerli sayfayı görsel (PNG) olarak paylaşır.
  final VoidCallback? sharePageImage;

  /// Bölge yakalamayı başlatır.
  final VoidCallback? capture;

  /// Geçerli sayfanın arkasına seçilen zeminle sayfa ekler.
  final ValueChanged<PageTemplate>? insertPage;

  /// Belgenin sonuna [newPageTemplate] zeminli, seçili yön ve renkte sayfa
  /// ekler (hızlı erişim çubuğundaki +).
  final VoidCallback? appendPage;

  /// Son eklenen sayfanın zemini; [appendPage] bununla ekler.
  final PageTemplate newPageTemplate;

  /// Eklenecek sayfanın yönü ve değiştirilmesi ("Sayfa ekle" menüsünde).
  final PageOrientation newPageOrientation;
  final ValueChanged<PageOrientation>? setNewPageOrientation;

  /// Eklenecek sayfanın kâğıt rengi ve değiştirilmesi.
  final PageColor newPageColor;
  final ValueChanged<PageColor>? setNewPageColor;

  final VoidCallback? deletePage;

  /// Geçerli sayfayı verilen çeyrek tur kadar döndürür (1 sağa, -1 sola).
  final ValueChanged<int>? rotatePage;

  /// Spot ışığını / perdeyi açar ya da kapatır.
  final VoidCallback? spotlight;
  final VoidCallback? curtain;

  /// Panodaki görseli yapıştırır; dosyadan görsel ekler.
  final VoidCallback? paste;
  final VoidCallback? insertImage;

  /// Seçilenleri Inken panosuna alır (Kes siler); sayfadaki her şeyi seçer.
  final VoidCallback? cut;
  final VoidCallback? copy;
  final VoidCallback? selectAll;

  /// Belgede arama kutusunu açar.
  final VoidCallback? find;

  /// Belge özellikleri penceresini açar.
  final VoidCallback? properties;

  /// Sayfa küçük resimleri panelini açar / kapatır.
  final VoidCallback? pagePanel;
}

/// Uygulamanın menüleri: Dosya · Düzen · Görünüm · Sayfa · Araçlar ·
/// Yardım.
/// Menü çubuğu (masaüstü), logo menüsü (tablet) ve açılış ekranı aynı
/// listeyi kullanır. Kısayollar menüde yalnızca gösterilir; asıl bağlar
/// ekranların klavye işleyicisindedir. [barStyle] verilirse üst düzey
/// başlıklar menü çubuğu biçimindedir. [fileExtras] "Aç…"ın altına girer
/// (son belgeler). [onSelectTool] `null` ise araçlar pasif (açılış ekranı).
/// [onNew] tek boş sayfalık yeni PDF açar; [onGuide] "Başlarken"
/// kılavuzunu.
List<Widget> appMenus(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onNew,
  required VoidCallback onOpen,
  required VoidCallback onSettings,
  required VoidCallback onGuide,
  ValueChanged<Tool>? onSelectTool,
  DocumentMenuActions actions = const DocumentMenuActions(),
  ButtonStyle? barStyle,
  List<Widget> fileExtras = const [],
}) {
  final l10n = AppLocalizations.of(context);
  final tools = ref.watch(toolProvider);
  final toolNotifier = ref.read(toolProvider.notifier);
  final cover = ref.watch(stageCoverProvider.select((s) => s.mode));
  const key = SingleActivator.new;
  const sep = menuSeparator;
  final a = actions;

  Widget toolItem(Tool tool) => RadioMenuButton<Tool>(
    value: tool,
    groupValue: tools.tool,
    onChanged: onSelectTool == null ? null : (t) => onSelectTool(t!),
    shortcut: switch (toolShortcut(tool)) {
      'P' => const SingleActivator(LogicalKeyboardKey.keyP),
      'H' => const SingleActivator(LogicalKeyboardKey.keyH),
      'E' => const SingleActivator(LogicalKeyboardKey.keyE),
      'L' => const SingleActivator(LogicalKeyboardKey.keyL),
      'V' => const SingleActivator(LogicalKeyboardKey.keyV),
      'G' => const SingleActivator(LogicalKeyboardKey.keyG),
      'T' => const SingleActivator(LogicalKeyboardKey.keyT),
      _ => null,
    },
    trailingIcon: Icon(toolIcon(tool, tools.shapeKind), size: 18),
    child: Text(toolLabel(l10n, tool)),
  );

  Widget inputItem(InputMode mode, String label) => RadioMenuButton<InputMode>(
    value: mode,
    groupValue: tools.inputMode,
    onChanged: (m) => toolNotifier.setInputMode(m!),
    child: Text(label),
  );

  return [
    SubmenuButton(
      style: barStyle,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.filePlus),
          shortcut: key(LogicalKeyboardKey.keyN, control: true),
          onPressed: onNew,
          child: Text(l10n.newDocument),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.folderOpen),
          shortcut: key(LogicalKeyboardKey.keyO, control: true),
          onPressed: onOpen,
          child: Text(l10n.openPdfMenu),
        ),
        ...fileExtras,
        sep,
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.save),
          shortcut: key(LogicalKeyboardKey.keyS, control: true),
          onPressed: a.save,
          child: Text(l10n.save),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.saveAll),
          shortcut: key(LogicalKeyboardKey.keyS, control: true, shift: true),
          onPressed: a.saveAs,
          child: Text(l10n.saveAs),
        ),
        MenuItemButton(
          key: const ValueKey('menu-export'),
          leadingIcon: const Icon(LucideIcons.fileDown),
          shortcut: key(LogicalKeyboardKey.keyE, control: true),
          onPressed: a.export,
          child: Text(l10n.exportMenu),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.printer),
          shortcut: key(LogicalKeyboardKey.keyP, control: true),
          onPressed: a.print,
          child: Text(l10n.printDocument),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.share2),
          onPressed: a.share,
          child: Text(l10n.shareDocument),
        ),
        MenuItemButton(
          key: const ValueKey('menu-share-page-image'),
          leadingIcon: const Icon(LucideIcons.fileImage),
          onPressed: a.sharePageImage,
          child: Text(l10n.sharePageImage),
        ),
        MenuItemButton(
          key: const ValueKey('menu-properties'),
          leadingIcon: const Icon(LucideIcons.fileText),
          shortcut: key(LogicalKeyboardKey.keyD, control: true),
          onPressed: a.properties,
          child: Text(l10n.documentProperties),
        ),
        sep,
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.x),
          shortcut: key(LogicalKeyboardKey.keyW, control: true),
          onPressed: a.close,
          child: Text(l10n.closeDocument),
        ),
      ],
      child: Text(l10n.menuFile),
    ),
    SubmenuButton(
      style: barStyle,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.undo2),
          shortcut: key(LogicalKeyboardKey.keyZ, control: true),
          onPressed: a.undo,
          child: Text(l10n.undo),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.redo2),
          shortcut: key(LogicalKeyboardKey.keyY, control: true),
          onPressed: a.redo,
          child: Text(l10n.redo),
        ),
        sep,
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.scissors),
          shortcut: key(LogicalKeyboardKey.keyX, control: true),
          onPressed: a.cut,
          child: Text(l10n.cut),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.copy),
          shortcut: key(LogicalKeyboardKey.keyC, control: true),
          onPressed: a.copy,
          child: Text(l10n.copy),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.clipboardPaste),
          shortcut: key(LogicalKeyboardKey.keyV, control: true),
          onPressed: a.paste,
          child: Text(l10n.paste),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.squareDashedMousePointer),
          shortcut: key(LogicalKeyboardKey.keyA, control: true),
          onPressed: a.selectAll,
          child: Text(l10n.selectAll),
        ),
        MenuItemButton(
          key: const ValueKey('menu-find'),
          leadingIcon: const Icon(LucideIcons.search),
          shortcut: key(LogicalKeyboardKey.keyF, control: true),
          onPressed: a.find,
          child: Text(l10n.find),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.imagePlus),
          onPressed: a.insertImage,
          child: Text(l10n.insertImage),
        ),
        MenuItemButton(
          key: const ValueKey('menu-capture'),
          leadingIcon: const Icon(LucideIcons.camera),
          shortcut: key(LogicalKeyboardKey.keyC, control: true, shift: true),
          onPressed: a.capture,
          child: Text(l10n.captureRegion),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.trash2),
          shortcut: key(LogicalKeyboardKey.delete),
          onPressed: a.deleteSelection,
          child: Text(l10n.deleteSelection),
        ),
        sep,
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.settings),
          shortcut: key(LogicalKeyboardKey.comma, control: true),
          onPressed: onSettings,
          child: Text(l10n.settingsMenu),
        ),
      ],
      child: Text(l10n.menuEdit),
    ),
    SubmenuButton(
      style: barStyle,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.zoomIn),
          shortcut: key(LogicalKeyboardKey.equal, control: true),
          onPressed: a.zoomIn,
          child: Text(l10n.zoomIn),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.zoomOut),
          shortcut: key(LogicalKeyboardKey.minus, control: true),
          onPressed: a.zoomOut,
          child: Text(l10n.zoomOut),
        ),
        MenuItemButton(
          key: const ValueKey('menu-fit-page'),
          leadingIcon: const Icon(LucideIcons.scan),
          shortcut: key(LogicalKeyboardKey.digit0, control: true),
          onPressed: a.fitPage,
          child: Text(l10n.fitPage),
        ),
        MenuItemButton(
          key: const ValueKey('menu-fit-width'),
          leadingIcon: const Icon(LucideIcons.moveHorizontal),
          shortcut: key(LogicalKeyboardKey.digit2, control: true),
          onPressed: a.fitWidth,
          child: Text(l10n.fitWidth),
        ),
        MenuItemButton(
          key: const ValueKey('menu-actual-size'),
          leadingIcon: const Icon(LucideIcons.ratio),
          shortcut: key(LogicalKeyboardKey.digit1, control: true),
          onPressed: a.actualSize,
          child: Text(l10n.actualSize),
        ),
        sep,
        ...viewSettingsMenuItems(ref, l10n),
        sep,
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.maximize),
          shortcut: key(LogicalKeyboardKey.f11),
          onPressed: a.fullscreen,
          child: Text(l10n.fullscreen),
        ),
      ],
      child: Text(l10n.menuView),
    ),
    SubmenuButton(
      style: barStyle,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.chevronLeft),
          shortcut: key(LogicalKeyboardKey.pageUp),
          onPressed: a.previousPage,
          child: Text(l10n.previousPage),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.chevronRight),
          shortcut: key(LogicalKeyboardKey.pageDown),
          onPressed: a.nextPage,
          child: Text(l10n.nextPage),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.hash),
          shortcut: key(LogicalKeyboardKey.keyG, control: true),
          onPressed: a.goToPage,
          child: Text(l10n.goToPage),
        ),
        sep,
        SubmenuButton(
          leadingIcon: const Icon(LucideIcons.filePlus2),
          menuChildren: pageInsertMenuChildren(
            l10n,
            orientation: a.newPageOrientation,
            onOrientation: a.setNewPageOrientation,
            color: a.newPageColor,
            onColor: a.setNewPageColor,
            onInsert: a.insertPage,
          ),
          child: Text(l10n.insertPage),
        ),
        SubmenuButton(
          leadingIcon: const Icon(LucideIcons.rotateCw),
          menuChildren: [
            MenuItemButton(
              key: const ValueKey('menu-rotate-right'),
              leadingIcon: const Icon(LucideIcons.rotateCw),
              shortcut: key(LogicalKeyboardKey.keyR, control: true),
              onPressed: a.rotatePage == null ? null : () => a.rotatePage!(1),
              child: Text(l10n.rotateRight),
            ),
            MenuItemButton(
              key: const ValueKey('menu-rotate-left'),
              leadingIcon: const Icon(LucideIcons.rotateCcw),
              shortcut: key(
                LogicalKeyboardKey.keyR,
                control: true,
                shift: true,
              ),
              onPressed: a.rotatePage == null ? null : () => a.rotatePage!(-1),
              child: Text(l10n.rotateLeft),
            ),
          ],
          child: Text(l10n.rotatePage),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.fileMinus2),
          onPressed: a.deletePage,
          child: Text(l10n.deletePage),
        ),
      ],
      child: Text(l10n.menuPage),
    ),
    SubmenuButton(
      style: barStyle,
      menuChildren: [
        for (final t in Tool.values) toolItem(t),
        sep,
        // Ders anlatımı: sayfanın bir yerini aydınlat / yanıtı sakla.
        CheckboxMenuButton(
          value: cover == StageCover.spotlight,
          shortcut: key(LogicalKeyboardKey.keyS),
          onChanged: a.spotlight == null ? null : (_) => a.spotlight!(),
          trailingIcon: Icon(stageCoverIcon(StageCover.spotlight), size: 18),
          child: Text(l10n.spotlight),
        ),
        CheckboxMenuButton(
          value: cover == StageCover.curtain,
          shortcut: key(LogicalKeyboardKey.keyC),
          onChanged: a.curtain == null ? null : (_) => a.curtain!(),
          trailingIcon: Icon(stageCoverIcon(StageCover.curtain), size: 18),
          child: Text(l10n.curtain),
        ),
        sep,
        SubmenuButton(
          menuChildren: [
            inputItem(InputMode.auto, l10n.inputModeAuto),
            inputItem(InputMode.pen, l10n.inputModePen),
            inputItem(InputMode.touch, l10n.inputModeTouch),
          ],
          child: Text(l10n.inputMode),
        ),
      ],
      child: Text(l10n.menuTools),
    ),
    SubmenuButton(
      style: barStyle,
      menuChildren: helpMenuItems(context, onGuide: onGuide),
      child: Text(l10n.menuHelp),
    ),
  ];
}

/// Yardım: kısayollar, uygulama bilgileri, hakkında (Ayarlar sayfasının
/// ilgili sekmesini açar). Menülerde önlerinde "Başlarken" kılavuzu durur.
List<(SettingsSection, IconData, String)> helpEntries(AppLocalizations l10n) =>
    [
      (SettingsSection.shortcuts, LucideIcons.keyboard, l10n.keyboardShortcuts),
      (SettingsSection.info, LucideIcons.clipboardList, l10n.settingsInfo),
      (SettingsSection.about, LucideIcons.info, l10n.aboutApp),
    ];

List<Widget> helpMenuItems(
  BuildContext context, {
  required VoidCallback onGuide,
}) => [
  MenuItemButton(
    key: const ValueKey('help-guide'),
    leadingIcon: const Icon(LucideIcons.bookOpen),
    onPressed: onGuide,
    child: Text(AppLocalizations.of(context).guideMenu),
  ),
  for (final (section, icon, label) in helpEntries(
    AppLocalizations.of(context),
  ))
    MenuItemButton(
      key: ValueKey('help-${section.name}'),
      leadingIcon: Icon(icon),
      onPressed: () => openSettingsPage(context, initial: section),
      child: Text(label),
    ),
  MenuItemButton(
    key: const ValueKey('help-share-app'),
    leadingIcon: const Icon(LucideIcons.share2),
    onPressed: () => shareApp(context),
    child: Text(AppLocalizations.of(context).shareApp),
  ),
];

/// Arayüz boyutu seçenekleri ve adları.
List<(UiScale, String)> uiScaleChoices(AppLocalizations l10n) => [
  (UiScale.normal, l10n.uiScaleNormal),
  (UiScale.large, l10n.uiScaleLarge),
  (UiScale.larger, l10n.uiScaleLarger),
];
