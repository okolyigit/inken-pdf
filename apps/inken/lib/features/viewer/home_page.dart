import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/window_title.dart';
import '../../theme/dialog_actions.dart';
import '../../theme/logo.dart';
import '../../theme/tokens.dart';
import '../backup/backup_store.dart';
import '../files/document_io.dart';
import '../files/launch_file.dart';
import '../files/pdf_drop.dart';
import '../files/guide.dart';
import '../settings/settings_store.dart';
import '../files/open_document.dart';
import '../files/recent_documents.dart';
import '../ink/ink_toolbar.dart';
import '../ink/tool_options.dart';
import '../settings/settings_page.dart';
import 'app_menus.dart';
import 'home_intro.dart';
import 'quick_bar.dart';

/// Açılış ekranı: masaüstünde menü çubuğu (belge açmadan da ayarlara
/// ulaşılır), son açılan belgeler ve "PDF aç". Hiç belge açılmamışsa
/// karşılama (logo, slogan, tek düğme).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

enum _RecoveryChoice { restore, delete, later }

class _HomePageState extends ConsumerState<HomePage> {
  /// Kaydedilmemiş yedeği olan belgeler (yol → yedek).
  Map<String, InkenBackup> _backups = {};

  /// Yerinde bulunamayan son belgeler.
  final Set<String> _missing = {};

  StreamSubscription<void>? _arrivals;

  /// Dışarıdan açılması istenen dosya (bkz. [LaunchFile]); yoksa `null`.
  Future<RecentDocument?> _takeLaunch() async {
    try {
      return await ref.read(launchFileProvider).take();
    } on Object catch (e) {
      debugPrint('Gelen dosya alınamadı: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    // Başka bir uygulamadan "Birlikte aç" (Android, uygulama açıkken).
    _arrivals = ref.read(launchFileProvider).arrivals.listen((_) async {
      final file = await _takeLaunch();
      if (file != null && mounted) await _openRecent(file);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_checkMissing());
      await _loadBackups();
      // Bu arada bir belge açılmış olabilir (ekran ağaçtan kalktı).
      if (!mounted) return;
      // Bir PDF ile başlatıldıysa önce o açılır (yedeği varsa sorulur).
      final launch = await _takeLaunch();
      if (launch != null && mounted) {
        await _openRecent(launch);
        return;
      }
      // Yeni kurulum: kılavuz bir kez kendiliğinden açılır.
      if (takeFirstRunGuide(ref.read(settingsStoreProvider))) {
        await _openGuide();
        return;
      }
      await _offerRecovery();
    });
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && focused.widget is EditableText) return false;
    const newDoc = SingleActivator(LogicalKeyboardKey.keyN, control: true);
    if (newDoc.accepts(event, HardwareKeyboard.instance)) {
      unawaited(_newDocument());
      return true;
    }
    const open = SingleActivator(LogicalKeyboardKey.keyO, control: true);
    if (open.accepts(event, HardwareKeyboard.instance)) {
      unawaited(_open());
      return true;
    }
    const settings = SingleActivator(LogicalKeyboardKey.comma, control: true);
    if (settings.accepts(event, HardwareKeyboard.instance)) {
      _openSettings();
      return true;
    }
    return false;
  }

  Future<void> _loadBackups() async {
    try {
      final list = await ref.read(backupStoreProvider).list();
      if (!mounted) return;
      setState(() => _backups = {for (final b in list) b.sourcePath: b});
    } on Object catch (e) {
      debugPrint('Yedekler okunamadı: $e');
    }
  }

  Future<void> _checkMissing() async {
    final io = ref.read(documentIoProvider);
    for (final r in ref.read(recentDocumentsProvider)) {
      DocStat? stat;
      try {
        stat = await io.stat(r.location);
      } on Object {
        stat = null;
      }
      if (!mounted) return;
      if (stat == null) setState(() => _missing.add(r.location));
    }
  }

  /// Kaydedilmemiş bir yedek varsa geri yüklemeyi önerir (bu çalıştırmada
  /// sorulmamış en yeni yedek; diğerleri belge kapatılınca sırayla).
  Future<void> _offerRecovery() async {
    // Yedekler okunurken belge açılmış olabilir (ekran kapandı).
    if (!mounted) return;
    final store = ref.read(backupStoreProvider);
    final backup = _backups.values
        .where((b) => !store.offered.contains(b.sourcePath))
        .fold<InkenBackup?>(
          null,
          (a, b) => a == null || b.savedAt.isAfter(a.savedAt) ? b : a,
        );
    if (backup == null || !mounted) return;
    store.offered.add(backup.sourcePath);
    switch (await _askRecovery(backup)) {
      case _RecoveryChoice.restore:
        await _restore(backup);
      case _RecoveryChoice.delete:
        await _deleteBackup(backup);
        if (mounted) await _offerRecovery();
      case _RecoveryChoice.later || null:
        if (mounted) await _offerRecovery();
    }
  }

