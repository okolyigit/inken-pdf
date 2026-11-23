import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../ink/tool_options.dart' show Segmented;
import '../settings/settings_store.dart';

/// Dışa aktarma penceresinde seçilenler.
typedef ExportChoice = ({
  ExportFormat format,

  /// Dışa aktarılacak sayfalar (0'dan, sırayla).
  List<int> pages,

  /// Görselde çözünürlük ve gri tonlama.
  int dpi,
  bool grayscale,
});

/// [page] sayfasının önizlemesi (PNG; çizimleri gömülü); [grayscale] gri
/// tonlamalı.
typedef RenderExportPreview = Future<Uint8List> Function(
  int page, {
  required bool grayscale,
});

/// Inken'in dışa aktarma penceresi (yazdırma penceresinin düzeninde):
/// solda önizleme, sağda biçim, sayfalar ve görsel seçenekleri, altta
/// özet ve Dışa aktar. Telefonda tam ekran. Dışa aktar'a basılırsa
/// seçilenler, vazgeçilirse `null`. Seçimler hatırlanır (sayfa aralığı
/// hariç).
Future<ExportChoice?> showExportDialog(
  BuildContext context, {
  required InkenDocument document,
  required int currentPage,
  required RenderExportPreview renderPreview,
  required SettingsStore settings,
}) {
  final phone = InkenLayout.of(context) == InkenLayout.phone;
  return showDialog<ExportChoice>(
    context: context,
    builder: (context) {
      final dialog = ExportDialog(
        document: document,
        currentPage: currentPage,
        renderPreview: renderPreview,
        settings: settings,
        phone: phone,
      );
      if (phone) return Dialog.fullscreen(child: dialog);
      return Dialog(
        insetPadding: const EdgeInsets.all(Space.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 680),
          child: dialog,
        ),
      );
    },
  );
}

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.document,
    required this.currentPage,
    required this.renderPreview,
    required this.settings,
    this.phone = false,
  });

  final InkenDocument document;
  final int currentPage;
  final RenderExportPreview renderPreview;
  final SettingsStore settings;
  final bool phone;

  @override
  State<ExportDialog> createState() => ExportDialogState();
}

@visibleForTesting
class ExportDialogState extends State<ExportDialog> {
  static const _key = 'export';

  late final Map<String, Object?> _saved = {
    ...?widget.settings.get<Map<String, Object?>>(_key),
  };

  T _pick<T extends Enum>(String key, List<T> values, T fallback) {
    final v = _saved[key];
    return values.where((e) => e.name == v).firstOrNull ?? fallback;
  }

  bool _flag(String key, bool fallback) => switch (_saved[key]) {
    final bool b => b,
    _ => fallback,
  };

  late ExportFormat format = _pick(
    'format',
    ExportFormat.values,
    ExportFormat.flattened,
  );

  /// "Aralık" hatırlanmaz (belgeye özgü); hatırlanan aralıksa "Tümü".
  late ExportPageSet pageSet = switch (_pick(
    'pages',
    ExportPageSet.values,
    ExportPageSet.all,
  )) {
    ExportPageSet.range => ExportPageSet.all,
    final p => p,
  };
  late bool skipBlank = _flag('skipBlank', false);
  late bool grayscale = _flag('grayscale', false);
  late int dpi = switch (_saved['dpi']) {
    final int d when exportDpis.contains(d) => d,
    _ => defaultExportDpi,
  };
  final _range = TextEditingController();

  /// Önizlenen sayfanın seçilen sayfalardaki sırası.
  int previewAt = 0;

  /// Önizlemeler: (sayfa, gri) → PNG.
  final Map<(int, bool), Future<Uint8List>> _previews = {};

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  /// Dışa aktarılacak sayfalar; geçersiz aralıkta `null`.
  List<int>? get pages => selectExportPages(
    widget.document,
    pageSet,
    current: widget.currentPage,
    range: _range.text,
    skipBlankInserted: skipBlank,
  );

  bool get canExport => pages?.isNotEmpty ?? false;

  /// Önizlemeye gri tonlama uygulanır mı (yalnızca görselde).
  bool get _grayPreview => format == ExportFormat.images && grayscale;

  int? get previewPage {
    final list = pages;
    if (list == null || list.isEmpty) return null;
    return list[previewAt.clamp(0, list.length - 1)];
  }

  Future<Uint8List>? _preview() {
    final page = previewPage;
    if (page == null) return null;
    final gray = _grayPreview;
    return _previews[(page, gray)] ??= widget.renderPreview(
      page,
      grayscale: gray,
    );
  }

