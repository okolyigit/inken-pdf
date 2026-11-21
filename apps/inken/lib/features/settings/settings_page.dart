import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/logo.dart';
import '../../theme/theme_mode.dart';
import '../../theme/tokens.dart';
import '../ink/tool_options.dart';
import '../ink/tool_state.dart';
import '../viewer/app_menus.dart';
import '../viewer/home_intro.dart';
import '../viewer/idle_fade.dart';
import '../viewer/page_panel.dart';
import '../viewer/page_scrollbar.dart';
import '../viewer/quick_bar.dart';
import '../../theme/ui_scale.dart';
import 'app_info.dart';
import 'share_app.dart';
import 'language.dart';
import 'shortcuts.dart';

/// Ayarlar sayfasının bölümleri (soldaki sekmeler).
enum SettingsSection { appearance, input, shortcuts, about, info }

/// Ayarlar sayfasını açar. Belgeden bağımsız ayarların hepsi burada;
/// değişiklik anında uygulanır ve kalıcıdır ("Kaydet" yok). Esc ya da geri
/// düğmesi kapatır.
Future<void> openSettingsPage(
  BuildContext context, {
  SettingsSection initial = SettingsSection.appearance,
}) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(initial: initial)));

/// Geniş ekranda solda sekmeler, sağda içerik; dar ekranda sekmeler üstte
/// yatay.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initial = SettingsSection.appearance});

  final SettingsSection initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Sol sütunun gösterildiği en küçük genişlik.
const double _sidebarFrom = 720;
const double _sidebarWidth = 240;
const double _contentMaxWidth = 640;

class _SettingsPageState extends State<SettingsPage> {
  late SettingsSection _section = widget.initial;

  /// Başka bir sekmeye geçer (Hakkında → Uygulama bilgileri).
  void show(SettingsSection section) => setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= _sidebarFrom;

    final sections = [
      (
        SettingsSection.appearance,
        LucideIcons.palette,
        l10n.settingsAppearance,
      ),
      (SettingsSection.input, LucideIcons.penLine, l10n.settingsInput),
      (SettingsSection.shortcuts, LucideIcons.keyboard, l10n.settingsShortcuts),
      (SettingsSection.about, LucideIcons.info, l10n.settingsAbout),
      (SettingsSection.info, LucideIcons.clipboardList, l10n.settingsInfo),
    ];

    Widget tab((SettingsSection, IconData, String) s, {required bool row}) {
      final (section, icon, label) = s;
      final selected = section == _section;
      final color = selected ? c.brand : c.ink;
      return Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          key: ValueKey('settings-tab-${section.name}'),
          color: selected ? c.brandTint : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            hoverColor: c.surfaceHover,
            onTap: () => setState(() => _section = section),
            child: Container(
              height: Sizes.target,
              padding: const EdgeInsets.symmetric(horizontal: Space.s3),
              child: Row(
                mainAxisSize: row ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: Space.s3),
                  if (row)
                    Text(label, style: InkenText.menu.copyWith(color: color))
                  else
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InkenText.menu.copyWith(color: color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final content = SingleChildScrollView(
      key: ValueKey('settings-${_section.name}'),
      padding: const EdgeInsets.all(Space.s6),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: switch (_section) {
            SettingsSection.appearance => const _AppearanceSection(),
            SettingsSection.input => const _InputSection(),
            SettingsSection.shortcuts => const _ShortcutsSection(),
            SettingsSection.about => const _AboutSection(),
            SettingsSection.info => const _InfoSection(),
          },
        ),
      ),
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _sidebarWidth,
                padding: const EdgeInsets.all(Space.s3),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(right: BorderSide(color: c.line)),
                ),
                child: Column(
                  children: [
                    for (final s in sections) ...[
                      tab(s, row: false),
                      const SizedBox(height: Space.s1),
                    ],
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.line)),
                ),
                padding: const EdgeInsets.all(Space.s2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in sections) ...[
                        tab(s, row: true),
                        const SizedBox(width: Space.s1),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: content),
            ],
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.canvas,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: Sizes.appbarM,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('settings-close'),
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        icon: const Icon(LucideIcons.arrowLeft),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: Space.s2),
                      Text(
                        l10n.settings,
                        style: InkenText.heading.copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm içi başlık.
class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? 0 : Space.s6, bottom: Space.s3),
    child: Text(
      text,
      style: InkenText.label.copyWith(color: context.colors.inkMuted),
    ),
  );
}

