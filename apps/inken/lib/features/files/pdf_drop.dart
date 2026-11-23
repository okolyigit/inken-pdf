import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'document_io.dart' show isImageFile;

/// Pencereye sürüklenip bırakılan PDF'i açar (masaüstü). Dosya pencerenin
/// üzerindeyken "PDF'i bırak" katmanı görünür. Birden çok dosya
/// bırakılırsa ilk PDF açılır; PDF yoksa kullanıcıya söylenir.
///
/// [onImage] verilirse (belge açıkken) görsel dosyası da kabul edilir:
/// PDF yoksa ilk görsel sayfaya eklenir.
class PdfDropTarget extends StatefulWidget {
  const PdfDropTarget({
    super.key,
    required this.onPdf,
    this.onImage,
    required this.child,
  });

  /// Bırakılan PDF'in yolu.
  final ValueChanged<String> onPdf;

  /// Bırakılan görsel dosyasının yolu.
  final ValueChanged<String>? onImage;
  final Widget child;

  @override
  State<PdfDropTarget> createState() => _PdfDropTargetState();
}

/// [paths] içinden ilk PDF (uzantıya göre, büyük / küçük harf fark etmez).
String? firstPdf(Iterable<String> paths) {
  for (final p in paths) {
    if (p.toLowerCase().endsWith('.pdf')) return p;
  }
  return null;
}

class _PdfDropTargetState extends State<PdfDropTarget> {
  bool _over = false;

  void _dropped(List<String> paths) {
    setState(() => _over = false);
    final pdf = firstPdf(paths);
    if (pdf != null) {
      widget.onPdf(pdf);
      return;
    }
    final onImage = widget.onImage;
    if (onImage != null) {
      for (final p in paths) {
        if (isImageFile(p)) return onImage(p);
      }
    }
    if (paths.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          onImage == null ? l10n.dropOnlyPdf : l10n.dropOnlyPdfOrImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (d) => _dropped([for (final f in d.files) f.path]),
      child: Stack(
        children: [
          widget.child,
          if (_over)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('pdf-drop-overlay'),
                  margin: const EdgeInsets.all(Space.s3),
                  decoration: BoxDecoration(
                    color: c.brandTint.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.brand, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons200.fileDown, size: 48, color: c.brand),
                        const SizedBox(height: Space.s3),
                        Text(
                          widget.onImage == null
                              ? l10n.dropPdfHere
                              : l10n.dropPdfOrImageHere,
                          style: InkenText.heading.copyWith(color: c.brand),
                        ),
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
}
