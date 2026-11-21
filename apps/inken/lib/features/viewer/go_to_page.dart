import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Kullanıcının yazdığı sayfa numarasını (1'den başlar) sıra numarasına
/// (0'dan) çevirir; geçersizse `null`. Aralık dışı değer en yakın sayfaya
/// çekilir.
int? parsePageInput(String text, int count) {
  final n = int.tryParse(text.trim());
  if (n == null || count <= 0) return null;
  return n.clamp(1, count) - 1;
}

/// "Sayfaya git" penceresi; seçilen sayfanın sıra numarası ya da `null`.
Future<int?> showGoToPageDialog(
  BuildContext context, {
  required int count,
  required int current,
}) => showDialog<int>(
  context: context,
  builder: (context) => _GoToPageDialog(count: count, current: current),
);

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.count, required this.current});

  final int count;
  final int current;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _text =
      TextEditingController(text: '${widget.current + 1}')
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: '${widget.current + 1}'.length,
        );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final page = parsePageInput(_text.text, widget.count);
    if (page != null) Navigator.pop(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.goToPageTitle),
      content: TextField(
        key: const ValueKey('go-to-page-field'),
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: l10n.goToPageLabel(widget.count),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.go)),
      ],
    );
  }
}