  /// Yedek için kullanıcıya sorar; dosyaya bakılamazsa `null`.
  Future<_RecoveryChoice?> _askRecovery(InkenBackup backup) async {
    final DocStat? stat;
    try {
      stat = await ref.read(documentIoProvider).stat(backup.sourcePath);
      if (!mounted) return null;
    } on Object catch (e) {
      debugPrint('Yedeğin dosyasına bakılamadı: $e');
      return null;
    }
    if (!mounted) return null;
    final exists = stat != null;
    final changed =
        stat != null &&
        !backup.matchesSource(length: stat.size, modified: stat.modified);
    final l10n = AppLocalizations.of(context);
    final when = _formatWhen(context, backup.savedAt);
    return showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.recoveryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exists
                  ? l10n.recoveryBody(backupDisplayName(backup), when)
                  : l10n.recoveryFileMissing(backupDisplayName(backup)),
            ),
            if (changed) ...[
              const SizedBox(height: 12),
              Text(l10n.recoveryFileChanged),
            ],
          ],
        ),
        actions: [
          DialogActions(
            cancel: (
              label: l10n.recoveryLater,
              onPressed: () => Navigator.pop(context, _RecoveryChoice.later),
            ),
            secondary: (
              label: l10n.recoveryDelete,
              onPressed: () => Navigator.pop(context, _RecoveryChoice.delete),
            ),
            primary: exists
                ? (
                    label: l10n.recoveryRestore,
                    onPressed: () =>
                        Navigator.pop(context, _RecoveryChoice.restore),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _restore(InkenBackup backup) => _guardOpen(() async {
    final images = await ref.read(backupStoreProvider).imagesFor(backup);
    await ref
        .read(openDocumentProvider.notifier)
        .restore(backup, images: images);
    return null;
  });

  Future<void> _deleteBackup(InkenBackup backup) async {
    await ref.read(backupStoreProvider).delete(backup.sourcePath);
    if (mounted) setState(() => _backups.remove(backup.sourcePath));
  }

  Future<void> _newDocument() => _guardOpen(
    () => ref
        .read(openDocumentProvider.notifier)
        .openNew(name: AppLocalizations.of(context).untitledDocument),
  );

  /// "Başlarken" kılavuzunu açar (Yardım menüsü, ilk kurulum).
  Future<void> _openGuide() {
    final l10n = AppLocalizations.of(context);
    return _guardOpen(() async {
      final guide = await loadGuide(l10n);
      await ref
          .read(openDocumentProvider.notifier)
          .openGuide(name: guide.name, bytes: guide.bytes);
      return null;
    });
  }

  Future<void> _open() => _guardOpen(
    () => ref
        .read(openDocumentProvider.notifier)
        .pickAndOpen(typeLabel: AppLocalizations.of(context).pdfFileType),
  );

  /// Son belgeyi açar. Kaydedilmemiş yedeği varsa önce onu sorar: geri
  /// yükle, yedeği sil ve aç, ya da yedeğe dokunmadan aç.
  Future<void> _openRecent(RecentDocument recent) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final backup = _backups[recent.location];
    if (backup != null) {
      switch (await _askRecovery(backup)) {
        case _RecoveryChoice.restore:
          await _restore(backup);
          return;
        case _RecoveryChoice.delete:
          await _deleteBackup(backup);
        case _RecoveryChoice.later:
          break;
        case null:
          return;
      }
      if (!mounted) return;
    }
    try {
      await ref.read(openDocumentProvider.notifier).openRecent(recent);
    } on OpenDocumentException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(openErrorMessage(l10n, e))),
      );
    } on Object {
      // Dosya taşınmış ya da silinmiş (ya da izni kalkmış).
      if (!mounted) return;
      setState(() => _missing.add(recent.location));
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.recentOpenFailed(recent.name)),
          action: SnackBarAction(
            label: l10n.recentRemove,
            onPressed: () => _remove(recent),
          ),
        ),
      );
    }
  }

  void _remove(RecentDocument recent) {
    ref.read(recentDocumentsProvider.notifier).remove(recent.location);
    setState(() => _missing.remove(recent.location));
  }

  /// Açma işlemini çalıştırır; hatayı kullanıcıya gösterir.
  Future<void> _guardOpen(Future<Object?> Function() open) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await open();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(openErrorMessage(l10n, e))),
      );
    }
  }

  void _openSettings() => openSettingsPage(context);

  /// Pencereye bırakılan PDF: son belge gibi açılır (yedeği varsa sorulur).
  Future<void> _openDropped(String path) => _openRecent(
    RecentDocument(
      location: path,
      name: displayNameOf(path, fallback: path),
      openedAt: DateTime.now(),
    ),
  );

  /// Hızlı erişim çubuğu: Aç ve Ayarlar çalışır, belgeye bağlılar pasif.
  Widget _quickBar({bool framed = true}) =>
      QuickBar(onOpen: _open, onSettings: _openSettings, framed: framed);

  /// Uygulamanın tam menüsü; belgeye bağlı komutlar pasif.
  List<Widget> _menus(List<RecentDocument> recents, {ButtonStyle? barStyle}) {
    final l10n = AppLocalizations.of(context);
    return appMenus(
      context,
      ref,
      barStyle: barStyle,
      onNew: _newDocument,
      onOpen: _open,
      onSettings: _openSettings,
      onGuide: _openGuide,
      // Araçlar belge açılınca seçilir (araç kutusu da burada pasif).
      onSelectTool: null,
      fileExtras: [
        if (recents.isNotEmpty)
          SubmenuButton(
            leadingIcon: const Icon(LucideIcons200.history),
            menuChildren: [
              for (final r in recents.take(8))
                MenuItemButton(
                  onPressed: () => _openRecent(r),
                  child: Text(r.name),
                ),
            ],
            child: Text(l10n.recentTitle),
          ),
      ],
    );
  }

  /// Tablet ve telefonda üst çubuk: menüleri açan logo (belge ekranındaki
  /// gibi) ve ad. Karşılama ekranında ad zaten ortada.
  Widget _compactBar(List<RecentDocument> recents, {required bool tablet}) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      height: Sizes.appbarM,
      padding: const EdgeInsets.symmetric(horizontal: Space.s2),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          MenuAnchor(
            menuChildren: _menus(recents),
            builder: (context, menu, _) => IconButton(
              key: const ValueKey('app-menu'),
              tooltip: l10n.menu,
              icon: const InkenLogo(size: 32),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
          if (tablet && ref.watch(quickBarProvider))
            Expanded(child: _quickBar(framed: false))
          else if (recents.isNotEmpty) ...[
            const SizedBox(width: Space.s1),
            Text(
              l10n.appTitle,
              style: InkenText.fileName.copyWith(color: c.ink),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    WindowTitle.set(l10n.appTitle);
    final recents = ref.watch(recentDocumentsProvider);
    final layout = InkenLayout.of(context);
    final desktop = layout == InkenLayout.desktop;
    final phone = layout == InkenLayout.phone;
    final dockEdge = ref.watch(toolDockProvider);
    // Yüzen araç kutusunun kapladığı şerit: içerik altına girmesin.
    const dockBand = Sizes.tool + 2 * (Space.s1 + 2) + 2 * Space.s3;
    final dockInset = phone
        ? EdgeInsets.zero
        : switch (dockEdge) {
            DockEdge.top => const EdgeInsets.only(top: dockBand),
            DockEdge.bottom => const EdgeInsets.only(bottom: dockBand),
            DockEdge.left => const EdgeInsets.only(left: dockBand),
            DockEdge.right => const EdgeInsets.only(right: dockBand),
          };

    final openButton = FilledButton.icon(
      key: const ValueKey('home-open'),
      onPressed: _open,
      icon: const Icon(LucideIcons200.folderOpen),
      label: Text(l10n.openPdf),
      style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
    );

    final showIntro = ref.watch(homeIntroProvider);

    final hero = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const InkenLogo(size: 96),
        const SizedBox(height: Space.s6),
        Text(l10n.appTitle, style: InkenText.display.copyWith(color: c.ink)),
        const SizedBox(height: Space.s2),
        Text(
          l10n.homeTagline,
          style: InkenText.body.copyWith(color: c.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.s8),
        SizedBox(width: 200, child: openButton),
      ],
    );

    final Widget content;
    if (recents.isEmpty && !showIntro) {
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.s6).add(dockInset),
          child: hero,
        ),
      );
    } else {
      content = LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          final pad = narrow ? Space.s4 : Space.s8;
          final inner = math.min(constraints.maxWidth - 2 * pad, 1040.0);
          // Telefonda iki sütun; geniş ekranda sabit kart genişliği.
          final cardWidth = narrow ? (inner - Space.s4) / 2 : 176.0;
          final columns = inner >= 900
              ? 3
              : inner >= 560
              ? 2
              : 1;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              pad,
              Space.s6,
              pad,
              Space.s8,
            ).add(dockInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recents.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.s6,
                          ),
                          child: hero,
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.recentTitle,
                              style: InkenText.heading.copyWith(color: c.ink),
                            ),
                          ),
                          openButton,
                        ],
                      ),
                      const SizedBox(height: Space.s6),
                      Wrap(
                        spacing: Space.s4,
                        runSpacing: Space.s6,
                        children: [
                          for (final r in recents)
                            SizedBox(
                              width: cardWidth,
                              child: _RecentCard(
                                key: ValueKey('recent-${r.location}'),
                                recent: r,
                                missing: _missing.contains(r.location),
                                unsaved: _backups.containsKey(r.location),
                                onOpen: () => _openRecent(r),
                                onRemove: () => _remove(r),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (showIntro) ...[
                      const SizedBox(height: Space.s8 + Space.s4),
                      HomeIntro(columns: columns),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Belge ekranındaki araç kutusu burada vitrin: görünür ama pasif;
    // belge açılınca etkinleşir.
    const dock = Passive(child: ToolDock(session: null));
    return PdfDropTarget(
      onPdf: _openDropped,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (desktop)
                DecoratedBox(
                  decoration: BoxDecoration(color: c.surface),
                  child: Column(
                    children: [
                      AppMenuBar(
                        menus: (style) => _menus(recents, barStyle: style),
                      ),
                      if (ref.watch(quickBarProvider)) _quickBar(),
                    ],
                  ),
                )
              else
                _compactBar(recents, tablet: !phone),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: content),
                    if (!phone) dockPositioned(dockEdge, dock),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bugün 14:32", "Dün 09:10" ya da "12 Kas 2026 14:32".
String _formatWhen(BuildContext context, DateTime at) {
  final l10n = AppLocalizations.of(context);
  final material = MaterialLocalizations.of(context);
  final local = at.toLocal();
  final time = material.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: true,
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.recentToday(time);
  if (diff == 1) return l10n.recentYesterday(time);
  return '${material.formatMediumDate(local)} $time';
}

/// Son belge kartı: ilk sayfanın küçük resmi, ad, ne zaman açıldığı, sayfa
/// sayısı. Kaydedilmemiş yedeği varsa rozet; dosya yerinde değilse soluk.
class _RecentCard extends ConsumerStatefulWidget {
  const _RecentCard({
    super.key,
    required this.recent,
    required this.missing,
    required this.unsaved,
    required this.onOpen,
    required this.onRemove,
  });

  final RecentDocument recent;
  final bool missing;
  final bool unsaved;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  ConsumerState<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends ConsumerState<_RecentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final r = widget.recent;
    final file = ref.read(recentStoreProvider).thumbnailFile(r.location);
    ref.watch(recentDocumentsProvider); // küçük resim yenilenince
    final details = [
      _formatWhen(context, r.openedAt),
      if (r.pageCount != null) l10n.recentPages(r.pageCount!),
    ].join(' · ');

    final thumbnail = AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: c.canvas,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: _hovered ? c.lineStrong : c.line),
          boxShadow: _hovered ? c.shadowPop : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null)
              Image.file(
                file,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _placeholder(c),
              )
            else
              _placeholder(c),
            if (widget.unsaved)
              Positioned(
                left: Space.s2,
                bottom: Space.s2,
                right: Space.s2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      l10n.recentUnsaved,
                      style: InkenText.caption.copyWith(color: c.onAccent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: Space.s1,
              right: Space.s1,
              child: MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('recent-remove'),
                    leadingIcon: const Icon(LucideIcons200.x),
                    onPressed: widget.onRemove,
                    child: Text(l10n.recentRemove),
                  ),
                ],
                builder: (context, menu, _) => IconButton(
                  tooltip: l10n.menu,
                  style: IconButton.styleFrom(
                    backgroundColor: c.surfaceRaised.withValues(alpha: 0.9),
                  ),
                  icon: Icon(
                    LucideIcons200.ellipsisVertical,
                    size: 18,
                    color: c.inkMuted,
                  ),
                  onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      label: r.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: Opacity(
            opacity: widget.missing ? 0.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail,
                const SizedBox(height: Space.s2),
                Text(
                  r.name,
                  style: InkenText.label.copyWith(
                    color: c.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.missing ? l10n.recentMissing : details,
                  style: InkenText.caption.copyWith(color: c.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(InkenColors c) => ColoredBox(
    color: c.surfaceRaised,
    child: Center(
      child: Icon(LucideIcons200.fileText, size: 40, color: c.inkFaint),
    ),
  );
}

/// Dosya açılamadığında gösterilecek metin.
String openErrorMessage(AppLocalizations l10n, Object error) => switch (error) {
  OpenDocumentException(failure: OpenFailure.newerFormat) =>
    l10n.openNewerFormat,
  OpenDocumentException(failure: OpenFailure.corruptData) =>
    l10n.openCorruptData,
  OpenDocumentException(failure: OpenFailure.pageMismatch) =>
    l10n.openPageMismatch,
  PdfPasswordRequired() => l10n.passwordNeeded,
  _ => l10n.openPdfFailed(error.toString()),
};