  void setFormat(ExportFormat v) => setState(() => format = v);
  void setPageSet(ExportPageSet v) => setState(() {
    pageSet = v;
    previewAt = 0;
  });
  void setSkipBlank(bool v) => setState(() {
    skipBlank = v;
    previewAt = 0;
  });
  void setGrayscale(bool v) => setState(() => grayscale = v);
  void setDpi(int v) => setState(() => dpi = v);
  void showPage(int at) => setState(() => previewAt = at);

  void _submit() {
    final list = pages;
    if (list == null || list.isEmpty) return;
    widget.settings.put(_key, {
      'format': format.name,
      'pages': pageSet.name,
      'skipBlank': skipBlank,
      'grayscale': grayscale,
      'dpi': dpi,
    });
    Navigator.pop<ExportChoice>(context, (
      format: format,
      pages: list,
      dpi: dpi,
      grayscale: grayscale,
    ));
  }

  String _summary(AppLocalizations l10n) {
    final count = pages?.length ?? 0;
    final what = switch (format) {
      ExportFormat.flattened => l10n.exportFormatFlattened,
      ExportFormat.editable => l10n.exportFormatEditable,
      ExportFormat.images => [
        'PNG',
        l10n.dpiLabel(dpi),
        if (count > 1) l10n.exportSummaryZip,
      ].join(' · '),
    };
    return l10n.exportSummary(count, what);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final preview = _Preview(state: this);
    final settings = _Settings(state: this);
    final submit = FilledButton.icon(
      key: const ValueKey('export-submit'),
      icon: const Icon(LucideIcons.fileDown, size: 18),
      label: Text(l10n.exportTitle),
      onPressed: canExport ? _submit : null,
    );
    final summary = Text(
      _summary(l10n),
      key: const ValueKey('export-summary'),
      style: InkenText.label.copyWith(color: c.inkMuted),
    );

    if (widget.phone) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: IconButton(
            key: const ValueKey('export-cancel'),
            tooltip: l10n.cancel,
            icon: const Icon(LucideIcons.x),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(l10n.exportTitle),
        ),
        body: Column(
          children: [
            Expanded(child: preview),
            Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: c.line),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.s4,
                      Space.s3,
                      Space.s4,
                      Space.s4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(child: SingleChildScrollView(child: settings)),
                        const SizedBox(height: Space.s3),
                        summary,
                        const SizedBox(height: Space.s2),
                        SizedBox(height: Sizes.target, child: submit),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(Space.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileDown, color: c.inkMuted),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Text(
                  l10n.exportTitle,
                  style: InkenText.heading.copyWith(color: c.ink),
                ),
              ),
              IconButton(
                key: const ValueKey('export-close'),
                tooltip: l10n.cancel,
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Space.s4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 10, child: preview),
                const SizedBox(width: Space.s6),
                Expanded(
                  flex: 8,
                  child: SingleChildScrollView(child: settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s4),
          Row(
            children: [
              Expanded(child: summary),
              TextButton(
                key: const ValueKey('export-cancel'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: Space.s2),
              submit,
            ],
          ),
        ],
      ),
    );
  }
}

