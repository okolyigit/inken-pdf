import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/settings/shortcuts.dart';
import 'package:inken/l10n/app_localizations_tr.dart';

void main() {
  test('her kısayolun tuşu var; aynı tuş iki komuta verilmemiş', () {
    final seen = <String, AppShortcut>{};
    for (final s in AppShortcut.values) {
      final keys = shortcutKeys[s];
      expect(keys, isNotEmpty, reason: s.name);
      for (final a in keys!) {
        final id = activatorKeys(a).join('+');
        expect(seen[id], isNull, reason: '$id: ${seen[id]} ve ${s.name}');
        seen[id] = s;
      }
    }
  });

  test('tuş adları', () {
    expect(activatorKeys(shortcutKeys[AppShortcut.saveAs]!.first), [
      'Ctrl',
      'Shift',
      'S',
    ]);
    expect(activatorKeys(shortcutKeys[AppShortcut.zoomIn]!.first), [
      'Ctrl',
      '+',
    ]);
    expect(activatorKeys(shortcutKeys[AppShortcut.escape]!.first), ['Esc']);
    expect(activatorKeys(shortcutKeys[AppShortcut.nextPage]!.first), [
      'Page Down',
    ]);
  });

  test('listede her kısayol görünür', () {
    final rows = [
      for (final (_, r) in shortcutGroups(AppLocalizationsTr())) ...r,
    ].map((r) => r.keys.join('+')).toSet();
    for (final s in AppShortcut.values) {
      expect(
        rows,
        contains(activatorKeys(shortcutKeys[s]!.first).join('+')),
        reason: s.name,
      );
    }
  });
}
