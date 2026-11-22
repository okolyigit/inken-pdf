import 'package:flutter/material.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'open_document.dart';

/// Belge özellikleri penceresi (Dosya → Belge özellikleri…, Ctrl+D):
/// dosyanın adı, yeri, boyutu; PDF'in bilgi sözlüğü (başlık, yazar…),
/// sürümü ve güvenliği; sayfa sayısı ve geçerli sayfanın boyutu.
///
/// Sayfa bilgileri açık belgenin modelinden gelir (eklenen / silinen
/// sayfalar dahil); PDF bilgileri dosyanın kendisinden.
Future<void> showDocumentProperties(
  BuildContext context, {
  required OpenDocument document,
  required int pageCount,
  PageLayer? currentPage,
}) => showDialog<void>(
  context: context,
  builder: (context) => DocumentPropertiesDialog(
    document: document,
    pageCount: pageCount,
    currentPage: currentPage,
    info: loadPdfInfo(document.bytes, password: document.password),
  ),
);

class DocumentPropertiesDialog extends StatelessWidget {
  const DocumentPropertiesDialog({
    super.key,
    required this.document,
    required this.pageCount,
    required this.currentPage,
    required this.info,
  });

  final OpenDocument document;
  final int pageCount;
  final PageLayer? currentPage;
  final Future<PdfInfo> info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey('properties-dialog'),
      icon: Icon(LucideIcons.fileText, color: context.colors.inkMuted),
      title: Text(l10n.propertiesTitle),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<PdfInfo>(
          future: info,
          builder: (context, snap) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _sections(context, l10n, snap),
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('properties-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  List<Widget> _sections(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<PdfInfo> snap,
  ) {
    final locale = l10n.localeName;
    final page = currentPage;
    final fileRows = <(String, String)>[
      (l10n.propFile, document.name),
      (l10n.propLocation, document.path ?? l10n.propNotSaved),
      (l10n.propFileSize, formatFileSize(document.bytes.length, locale)),
      (l10n.propPages, '$pageCount'),
      if (page != null)
        (l10n.propPageSize, describePageSize(l10n, page.width, page.height)),
    ];
    final i = snap.data;
    final Widget docPart;
    if (i != null) {
      String date(DateTime? d) =>
          d == null ? '' : DateFormat.yMMMMd(locale).add_Hm().format(d);
      docPart = _Rows(
        rows: [
          (l10n.propTitle, i.title),
          (l10n.propAuthor, i.author),
          (l10n.propSubject, i.subject),
          (l10n.propKeywords, i.keywords),
          (l10n.propCreator, i.creator),
          (l10n.propProducer, i.producer),
          (l10n.propCreated, date(i.created)),
          (l10n.propModified, date(i.modified)),
          (l10n.propVersion, i.version ?? ''),
          (
            l10n.propSecurity,
            [
              if (i.encrypted) l10n.propPasswordProtected,
              if (i.signed) l10n.propSigned,
            ].join(', ').ifEmpty(l10n.propNoSecurity),
          ),
        ],
      );
    } else if (snap.hasError) {
      docPart = Text(
        l10n.propUnreadable,
        key: const ValueKey('properties-error'),
        style: InkenText.body.copyWith(color: context.colors.danger),
      );
    } else {
      docPart = const Padding(
        padding: EdgeInsets.all(Space.s4),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return [
      _Heading(l10n.propSectionFile),
      _Rows(rows: fileRows),
      const SizedBox(height: Space.s4),
      _Heading(l10n.propSectionDocument),
      docPart,
    ];
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// "1,4 MB", "820 KB", "512 B".
String formatFileSize(int bytes, String locale) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${NumberFormat('#,##0', locale).format(bytes / 1024)} KB';
  }
  return '${NumberFormat('#,##0.0', locale).format(bytes / (1024 * 1024))} MB';
}

/// "210 × 297 mm (A4, Dikey)"; bilinmeyen boyutta yalnızca yön.
String describePageSize(AppLocalizations l10n, double width, double height) {
  final orientation = width > height
      ? l10n.orientationLandscape
      : l10n.orientationPortrait;
  final paper = paperSizeName(width, height);
  return '${ptToMm(width)} × ${ptToMm(height)} mm '
      '(${paper == null ? orientation : '$paper, $orientation'})';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s2),
    child: Text(
      text,
      style: InkenText.label.copyWith(color: context.colors.inkMuted),
    ),
  );
}

/// Etiket / değer satırları; boş değer "—". Değerler seçilip kopyalanabilir.
/// Genişte etiket solda sabit sütunda; darda (telefon) etiket küçük ve
/// soluk olarak üstte, değer altında.
class _Rows extends StatelessWidget {
  const _Rows({required this.rows});
  final List<(String, String)> rows;

  /// Bu genişliğin altında etiket değerin üstüne geçer.
  static const double stackBelow = 420;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < stackBelow;
        Widget value(String v) => SelectableText(
          v.isEmpty ? '—' : v,
          style: InkenText.body.copyWith(color: v.isEmpty ? c.inkFaint : c.ink),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, v) in rows)
              if (stacked)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: InkenText.caption.copyWith(color: c.inkMuted),
                      ),
                      const SizedBox(height: 2),
                      value(v),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          label,
                          style: InkenText.body.copyWith(color: c.inkMuted),
                        ),
                      ),
                      Expanded(child: value(v)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}
