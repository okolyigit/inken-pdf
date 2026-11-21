import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dosya menüsündeki [item] komutunu çalıştırır; yerleşime göre menü
/// çubuğundan (masaüstü), logo menüsünden (tablet) ya da yan menüden
/// (telefon).
Future<void> fileCommand(WidgetTester t, String item) async {
  final menuButton = find.byKey(const ValueKey('app-menu'));
  if (menuButton.evaluate().isEmpty) {
    await t.tap(find.text('Dosya'));
  } else {
    await t.tap(menuButton);
    await t.pumpAndSettle();
    if (find.byType(Drawer).evaluate().isNotEmpty) {
      await t.tap(find.widgetWithText(ListTile, item));
      await t.pumpAndSettle();
      return;
    }
    await t.tap(find.widgetWithText(SubmenuButton, 'Dosya'));
  }
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(MenuItemButton, item));
  await t.pumpAndSettle();
}