/// Başlıklı ayar: etiket üstte, denetim altta.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s2),
          child: Text(
            label,
            style: InkenText.body.copyWith(color: context.colors.ink),
          ),
        ),
        child,
      ],
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String id;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: ValueKey('setting-$id'),
    contentPadding: EdgeInsets.zero,
    title: Text(
      label,
      style: InkenText.body.copyWith(color: context.colors.ink),
    ),
    value: value,
    onChanged: onChanged,
  );
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.settingsAppearance, first: true),
        _Labeled(
          label: l10n.theme,
          child: Segmented<ThemeMode>(
            key: const ValueKey('setting-theme'),
            value: ref.watch(themeModeProvider),
            onChanged: ref.read(themeModeProvider.notifier).set,
            options: [
              for (final (m, label) in themeChoices(l10n))
                (
                  m,
                  switch (m) {
                    ThemeMode.light => LucideIcons.sun,
                    ThemeMode.dark => LucideIcons.moon,
                    ThemeMode.system => LucideIcons.monitor,
                  },
                  label,
                ),
            ],
          ),
        ),
        _Labeled(
          label: l10n.uiScale,
          child: Segmented<UiScale>(
            key: const ValueKey('setting-ui-scale'),
            value: ref.watch(uiScaleProvider),
            onChanged: ref.read(uiScaleProvider.notifier).set,
            options: [
              for (final (s, label) in uiScaleChoices(l10n))
                (
                  s,
                  switch (s) {
                    UiScale.normal => LucideIcons.monitor,
                    UiScale.large => LucideIcons.zoomIn,
                    UiScale.larger => LucideIcons.presentation,
                  },
                  label,
                ),
            ],
          ),
        ),
        _Labeled(
          label: l10n.language,
          child: Segmented<AppLanguage>(
            key: const ValueKey('setting-language'),
            value: ref.watch(appLanguageProvider),
            onChanged: ref.read(appLanguageProvider.notifier).set,
            options: [
              for (final (language, label) in languageChoices(l10n))
                (
                  language,
                  language == AppLanguage.system
                      ? LucideIcons.monitor
                      : LucideIcons.languages,
                  label,
                ),
            ],
          ),
        ),
        _Labeled(
          label: l10n.toolDock,
          child: Segmented<DockEdge>(
            key: const ValueKey('setting-dock'),
            value: ref.watch(toolDockProvider),
            onChanged: ref.read(toolDockProvider.notifier).set,
            options: dockEdgeChoices(l10n),
          ),
        ),
        _Toggle(
          id: 'quick-bar',
          label: l10n.quickBar,
          value: ref.watch(quickBarProvider),
          onChanged: ref.read(quickBarProvider.notifier).set,
        ),
        _Toggle(
          id: 'page-panel',
          label: l10n.pagePanel,
          value: ref.watch(pagePanelProvider),
          onChanged: ref.read(pagePanelProvider.notifier).set,
        ),
        _Toggle(
          id: 'page-scrollbar',
          label: l10n.pageScrollbar,
          value: ref.watch(pageScrollbarProvider),
          onChanged: ref.read(pageScrollbarProvider.notifier).set,
        ),
        _Toggle(
          id: 'fade',
          label: l10n.fadeFloating,
          value: ref.watch(floatingFadeProvider),
          onChanged: ref.read(floatingFadeProvider.notifier).set,
        ),
        _Toggle(
          id: 'intro',
          label: l10n.introShowSetting,
          value: ref.watch(homeIntroProvider),
          onChanged: ref.read(homeIntroProvider.notifier).set,
        ),
      ],
    );
  }
}

class _InputSection extends ConsumerWidget {
  const _InputSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.inputMode, first: true),
        RadioGroup<InputMode>(
          groupValue: ref.watch(toolProvider.select((t) => t.inputMode)),
          onChanged: (m) => ref.read(toolProvider.notifier).setInputMode(m!),
          child: Column(
            children: [
              for (final (m, label) in [
                (InputMode.auto, l10n.inputModeAuto),
                (InputMode.pen, l10n.inputModePen),
                (InputMode.touch, l10n.inputModeTouch),
              ])
                RadioListTile<InputMode>(
                  key: ValueKey('setting-input-${m.name}'),
                  contentPadding: EdgeInsets.zero,
                  value: m,
                  title: Text(
                    label,
                    style: InkenText.body.copyWith(color: c.ink),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutsSection extends StatelessWidget {
  const _ShortcutsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final groups = shortcutGroups(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.shortcutsNote,
          style: InkenText.label.copyWith(color: c.inkMuted),
        ),
        for (final (title, rows) in groups) ...[
          _Heading(title),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                for (final (i, r) in rows.indexed)
                  Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s4,
                      vertical: Space.s2,
                    ),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.label,
                            style: InkenText.body.copyWith(color: c.ink),
                          ),
                        ),
                        const SizedBox(width: Space.s3),
                        _Keys(r.keys),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Tuş rozetleri: "Ctrl" "Shift" "S".
class _Keys extends StatelessWidget {
  const _Keys(this.keys);

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Space.s1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final k in keys)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: c.surfaceWell,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: c.line),
            ),
            child: Text(
              k,
              style: InkenText.caption.copyWith(
                color: c.ink,
                fontFamily: Fonts.mono,
              ),
            ),
          ),
      ],
    );
  }
}

