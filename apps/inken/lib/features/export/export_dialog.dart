import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart' show ImageEncoding;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/dialog_form.dart';
import '../../theme/tokens.dart';
import '../ink/tool_options.dart' show Segmented, colorNames;
import '../ink/tool_state.dart';
import '../settings/settings_store.dart';

/// Dışa aktarma penceresinde seçilenler.
typedef ExportChoice = ({
  ExportFormat format,

  /// Dışa aktarılacak sayfalar (0'dan, sırayla).
  List<int> pages,

  /// Görselde dosya türü, çözünürlük ve gri tonlama.
  ImageEncoding encoding,
  int dpi,
  bool grayscale,

  /// Dışa aktarılmayan renkler (`0xRRGGBB`) ve görseller (öğrenci kopyası).
  Set<int> hiddenColors,
  bool hideImages,
});

/// [page] sayfasının önizlemesi (PNG; çizimleri gömülü); [grayscale] gri
/// tonlamalı; [hiddenColors] / [hideImages] gizlenmiş.
typedef RenderExportPreview = Future<Uint8List> Function(
  int page, {
  required bool grayscale,
  required Set<int> hiddenColors,
  required bool hideImages,
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
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
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
  late ImageEncoding encoding = _pick(
    'encoding',
    ImageEncoding.values,
    ImageEncoding.png,
  );
  late int dpi = switch (_saved['dpi']) {
    final int d when exportDpis.contains(d) => d,
    _ => defaultExportDpi,
  };
  final _range = TextEditingController();

  /// Önizlenen sayfanın seçilen sayfalardaki sırası.
  int previewAt = 0;

  /// Gizlenen renkler (`0xRRGGBB`) ve görseller; hatırlanmaz (bir sonraki
  /// dışa aktarmada çizimler fark edilmeden eksik çıkmasın).
  Set<int> hiddenColors = {};
  bool hideImages = false;

  /// Önizlemeler: anahtar (sayfa, gri, gizlenenler) → PNG.
  final Map<String, Future<Uint8List>> _previews = {};

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
    final hidden = {...hiddenColors};
    final key =
        '$page|$gray|$hideImages|${(hidden.toList()..sort()).join(',')}';
    return _previews[key] ??= widget.renderPreview(
      page,
      grayscale: gray,
      hiddenColors: hidden,
      hideImages: hideImages,
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
  void setEncoding(ImageEncoding v) => setState(() => encoding = v);
  void toggleColor(int rgb) => setState(() {
    hiddenColors = {...hiddenColors};
    if (!hiddenColors.remove(rgb)) hiddenColors.add(rgb);
  });
  void toggleImages() => setState(() => hideImages = !hideImages);

  /// Seçilen sayfalarda kullanılan renkler (gizlenmişler dahil).
  List<int> get colors => usedColors(widget.document, pages ?? const []);

  /// Seçilen sayfalarda görsel var mı?
  bool get images => hasImages(widget.document, pages ?? const []);

  /// Seçilen sayfalarda gerçekten gizlenen renkler.
  Set<int> get _effectiveHidden => colors.toSet().intersection(hiddenColors);
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
      'encoding': encoding.name,
    });
    Navigator.pop<ExportChoice>(context, (
      format: format,
      pages: list,
      encoding: encoding,
      dpi: dpi,
      grayscale: grayscale,
      hiddenColors: _effectiveHidden,
      hideImages: hideImages && images,
    ));
  }

  String _summary(AppLocalizations l10n) {
    final count = pages?.length ?? 0;
    final what = switch (format) {
      ExportFormat.flattened => l10n.exportFormatFlattened,
      ExportFormat.editable => l10n.exportFormatEditable,
      ExportFormat.images => [
        _encodingName(encoding),
        l10n.dpiLabel(dpi),
        if (count > 1) l10n.exportSummaryZip,
      ].join(' · '),
    };
    final hidden = _effectiveHidden.length;
    return [
      l10n.exportSummary(count, what),
      if (hidden > 0) l10n.exportHiddenColors(hidden),
      if (hideImages && images) l10n.exportHiddenImages,
    ].join(' · ');
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
      padding: const EdgeInsets.fromLTRB(
        Space.s6,
        Space.s4,
        Space.s4,
        Space.s4,
      ),
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
          const SizedBox(height: Space.s3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 9, child: preview),
                const SizedBox(width: Space.s6),
                Expanded(
                  flex: 10,
                  child: SingleChildScrollView(child: settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s3),
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
    final list = state.pages;
    final images = state.format == ExportFormat.images;
    final phone = state.widget.phone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRow(
          label: l10n.exportFormat,
          hint: switch (state.format) {
            ExportFormat.flattened => l10n.exportFormatFlattenedHint,
            ExportFormat.editable => l10n.exportFormatEditableHint,
            ExportFormat.images => l10n.exportFormatImagesHint,
          },
          child: Segmented<ExportFormat>(
            dense: true,
            value: state.format,
            onChanged: state.setFormat,
            options: [
              (
                ExportFormat.flattened,
                phone ? null : LucideIcons.fileCheck,
                l10n.exportFormatFlattenedShort,
              ),
              (
                ExportFormat.editable,
                phone ? null : LucideIcons.filePen,
                l10n.exportFormatEditableShort,
              ),
              (
                ExportFormat.images,
                phone ? null : LucideIcons.fileImage,
                l10n.exportFormatImages,
              ),
            ],
          ),
        ),
        if (images) ...[
          FormRow(
            label: l10n.exportFileType,
            hint: l10n.exportFileTypeHint,
            child: Segmented<ImageEncoding>(
              key: const ValueKey('export-encoding'),
              dense: true,
              value: state.encoding,
              onChanged: state.setEncoding,
              options: [
                for (final e in ImageEncoding.values)
                  (e, null, _encodingName(e)),
              ],
            ),
          ),
          FormRow(
            label: l10n.exportResolution,
            hint: l10n.exportResolutionHint,
            child: Segmented<int>(
              key: const ValueKey('export-dpi'),
              dense: true,
              value: state.dpi,
              onChanged: state.setDpi,
              options: [
                for (final d in exportDpis) (d, null, l10n.dpiLabel(d)),
              ],
            ),
          ),
          FormRow(
            label: l10n.exportGray,
            child: FormSwitch(
              key: const ValueKey('export-gray'),
              value: state.grayscale,
              onChanged: state.setGrayscale,
            ),
          ),
        ],
        if (state.colors.isNotEmpty || state.images)
          FormRow(
            label: l10n.exportHide,
            hint: l10n.exportHideHint,
            child: Wrap(
              key: const ValueKey('export-hide'),
              spacing: Space.s1,
              runSpacing: Space.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final rgb in state.colors)
                  _HideToggle(
                    key: ValueKey('export-hide-${rgb.toRadixString(16)}'),
                    label: l10n.exportHideColor(_colorName(l10n, rgb)),
                    hidden: state.hiddenColors.contains(rgb),
                    onTap: () => state.toggleColor(rgb),
                    color: Color(0xFF000000 | rgb),
                  ),
                if (state.images)
                  _HideToggle(
                    key: const ValueKey('export-hide-images'),
                    label: l10n.exportHideImages,
                    hidden: state.hideImages,
                    onTap: state.toggleImages,
                    icon: LucideIcons.image,
                    text: l10n.exportHideImages,
                  ),
              ],
            ),
          ),
        FormRow(
          label: l10n.exportPages,
          hint: state.pageSet == ExportPageSet.drawn
              ? l10n.exportPagesDrawnHint
              : null,
          below: state.pageSet == ExportPageSet.range
              ? Padding(
                  padding: const EdgeInsets.only(bottom: Space.s1),
                  child: TextField(
                    key: const ValueKey('export-range'),
                    controller: state._range,
                    autofocus: true,
                    style: InkenText.numeric.copyWith(color: c.ink),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,;\-– ]')),
                    ],
                    decoration: denseFieldDecoration.copyWith(
                      hintText: l10n.printRangeHint,
                      errorText:
                          state._range.text.trim().isNotEmpty && list == null
                          ? l10n.printRangeInvalid(
                              state.widget.document.pages.length,
                            )
                          : null,
                    ),
                    onChanged: (_) => state.setPageSet(ExportPageSet.range),
                  ),
                )
              : null,
          child: Segmented<ExportPageSet>(
            key: const ValueKey('export-pages'),
            dense: true,
            value: state.pageSet,
            onChanged: state.setPageSet,
            options: [
              (ExportPageSet.all, null, l10n.exportPagesAll),
              (ExportPageSet.current, null, l10n.exportPagesCurrent),
              (ExportPageSet.drawn, null, l10n.exportPagesDrawn),
              (ExportPageSet.range, null, l10n.exportPagesRange),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: phone ? 0 : FormRow.labelWidth + Space.s2,
          ),
          child: FormCheck(
            key: const ValueKey('export-skip-blank'),
            label: l10n.exportSkipBlank,
            value: state.skipBlank,
            onChanged: state.setSkipBlank,
          ),
        ),
      ],
    );
  }
}

