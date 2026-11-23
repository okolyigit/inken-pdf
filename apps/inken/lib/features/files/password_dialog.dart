import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Parolalı PDF için açılış parolasını sorar; vazgeçilirse `null`.
/// [wrong]: önceki deneme yanlıştı (pencerede uyarı gösterilir).
Future<String?> askPdfPassword(
  BuildContext context, {
  required String name,
  required bool wrong,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _PasswordDialog(name: name, wrong: wrong),
);

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.name, required this.wrong});

  final String name;
  final bool wrong;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _text = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _text.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return AlertDialog(
      key: const ValueKey('password-dialog'),
      icon: Icon(LucideIcons200.lock, color: c.inkMuted),
      title: Text(l10n.passwordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.passwordPrompt(widget.name)),
          const SizedBox(height: Space.s4),
          TextField(
            key: const ValueKey('password-field'),
            controller: _text,
            autofocus: true,
            obscureText: !_visible,
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              errorText: widget.wrong ? l10n.passwordWrong : null,
              suffixIcon: IconButton(
                key: const ValueKey('password-visibility'),
                tooltip: _visible ? l10n.passwordHide : l10n.passwordShow,
                icon: Icon(
                  _visible ? LucideIcons200.eyeOff : LucideIcons200.eye,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('password-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('password-open'),
          onPressed: _submit,
          child: Text(l10n.passwordOpen),
        ),
      ],
    );
  }
}
