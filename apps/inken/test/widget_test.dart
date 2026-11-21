import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';

void main() {
  testWidgets('açılış ekranı Türkçe "PDF aç" düğmesini gösterir', (t) async {
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await t.pumpWidget(const ProviderScope(child: InkenApp()));
    await t.pumpAndSettle();
    expect(find.text('PDF aç'), findsOneWidget);
    expect(find.text('Inken PDF'), findsOneWidget);
  });

  testWidgets('İngilizce yerelde metinler İngilizce', (t) async {
    t.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await t.pumpWidget(const ProviderScope(child: InkenApp()));
    await t.pumpAndSettle();
    expect(find.text('Open PDF'), findsOneWidget);
  });
}