String _encodingName(ImageEncoding e) => switch (e) {
  ImageEncoding.png => 'PNG',
  ImageEncoding.jpeg => 'JPEG',
};

/// Rengin adı: kalem, fosforlu ya da geçici kalem paletindeyse adı, değilse
/// `#RRGGBB`.
String _colorName(AppLocalizations l10n, int rgb) {
  for (final (tool, palette) in [
    (Tool.pen, penColors),
    (Tool.highlighter, highlighterColors),
    (Tool.laser, laserColors),
  ]) {
    final i = palette.indexWhere((c) => c & 0xFFFFFF == rgb);
    if (i >= 0) return colorNames(l10n, tool)[i];
  }
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Gizle / göster düğmesi: renk yuvarlağı (ya da ikonlu etiket). Gizliyken
/// soluk, göz ikonlu (etikette üstü çizili), çevresinde halka: durum
/// yalnızca renkle gösterilmez. Dokunma alanı 48 px.
class _HideToggle extends StatelessWidget {
  const _HideToggle({
    super.key,
    required this.label,
    required this.hidden,
    required this.onTap,
    this.color,
    this.icon,
    this.text,
  });

  final String label;
  final bool hidden;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final swatch = color;
    final Widget body;
    if (swatch != null) {
      body = SizedBox.square(
        dimension: 26,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: hidden ? 0.3 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x73808080)),
                  ),
                ),
              ),
            ),
            if (hidden) Icon(LucideIcons.eyeOff, size: 16, color: c.ink),
          ],
        ),
      );
    } else {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hidden ? LucideIcons.eyeOff : icon,
            size: 18,
            color: hidden ? c.ink : c.inkMuted,
          ),
          const SizedBox(width: Space.s2),
          Text(
            text ?? label,
            style: InkenText.menu.copyWith(
              color: hidden ? c.inkMuted : c.ink,
              decoration: hidden ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      );
    }
    final round = swatch != null;
    return Semantics(
      button: true,
      toggled: hidden,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: round
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
          child: Container(
            width: round ? 36 : null,
            height: 36,
            padding: round
                ? null
                : const EdgeInsets.symmetric(horizontal: Space.s3),
            alignment: round ? Alignment.center : null,
            decoration: BoxDecoration(
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: round ? null : BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: hidden ? c.ink : const Color(0x00000000),
                width: 2,
              ),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