/// Seçilen sayfaların önizlemesi; altında sayfa gezgini.
class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final ExportDialogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final list = state.pages ?? const <int>[];
    final at = state.previewAt.clamp(0, list.isEmpty ? 0 : list.length - 1);
    final page = state.previewPage;
    final layer = page == null ? null : state.widget.document.pages[page];
    final future = state._preview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              state.widget.phone ? 0 : Radii.lg,
            ),
            child: ColoredBox(
              color: state.widget.phone ? c.canvas : c.surfaceWell,
              child: Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Center(
                  child: layer == null || future == null
                      ? Text(
                          l10n.exportNoPages,
                          key: const ValueKey('export-no-pages'),
                          textAlign: TextAlign.center,
                          style: InkenText.body.copyWith(color: c.inkMuted),
                        )
                      : AspectRatio(
                          aspectRatio: layer.width / layer.height,
                          child: Semantics(
                            image: true,
                            label: l10n.printPreviewLabel(page! + 1),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFFFFF),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x80000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FutureBuilder<Uint8List>(
                                future: future,
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return Center(
                                      child: Text(
                                        '${snap.error}',
                                        style: InkenText.caption.copyWith(
                                          color: c.danger,
                                        ),
                                      ),
                                    );
                                  }
                                  final png = snap.data;
                                  if (png == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return Image.memory(
                                    png,
                                    key: const ValueKey('export-preview-image'),
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.medium,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.s2),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: state.widget.phone ? Space.s4 : 0,
          ),
          child: Row(
            children: [
              IconButton.outlined(
                key: const ValueKey('export-prev'),
                tooltip: l10n.printPrevPage,
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                onPressed: at > 0 ? () => state.showPage(at - 1) : null,
              ),
              const SizedBox(width: Space.s2),
              Text(
                list.isEmpty ? '–' : '${at + 1} / ${list.length}',
                key: const ValueKey('export-position'),
                style: InkenText.numeric.copyWith(color: c.ink),
              ),
              const SizedBox(width: Space.s2),
              IconButton.outlined(
                key: const ValueKey('export-next'),
                tooltip: l10n.printNextPage,
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                onPressed: at < list.length - 1
                    ? () => state.showPage(at + 1)
                    : null,
              ),
              const Spacer(),
              if (page != null)
                Text(
                  l10n.exportPageOf(page + 1),
                  style: InkenText.caption.copyWith(color: c.inkMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.state});

  final ExportDialogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Text(
        text,
        style: InkenText.label.copyWith(
          color: c.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.s1),
      child: Text(text, style: InkenText.caption.copyWith(color: c.inkMuted)),
    );
    const gap = SizedBox(height: Space.s4);
    final list = state.pages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(l10n.exportFormat),
        for (final (format, icon, title, text) in [
          (
            ExportFormat.flattened,
            LucideIcons.fileCheck,
            l10n.exportFormatFlattened,
            l10n.exportFormatFlattenedHint,
          ),
          (
            ExportFormat.editable,
            LucideIcons.filePen,
            l10n.exportFormatEditable,
            l10n.exportFormatEditableHint,
          ),
          (
            ExportFormat.images,
            LucideIcons.fileImage,
            l10n.exportFormatImages,
            l10n.exportFormatImagesHint,
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s2),
            child: _FormatOption(
              key: ValueKey('export-format-${format.name}'),
              icon: icon,
              title: title,
              hint: text,
              selected: state.format == format,
              onTap: () => state.setFormat(format),
            ),
          ),
        if (state.format == ExportFormat.images) ...[
          const SizedBox(height: Space.s2),
          label(l10n.exportResolution),
          Segmented<int>(
            key: const ValueKey('export-dpi'),
            value: state.dpi,
            onChanged: state.setDpi,
            options: [for (final d in exportDpis) (d, null, l10n.dpiLabel(d))],
          ),
          hint(l10n.exportResolutionHint),
          SwitchListTile(
            key: const ValueKey('export-gray'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.exportGray),
            value: state.grayscale,
            onChanged: state.setGrayscale,
          ),
        ],
        gap,
        label(l10n.exportPages),
        Segmented<ExportPageSet>(
          key: const ValueKey('export-pages'),
          value: state.pageSet,
          onChanged: state.setPageSet,
          options: [
            (ExportPageSet.all, null, l10n.exportPagesAll),
            (ExportPageSet.current, null, l10n.exportPagesCurrent),
            (ExportPageSet.drawn, null, l10n.exportPagesDrawn),
            (ExportPageSet.range, null, l10n.exportPagesRange),
          ],
        ),
        if (state.pageSet == ExportPageSet.drawn)
          hint(l10n.exportPagesDrawnHint),
        if (state.pageSet == ExportPageSet.range) ...[
          const SizedBox(height: Space.s2),
          TextField(
            key: const ValueKey('export-range'),
            controller: state._range,
            autofocus: true,
            style: InkenText.numeric.copyWith(color: c.ink),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,;\-– ]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.printRangeHint,
              border: const OutlineInputBorder(),
              errorText: state._range.text.trim().isNotEmpty && list == null
                  ? l10n.printRangeInvalid(state.widget.document.pages.length)
                  : null,
            ),
            onChanged: (_) => state.setPageSet(ExportPageSet.range),
          ),
        ],
        CheckboxListTile(
          key: const ValueKey('export-skip-blank'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.exportSkipBlank),
          value: state.skipBlank,
          onChanged: (v) => state.setSkipBlank(v ?? false),
        ),
      ],
    );
  }
}

/// Biçim seçeneği: ikon, ad ve kısa açıklama; seçiliyken marka renginde
/// halka ve zemin (seçim yalnızca renkle gösterilmez: halka + onay).
class _FormatOption extends StatelessWidget {
  const _FormatOption({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.brandTint : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: selected ? c.brand : c.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.target),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s3,
                vertical: Space.s2,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: selected ? c.brand : c.inkMuted),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: InkenText.menu.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          hint,
                          style: InkenText.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: Space.s2),
                    Icon(LucideIcons.circleCheck, size: 20, color: c.brand),
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