/// Hakkında: logo, ad, sürüm, tanıtım, depo bağlantısı, lisanslar.
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final version = ref.watch(appVersionProvider).value;
    final versionText = versionLabel(l10n, version);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const InkenLogo(size: 56),
            const SizedBox(width: Space.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTitle,
                    style: InkenText.heading.copyWith(color: c.ink),
                  ),
                  Text(
                    l10n.homeTagline,
                    style: InkenText.label.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: Space.s1),
                  SelectableText(
                    l10n.aboutVersion(versionText),
                    key: const ValueKey('about-version'),
                    style: InkenText.numeric.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s6),
        Text(
          l10n.aboutDescription,
          style: InkenText.body.copyWith(color: c.ink),
        ),
        const SizedBox(height: Space.s6),
        // Depo bağlantısı: kaynak, sürümler, geri bildirim.
        Material(
          color: c.surfaceWell,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            key: const ValueKey('about-repository'),
            borderRadius: BorderRadius.circular(Radii.md),
            hoverColor: c.surfaceHover,
            onTap: () => _openRepository(context),
            child: Padding(
              padding: const EdgeInsets.all(Space.s3),
              child: Row(
                children: [
                  Icon(LucideIcons.gitBranch, color: c.ink),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aboutRepository,
                          style: InkenText.menu.copyWith(color: c.ink),
                        ),
                        Text(
                          l10n.aboutRepositoryHint,
                          style: InkenText.caption.copyWith(color: c.inkMuted),
                        ),
                        Text(
                          repositoryUrl,
                          style: InkenText.caption.copyWith(color: c.brand),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.externalLink, size: 18, color: c.inkMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s6),
        Text(
          l10n.aboutAppLicense,
          key: const ValueKey('about-app-license'),
          style: InkenText.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Space.s2),
        Text(
          l10n.aboutFonts,
          style: InkenText.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Space.s3),
        Wrap(
          spacing: Space.s3,
          runSpacing: Space.s3,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('about-share-app'),
              icon: const Icon(LucideIcons.share2, size: 18),
              label: Text(l10n.shareApp),
              onPressed: () => shareApp(context),
            ),
            OutlinedButton.icon(
              key: const ValueKey('about-licenses'),
              icon: const Icon(LucideIcons.scrollText, size: 18),
              label: Text(l10n.aboutLicenses),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: versionText,
                applicationLegalese: l10n.aboutAppLicense,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(Space.s3),
                  child: InkenLogo(size: 48),
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('about-info'),
              icon: const Icon(LucideIcons.clipboardList, size: 18),
              label: Text(l10n.settingsInfo),
              onPressed: () => context
                  .findAncestorStateOfType<_SettingsPageState>()
                  ?.show(SettingsSection.info),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _openRepository(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(repositoryUrl),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.linkOpenFailed(repositoryUrl))),
      );
    }
  }
}

/// Uygulama bilgileri: sürüm, platform, PDF motoru, kayıt formatı, veri
/// klasörü… Hata bildirirken "Kopyala" ile panoya alınır.
class _InfoSection extends ConsumerWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final rows = appInfoRows(
      l10n,
      version: ref.watch(appVersionProvider).value,
      dataFolder: ref.watch(dataFolderProvider).value,
      tools: ref.watch(toolProvider),
      screen: MediaQuery.sizeOf(context),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.infoIntro, style: InkenText.body.copyWith(color: c.ink)),
        const SizedBox(height: Space.s4),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceWell,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s3),
            child: Column(
              children: [
                for (final (i, (label, value)) in rows.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.s1),
                    child: _InfoRow(
                      label: Text(
                        label,
                        style: InkenText.label.copyWith(color: c.inkMuted),
                      ),
                      value: SelectableText(
                        value,
                        key: ValueKey('info-row-$i'),
                        style: InkenText.numeric.copyWith(
                          color: c.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s4),
        FilledButton.icon(
          key: const ValueKey('info-copy'),
          icon: const Icon(LucideIcons.copy, size: 18),
          label: Text(l10n.infoCopy),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(
              ClipboardData(text: appInfoText(l10n.appTitle, rows)),
            );
            messenger.showSnackBar(SnackBar(content: Text(l10n.infoCopied)));
          },
        ),
      ],
    );
  }
}

/// Bilgi satırı: genişte etiket solda sabit sütunda, darda değerin üstünde.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final Widget label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 560) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, value],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 200, child: label),
        Expanded(child: value),
      ],
    );
  }
}
