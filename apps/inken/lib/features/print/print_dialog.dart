import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/print_service.dart';
import '../../theme/dialog_form.dart';
import '../../theme/tokens.dart';
import '../ink/tool_options.dart' show Segmented;
import '../settings/settings_store.dart';

/// Yazdırma penceresinde seçilenler: istek ve çizimlerin basılıp
/// basılmayacağı (hangi PDF'in yazdırılacağı).
typedef PrintChoice = ({PrintRequest request, bool drawings});

/// Yazdırılacak PDF'i hazırlar: çizimli ya da çizimsiz kopya, dosya yolu.
typedef PreparePrintPdf = Future<String> Function({required bool drawings});

/// Hangi sayfalar.
enum PrintPages { all, current, range }

/// Inken'in yazdırma penceresi: önizleme, yazıcı, kopya, sayfalar, boyut,
/// çizimler ve açılır kapanır "Diğer seçenekler". Telefonda tam ekran.
/// Yazdır'a basılırsa seçilenler, vazgeçilirse `null`.
Future<PrintChoice?> showPrintDialog(
  BuildContext context, {
  required int pageCount,
  required int currentPage,
  required PreparePrintPdf preparePdf,
  required PrintService service,
  required SettingsStore settings,
}) {
  final phone = InkenLayout.of(context) == InkenLayout.phone;
  return showDialog<PrintChoice>(
    context: context,
    builder: (context) {
      final dialog = PrintDialog(
        pageCount: pageCount,
        currentPage: currentPage,
        preparePdf: preparePdf,
        service: service,
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

class PrintDialog extends StatefulWidget {
  const PrintDialog({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.preparePdf,
    required this.service,
    required this.settings,
    this.phone = false,
  });

  final int pageCount;
  final int currentPage;
  final PreparePrintPdf preparePdf;
  final PrintService service;
  final SettingsStore settings;
  final bool phone;

  @override
  State<PrintDialog> createState() => PrintDialogState();
}

@visibleForTesting
class PrintDialogState extends State<PrintDialog> {
  static const _key = 'print';

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

  List<PrinterInfo> _printers = const [];
  bool _loadingPrinters = true;
  String? _printer;
  int copies = 1;
  PrintPages pagesMode = PrintPages.all;
  final _range = TextEditingController();
  late bool fit = _flag('fit', true);
  late bool drawings = _flag('drawings', true);
  late bool more = _flag('more', false);
  late bool grayscale = _flag('grayscale', false);
  late bool collate = _flag('collate', true);
  bool reverse = false;
  late PrintDuplex duplex = _pick(
    'duplex',
    PrintDuplex.values,
    PrintDuplex.off,
  );
  late PaperSize paper = _pick('paper', PaperSize.values, PaperSize.a4);
  late PrintOrientation orientation = _pick(
    'orientation',
    PrintOrientation.values,
    PrintOrientation.auto,
  );

  /// Önizlenen sayfanın seçilen sayfalardaki sırası.
  int previewAt = 0;

  /// Önizleme: hazırlanan PDF'ler (çizimli / çizimsiz) ve açık çizici.
  final Map<bool, Future<String>> _pdfs = {};
  PdfPrintRasterizer? _raster;
  String? _rasterPath;
  ui.Image? _preview;
  String? _previewKey;
  int _renderToken = 0;
  bool _preparing = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
    _refreshPreview();
  }

  @override
  void dispose() {
    _range.dispose();
    _preview?.dispose();
    final raster = _raster;
    if (raster != null) unawaited(raster.dispose());
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    if (!widget.service.choosesPrinter) {
      setState(() => _loadingPrinters = false);
      return;
    }
    List<PrinterInfo> list;
    try {
      list = await widget.service.printers();
    } on Object catch (e) {
      debugPrint('Yazıcılar alınamadı: $e');
      list = const [];
    }
    if (!mounted) return;
    final saved = _saved['printer'];
    setState(() {
      _printers = list;
      _loadingPrinters = false;
      _printer =
          list.where((p) => p.name == saved).firstOrNull?.name ??
          list.where((p) => p.isDefault).firstOrNull?.name ??
          list.firstOrNull?.name;
    });
  }

  // ---- seçimler

  /// Basılacak sayfalar (0'dan); geçersiz aralıkta `null`.
  List<int>? get pages => switch (pagesMode) {
    PrintPages.all => [for (var i = 0; i < widget.pageCount; i++) i],
    PrintPages.current => [widget.currentPage.clamp(0, widget.pageCount - 1)],
    PrintPages.range => parsePageRanges(_range.text, widget.pageCount),
  };

  String? get printer => _printer;

  bool get canPrint =>
      (pages?.isNotEmpty ?? false) &&
      (!widget.service.choosesPrinter || _printer != null);

  PrintRequest request() => PrintRequest(
    pages: pages ?? const [],
    pageCount: widget.pageCount,
    printer: widget.service.choosesPrinter ? _printer : null,
    copies: copies,
    collate: collate,
    reverse: reverse,
    fit: fit,
    grayscale: grayscale,
    duplex: duplex,
    paper: paper,
    orientation: orientation,
  );

  void _set(VoidCallback change) {
    setState(change);
    _refreshPreview();
  }

  void setPagesMode(PrintPages mode) => _set(() {
    pagesMode = mode;
    previewAt = 0;
  });

  void setCopies(int n) => setState(() => copies = n.clamp(1, 99));
  void setFit(bool v) => _set(() => fit = v);
  void setDrawings(bool v) => _set(() => drawings = v);
  void setGrayscale(bool v) => _set(() => grayscale = v);
  void setPaper(PaperSize v) => _set(() => paper = v);
  void setOrientation(PrintOrientation v) => _set(() => orientation = v);
  void showPage(int at) => _set(() => previewAt = at);

  void _submit() {
    if (!canPrint) return;
    widget.settings.put(_key, {
      'printer': ?_printer,
      'fit': fit,
      'drawings': drawings,
      'more': more,
      'grayscale': grayscale,
      'collate': collate,
      'duplex': duplex.name,
      'paper': paper.name,
      'orientation': orientation.name,
    });
    Navigator.pop<PrintChoice>(context, (
      request: request(),
      drawings: drawings,
    ));
  }

  // ---- önizleme

  /// Önizlemede kâğıt (pt, yönlendirilmiş).
  ({double width, double height}) get _paperPt =>
      orientedPaper(paper.widthPt, paper.heightPt, orientation);

  /// Yazıcının basamadığı kenar payı (önizlemede yaklaşık, pt).
  static const _marginPt = 12.0;

  PagePlacement _placement(({double width, double height}) page) {
    final p = _paperPt;
    return placeOnPaper(
      pageWidth: page.width,
      pageHeight: page.height,
      paperWidth: p.width,
      paperHeight: p.height,
      unitsPerPt: 1,
      fit: fit || !widget.service.choosesPrinter,
      orientation: orientation,
      area: (
        x: _marginPt,
        y: _marginPt,
        width: p.width - 2 * _marginPt,
        height: p.height - 2 * _marginPt,
      ),
    );
  }

  int? get previewPage {
    final list = pages;
    if (list == null || list.isEmpty) return null;
    return list[previewAt.clamp(0, list.length - 1)];
  }

  Future<void> _refreshPreview() async {
    final token = ++_renderToken;
    final page = previewPage;
    try {
      final path = await (_pdfs[drawings] ??= widget.preparePdf(
        drawings: drawings,
      ));
      if (!mounted || token != _renderToken) return;
      if (_rasterPath != path) {
        final old = _raster;
        _raster = null;
        _rasterPath = null;
        if (old != null) await old.dispose();
        final raster = await PdfPrintRasterizer.open(
          await File(path).readAsBytes(),
        );
        if (!mounted || token != _renderToken) {
          await raster.dispose();
          return;
        }
        _raster = raster;
        _rasterPath = path;
      }
      final raster = _raster!;
      if (page == null || page >= raster.pageCount) {
        setState(() => _preparing = false);
        return;
      }
      final place = _placement(raster.pageSize(page));
      final key =
          '$path|$page|$fit|$grayscale|${paper.name}|'
          '${orientation.name}';
      if (key == _previewKey) {
        setState(() => _preparing = false);
        return;
      }
      // Önizleme kâğıdın uzun kenarı ~1200 piksel olacak çözünürlükte.
      final p = _paperPt;
      final scale = 1200 / (p.width > p.height ? p.width : p.height);
      final r = await raster.renderSized(
        page,
        (place.width * scale).round(),
        (place.height * scale).round(),
        rotate: place.rotate,
        grayscale: grayscale,
      );
      final image = await _decode(r);
      if (!mounted || token != _renderToken) {
        image.dispose();
        return;
      }
      setState(() {
        _preview?.dispose();
        _preview = image;
        _previewKey = key;
        _preparing = false;
        _error = null;
      });
    } on Object catch (e) {
      debugPrint('Yazdırma önizlemesi: $e');
      if (mounted && token == _renderToken) {
        setState(() {
          _error = e;
          _preparing = false;
        });
      }
    }
  }

  static Future<ui.Image> _decode(PrintRaster r) {
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      r.bgra,
      r.width,
      r.height,
      ui.PixelFormat.bgra8888,
      done.complete,
    );
    return done.future;
  }

  // ---- görünüm

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final count = pages?.length ?? 0;
    final preview = _Preview(state: this);
    final settings = _Settings(state: this);
    final printLabel = widget.service.choosesPrinter
        ? l10n.printTitle
        : '${l10n.printContinue} · ${l10n.printSummary(count, copies).split(' · ').first}';
    final printButton = FilledButton.icon(
      key: const ValueKey('print-submit'),
      icon: Icon(
        widget.service.choosesPrinter
            ? LucideIcons200.printer
            : LucideIcons200.chevronRight,
        size: 18,
      ),
      label: Text(printLabel),
      onPressed: canPrint ? _submit : null,
    );

    if (widget.phone) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: IconButton(
            key: const ValueKey('print-cancel'),
            tooltip: l10n.cancel,
            icon: const Icon(LucideIcons200.x),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(l10n.printTitle),
        ),
        body: Column(
          children: [
            Expanded(child: preview),
            // Material: anahtar satırının dokunma izi zeminin altında
            // kalmasın.
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
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
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
                        SizedBox(height: Sizes.target, child: printButton),
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
              Icon(LucideIcons200.printer, color: c.inkMuted),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Text(
                  l10n.printTitle,
                  style: InkenText.heading.copyWith(color: c.ink),
                ),
              ),
              IconButton(
                key: const ValueKey('print-close'),
                tooltip: l10n.cancel,
                icon: const Icon(LucideIcons200.x),
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
              Expanded(
                child: Text(
                  l10n.printSummary(count, copies),
                  key: const ValueKey('print-summary'),
                  style: InkenText.label.copyWith(color: c.inkMuted),
                ),
              ),
              TextButton(
                key: const ValueKey('print-cancel'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: Space.s2),
              printButton,
            ],
          ),
        ],
      ),
    );
  }
}

