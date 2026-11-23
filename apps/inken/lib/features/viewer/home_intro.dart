import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../presentation/stage_cover.dart';
import '../ink/tool_options.dart';
import '../ink/tool_state.dart';
import '../settings/settings_store.dart';

/// Açılış ekranında tanıtım gösterilsin mi (Görünüm menüsü, "Gizle")?
class HomeIntroNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(settingsStoreProvider).get<bool>('homeIntro') ?? true;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('homeIntro', on);
  }
}

final homeIntroProvider = NotifierProvider<HomeIntroNotifier, bool>(
  HomeIntroNotifier.new,
);

/// Etkileşimsiz, soluk gösterim: açılış ekranındaki araç kutusu "vitrin"dir;
/// belge açılınca etkinleşir.
class Passive extends StatelessWidget {
  const Passive({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    enabled: false,
    child: IgnorePointer(
      child: Opacity(opacity: Opacities.passive, child: child),
    ),
  );
}

typedef _Feature = ({
  IconData icon,
  String title,
  String? keys,
  String body,
  Key key,
});

/// Uygulamanın tanıtımı: araçlar ve ders sırasında işe yarayanlar; her biri
/// ikon, ad, kısayol ve tek cümle.
class HomeIntro extends ConsumerWidget {
  const HomeIntro({super.key, required this.columns});

  /// Kart sütunu sayısı (genişliğe göre ekran belirler).
  final int columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    String title(Tool t) => toolLabel(l10n, t);
    String? key(Tool t) => toolShortcut(t);

    final tools = <_Feature>[
      (
        icon: toolIcon(Tool.pen),
        title: title(Tool.pen),
        keys: key(Tool.pen),
        body: l10n.introPen,
        key: const ValueKey('intro-pen'),
      ),
      (
        icon: toolIcon(Tool.highlighter),
        title: title(Tool.highlighter),
        keys: key(Tool.highlighter),
        body: l10n.introHighlighter,
        key: const ValueKey('intro-highlighter'),
      ),
      (
        icon: toolIcon(Tool.laser),
        title: title(Tool.laser),
        keys: key(Tool.laser),
        body: l10n.introLaser,
        key: const ValueKey('intro-laser'),
      ),
      (
        icon: toolIcon(Tool.eraser),
        title: title(Tool.eraser),
        keys: key(Tool.eraser),
        body: l10n.introEraser,
        key: const ValueKey('intro-eraser'),
      ),
      (
        icon: shapeIcon(ShapeKind.rectangle),
        title: title(Tool.shape),
        keys: key(Tool.shape),
        body: l10n.introShape,
        key: const ValueKey('intro-shape'),
      ),
      (
        icon: toolIcon(Tool.text),
        title: title(Tool.text),
        keys: key(Tool.text),
        body: l10n.introText,
        key: const ValueKey('intro-text'),
      ),
      (
        icon: LucideIcons.imagePlus,
        title: l10n.introImageTitle,
        keys: 'Ctrl+V',
        body: l10n.introImage,
        key: const ValueKey('intro-image'),
      ),
      (
        icon: toolIcon(Tool.select),
        title: title(Tool.select),
        keys: key(Tool.select),
        body: l10n.introSelect,
        key: const ValueKey('intro-select'),
      ),
      (
        icon: toolIcon(Tool.hand),
        title: title(Tool.hand),
        keys: l10n.keySpace,
        body: l10n.introHand,
        key: const ValueKey('intro-hand'),
      ),
      (
        icon: LucideIcons.undo2,
        title: '${l10n.undo} / ${l10n.redo}',
        keys: 'Ctrl+Z · Ctrl+Y',
        body: l10n.introUndo,
        key: const ValueKey('intro-undo'),
      ),
    ];
    final lesson = <_Feature>[
      (
        icon: LucideIcons.save,
        title: l10n.save,
        keys: 'Ctrl+S',
        body: l10n.introSave,
        key: const ValueKey('intro-save'),
      ),
      (
        icon: LucideIcons.fileDown,
        title: l10n.exportMenu,
        keys: null,
        body: l10n.introExport,
        key: const ValueKey('intro-export'),
      ),
      (
        icon: LucideIcons.lifeBuoy,
        title: l10n.introBackupTitle,
        keys: null,
        body: l10n.introBackup,
        key: const ValueKey('intro-backup'),
      ),
      (
        icon: LucideIcons.maximize,
        title: l10n.fullscreen,
        keys: 'F11',
        body: l10n.introFullscreen,
        key: const ValueKey('intro-fullscreen'),
      ),
      (
        icon: stageCoverIcon(StageCover.spotlight),
        title: l10n.spotlight,
        keys: 'S',
        body: l10n.introSpotlight,
        key: const ValueKey('intro-spotlight'),
      ),
      (
        icon: stageCoverIcon(StageCover.curtain),
        title: l10n.curtain,
        keys: 'C',
        body: l10n.introCurtain,
        key: const ValueKey('intro-curtain'),
      ),
      (
        icon: LucideIcons.bookOpen,
        title: l10n.introPagesTitle,
        keys: 'PgUp · PgDn · ${l10n.keySpace}',
        body: l10n.introPages,
        key: const ValueKey('intro-pages'),
      ),
    ];

    Widget section(String heading, List<_Feature> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: InkenText.fileName.copyWith(color: c.ink)),
        const SizedBox(height: Space.s3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w =
                (constraints.maxWidth - (columns - 1) * Space.s3) / columns;
            return Wrap(
              spacing: Space.s3,
              runSpacing: Space.s3,
              children: [
                for (final f in items)
                  SizedBox(
                    width: w,
                    child: _FeatureCard(key: f.key, feature: f),
                  ),
              ],
            );
          },
        ),
      ],
    );

    return Column(
      key: const ValueKey('home-intro'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.introTitle,
                    style: InkenText.heading.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: Space.s1),
                  Text(
                    l10n.introSubtitle,
                    style: InkenText.body.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('intro-hide'),
              onPressed: () => ref.read(homeIntroProvider.notifier).set(false),
              child: Text(l10n.introHide),
            ),
          ],
        ),
        const SizedBox(height: Space.s6),
        section(l10n.introToolsHeading, tools),
        const SizedBox(height: Space.s6),
        section(l10n.introLessonHeading, lesson),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({super.key, required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = feature;
    return Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.brandTint,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(f.icon, size: 22, color: c.brand),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Space.s2,
                  runSpacing: Space.s1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      f.title,
                      style: InkenText.button.copyWith(color: c.ink),
                    ),
                    if (f.keys != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceWell,
                          borderRadius: BorderRadius.circular(Radii.sm),
                          border: Border.all(color: c.line),
                        ),
                        child: Text(
                          f.keys!,
                          style: InkenText.caption.copyWith(
                            color: c.inkMuted,
                            fontFamily: Fonts.mono,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.s1),
                Text(
                  f.body,
                  style: InkenText.label.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
