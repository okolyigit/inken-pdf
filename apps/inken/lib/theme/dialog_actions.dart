import 'package:flutter/material.dart';

import 'tokens.dart';

/// Diyalog düğmesi: etiket ve işlev.
typedef DialogAction = ({String label, VoidCallback onPressed});

/// Üç seçenekli diyalogların düğmeleri (ör. Vazgeç / Kaydetme / Kaydet).
/// Genişte tek sırada, sağa yaslı: vazgeç, ikinci seçenek (metin düğmesi),
/// ana iş (dolu). Telefonda tam genişlikte alt alta: ana iş üstte, ikinci
/// seçenek çerçeveli, en altta vazgeç. `AlertDialog.actions`'a tek öğe
/// olarak verilir: `actions: [DialogActions(...)]`.
class DialogActions extends StatelessWidget {
  const DialogActions({
    super.key,
    required this.cancel,
    required this.secondary,
    this.primary,
  });

  final DialogAction cancel;
  final DialogAction secondary;

  /// `null` ise ana iş yok (ör. geri yüklenecek dosya bulunamadı).
  final DialogAction? primary;

  @override
  Widget build(BuildContext context) {
    final phone = InkenLayout.of(context) == InkenLayout.phone;
    final cancelButton = TextButton(
      key: const ValueKey('dialog-cancel'),
      onPressed: cancel.onPressed,
      child: Text(cancel.label),
    );
    final secondaryButton = phone
        ? OutlinedButton(
            key: const ValueKey('dialog-secondary'),
            onPressed: secondary.onPressed,
            child: Text(secondary.label),
          )
        : TextButton(
            key: const ValueKey('dialog-secondary'),
            onPressed: secondary.onPressed,
            child: Text(secondary.label),
          );
    final primaryButton = switch (primary) {
      final p? => FilledButton(
        key: const ValueKey('dialog-primary'),
        onPressed: p.onPressed,
        child: Text(p.label),
      ),
      null => null,
    };
    if (!phone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cancelButton,
          const SizedBox(width: Space.s2),
          secondaryButton,
          if (primaryButton != null) ...[
            const SizedBox(width: Space.s2),
            primaryButton,
          ],
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primaryButton != null) ...[
            primaryButton,
            const SizedBox(height: Space.s2),
          ],
          secondaryButton,
          const SizedBox(height: Space.s1),
          cancelButton,
        ],
      ),
    );
  }
}