/// Kâğıt üzerinde sayfa; altında sayfa gezgini ve kâğıt bilgisi.
class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final PrintDialogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final list = state.pages ?? const <int>[];
    final at = state.previewAt.clamp(0, list.isEmpty ? 0 : list.length - 1);
    final paper = state._paperPt;
    final raster = state._raster;
    final page = state.previewPage;
    final image = state._preview;
    final placement = raster == null || page == null || page >= raster.pageCount
        ? null
        : state._placement(raster.pageSize(page));
    final landscape = paper.width > paper.height;
    final mm = state.paper;

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
                  child: AspectRatio(
                    aspectRatio: paper.width / paper.height,
                    child: Semantics(
                      image: true,
                      label: page == null
                          ? null
                          : l10n.printPreviewLabel(page + 1),
                      child: DecoratedBox(
                        key: const ValueKey('print-paper'),
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
                        child: LayoutBuilder(
                          builder: (context, box) {
                            if (state._preparing && image == null) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (image == null || placement == null) {
                              return const SizedBox.expand();
                            }
                            final s = box.maxWidth / paper.width;
                            return ClipRect(
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: placement.x * s,
                                    top: placement.y * s,
                                    width: placement.width * s,
                                    height: placement.height * s,
                                    child: RawImage(
                                      key: const ValueKey(
                                        'print-preview-image',
                                      ),
                                      image: image,
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ],
                              ),
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
                key: const ValueKey('print-prev'),
                tooltip: l10n.printPrevPage,
                icon: const Icon(LucideIcons200.chevronLeft, size: 18),
                onPressed: at > 0 ? () => state.showPage(at - 1) : null,
              ),
              const SizedBox(width: Space.s2),
              Text(
                list.isEmpty ? '–' : '${at + 1} / ${list.length}',
                key: const ValueKey('print-position'),
                style: InkenText.numeric.copyWith(color: c.ink),
              ),
              const SizedBox(width: Space.s2),
              IconButton.outlined(
                key: const ValueKey('print-next'),
                tooltip: l10n.printNextPage,
                icon: const Icon(LucideIcons200.chevronRight, size: 18),
                onPressed: at < list.length - 1
                    ? () => state.showPage(at + 1)
                    : null,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '${_paperName(mm)} · ${_mm(mm.widthMm)} × ${_mm(mm.heightMm)} mm · '
                  '${landscape ? l10n.printLandscape : l10n.printPortrait}',
                  overflow: TextOverflow.ellipsis,
                  style: InkenText.caption.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
        ),
        if (state._error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s2),
            child: Text(
              '${state._error}',
              style: InkenText.caption.copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}

String _paperName(PaperSize p) => switch (p) {
  PaperSize.a4 => 'A4',
  PaperSize.a3 => 'A3',
  PaperSize.a5 => 'A5',
  PaperSize.letter => 'Letter',
  PaperSize.legal => 'Legal',
};

String _mm(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

class _Settings extends StatelessWidget {
  const _Settings({required this.state});

  final PrintDialogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final service = state.widget.service;
    final full = service.choosesPrinter;

    final printers = state._printers;
    final selected = printers.where((p) => p.name == state.printer).firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (full) ...[
          FormRow(
            label: l10n.printPrinter,
            hint:
                selected != null &&
                    (selected.isDefault || selected.status != null)
                ? [
                    ?selected.status,
                    if (selected.isDefault) l10n.printDefaultPrinter,
                  ].join(' · ')
                : null,
            child: state._loadingPrinters
                ? const LinearProgressIndicator()
                : printers.isEmpty
                ? Text(
                    l10n.printNoPrinter,
                    key: const ValueKey('print-no-printer'),
                    style: InkenText.body.copyWith(color: c.danger),
                  )
                : DropdownButtonFormField<String>(
                    key: const ValueKey('print-printer'),
                    initialValue: state.printer,
                    isExpanded: true,
                    isDense: true,
                    style: InkenText.menu.copyWith(color: c.ink),
                    decoration: denseFieldDecoration,
                    items: [
                      for (final p in printers)
                        DropdownMenuItem(
                          value: p.name,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) =>
                        // ignore: invalid_use_of_protected_member
                        state.setState(() => state._printer = v),
                  ),
          ),
          FormRow(
            label: l10n.printCopies,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('print-copies-down'),
                  tooltip: l10n.printDecrease,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons200.minus, size: 18),
                  onPressed: state.copies > 1
                      ? () => state.setCopies(state.copies - 1)
                      : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${state.copies}',
                    key: const ValueKey('print-copies'),
                    textAlign: TextAlign.center,
                    style: InkenText.numeric.copyWith(color: c.ink),
                  ),
                ),
                IconButton(
                  key: const ValueKey('print-copies-up'),
                  tooltip: l10n.printIncrease,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons200.plus, size: 18),
                  onPressed: state.copies < 99
                      ? () => state.setCopies(state.copies + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
        FormRow(
          label: l10n.printPages,
          below: state.pagesMode == PrintPages.range
              ? Padding(
                  padding: const EdgeInsets.only(bottom: Space.s1),
                  child: TextField(
                    key: const ValueKey('print-range'),
                    controller: state._range,
                    autofocus: true,
                    style: InkenText.numeric.copyWith(color: c.ink),
                    decoration: denseFieldDecoration.copyWith(
                      hintText: l10n.printRangeHint,
                      errorText:
                          state._range.text.trim().isNotEmpty &&
                              state.pages == null
                          ? l10n.printRangeInvalid(state.widget.pageCount)
                          : null,
                    ),
                    onChanged: (_) => state.setPagesMode(PrintPages.range),
                  ),
                )
              : null,
          child: Segmented<PrintPages>(
            dense: true,
            value: state.pagesMode,
            onChanged: state.setPagesMode,
            options: [
              (PrintPages.all, null, l10n.printPagesAll),
              (PrintPages.current, null, l10n.printPagesCurrentShort),
              (PrintPages.range, null, l10n.printPagesRange),
            ],
          ),
        ),
        if (full)
          FormRow(
            label: l10n.printSize,
            child: Segmented<bool>(
              dense: true,
              value: state.fit,
              onChanged: state.setFit,
              options: [
                (true, null, l10n.printFit),
                (false, null, l10n.printActual),
              ],
            ),
          ),
        FormRow(
          label: l10n.printDrawings,
          child: FormSwitch(
            key: const ValueKey('print-drawings'),
            value: state.drawings,
            onChanged: state.setDrawings,
          ),
        ),
        if (!full)
          Text(
            l10n.printAndroidHint,
            style: InkenText.caption.copyWith(color: c.inkMuted),
          ),
        if (full) ...[
          Divider(height: Space.s3, color: c.line),
          _MoreOptions(state: state),
        ],
      ],
    );
  }
}

/// "Diğer seçenekler": başta kapalı; açık / kapalı hatırlanır.
class _MoreOptions extends StatelessWidget {
  const _MoreOptions({required this.state});

  final PrintDialogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    void update(VoidCallback f) =>
        // ignore: invalid_use_of_protected_member
        state.setState(f);

    final summary = [
      state.grayscale ? l10n.printGray : l10n.printColorOn,
      state.duplex == PrintDuplex.off
          ? '${l10n.printDuplex}: ${l10n.printDuplexOff}'
          : l10n.printDuplex,
      _paperName(state.paper),
      switch (state.orientation) {
        PrintOrientation.auto => l10n.printOrientationAuto,
        PrintOrientation.portrait => l10n.printPortrait,
        PrintOrientation.landscape => l10n.printLandscape,
      },
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const ValueKey('print-more'),
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => update(() => state.more = !state.more),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: FormRow.height),
            child: Row(
              children: [
                Icon(
                  LucideIcons200.slidersHorizontal,
                  size: 18,
                  color: c.inkMuted,
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.printMore,
                        style: InkenText.menu.copyWith(color: c.ink),
                      ),
                      if (!state.more)
                        Text(
                          summary,
                          style: InkenText.caption.copyWith(color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
                Icon(
                  state.more
                      ? LucideIcons200.chevronUp
                      : LucideIcons200.chevronDown,
                  size: 18,
                  color: c.inkMuted,
                ),
              ],
            ),
          ),
        ),
        if (state.more) ...[
          const SizedBox(height: Space.s1),
          FormRow(
            label: l10n.printColor,
            child: Segmented<bool>(
              dense: true,
              value: state.grayscale,
              onChanged: state.setGrayscale,
              options: [
                (false, null, l10n.printColorOn),
                (true, null, l10n.printGray),
              ],
            ),
          ),
          FormRow(
            label: l10n.printDuplex,
            child: DropdownButtonFormField<PrintDuplex>(
              key: const ValueKey('print-duplex'),
              initialValue: state.duplex,
              isExpanded: true,
              isDense: true,
              style: InkenText.menu.copyWith(color: c.ink),
              decoration: denseFieldDecoration,
              items: [
                DropdownMenuItem(
                  value: PrintDuplex.off,
                  child: Text(l10n.printDuplexOff),
                ),
                DropdownMenuItem(
                  value: PrintDuplex.longEdge,
                  child: Text(l10n.printDuplexLong),
                ),
                DropdownMenuItem(
                  value: PrintDuplex.shortEdge,
                  child: Text(l10n.printDuplexShort),
                ),
              ],
              onChanged: (v) =>
                  update(() => state.duplex = v ?? PrintDuplex.off),
            ),
          ),
          FormRow(
            label: l10n.printPaper,
            child: DropdownButtonFormField<PaperSize>(
              key: const ValueKey('print-paper-size'),
              initialValue: state.paper,
              isExpanded: true,
              isDense: true,
              style: InkenText.menu.copyWith(color: c.ink),
              decoration: denseFieldDecoration,
              items: [
                for (final p in PaperSize.values)
                  DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${_paperName(p)} (${_mm(p.widthMm)} × ${_mm(p.heightMm)} mm)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => state.setPaper(v ?? PaperSize.a4),
            ),
          ),
          FormRow(
            label: l10n.printOrientation,
            hint: l10n.printOrientationHint,
            child: Segmented<PrintOrientation>(
              dense: true,
              value: state.orientation,
              onChanged: state.setOrientation,
              options: [
                (PrintOrientation.auto, null, l10n.printOrientationAuto),
                (PrintOrientation.portrait, null, l10n.printPortrait),
                (PrintOrientation.landscape, null, l10n.printLandscape),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FormCheck(
                  key: const ValueKey('print-collate'),
                  label: l10n.printCollate,
                  value: state.collate,
                  onChanged: (v) => update(() => state.collate = v),
                ),
              ),
              Expanded(
                child: FormCheck(
                  key: const ValueKey('print-reverse'),
                  label: l10n.printReverse,
                  value: state.reverse,
                  onChanged: (v) => update(() => state.reverse = v),
                ),
              ),
            ],
          ),
          if (state.widget.service.hasPrinterProperties &&
              state.printer != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: l10n.printPropertiesHint,
                child: TextButton.icon(
                  key: const ValueKey('print-properties'),
                  icon: const Icon(LucideIcons200.printer, size: 18),
                  label: Text(l10n.printProperties),
                  onPressed: () =>
                      state.widget.service.printerProperties(state.printer!),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
