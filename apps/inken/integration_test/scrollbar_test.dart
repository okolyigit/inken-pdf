// Sayfa kaydırma çubuğunu gerçek görüntüleyiciyle (pdfrx) doğrular.
// Çalıştır: flutter test integration_test/scrollbar_test.dart -d linux
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kaydırma çubuğu 100 sayfalık belgede doğru yere götürür', (
    t,
  ) async {
    await initInkenPdf();
    final bytes = File('../../test/fixtures/hundred_pages.pdf')
        .readAsBytesSync();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerPage(
            document: OpenDocument(name: 'hundred_pages.pdf', bytes: bytes),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byType(InkLayer).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 200));
    final c =
        (t.widget<InkLayer>(find.byType(InkLayer)).geometry as LayoutGate).inner
            as InkenViewerController;
    expect(c.pageCount, 100);
    expect(c.scrollFraction, closeTo(0, 1e-6));
    expect(c.visibleFraction, lessThan(0.05));

    // Denetleyici: ortaya ve sona.
    await c.scrollToFraction(0.5);
    await t.pump(const Duration(milliseconds: 100));
    expect(c.scrollFraction, closeTo(0.5, 0.01));
    expect(c.currentPage, inInclusiveRange(48, 51));
    await c.scrollToFraction(1);
    await t.pump(const Duration(milliseconds: 100));
    expect(c.scrollFraction, closeTo(1, 0.01));
    expect(c.currentPage, 99);

    // Çubuk: en üste dokun, sonra tutamağı aşağı sürükle.
    final bar = find.byKey(const ValueKey('page-scrollbar'));
    expect(bar, findsOneWidget);
    final r = t.getRect(bar);
    await t.tapAt(Offset(r.center.dx, r.top + 2));
    await t.pump(const Duration(milliseconds: 100));
    expect(c.scrollFraction, closeTo(0, 0.01));
    expect(c.currentPage, 0);

    final g = await t.startGesture(Offset(r.center.dx, r.top + 10));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(r.center.dx, r.top + 10 + r.height * 0.05 * i));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const ValueKey('page-scrollbar-label')), findsOneWidget);
    await g.up();
    await t.pump(const Duration(milliseconds: 100));
    // Yolun yaklaşık yarısı (tutamak yüksekliği yolu biraz kısaltır).
    expect(c.scrollFraction, inInclusiveRange(0.45, 0.65));
    expect(c.currentPage, inInclusiveRange(40, 65));
  });

  testWidgets('Page Down görüntüleyici odaktayken de tam bir sayfa gider', (
    t,
  ) async {
    await initInkenPdf();
    final bytes = File('../../test/fixtures/hundred_pages.pdf')
        .readAsBytesSync();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ViewerPage(
            document: OpenDocument(name: 'hundred_pages.pdf', bytes: bytes),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byType(InkLayer).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pump(const Duration(milliseconds: 200));
    final c =
        (t.widget<InkLayer>(find.byType(InkLayer)).geometry as LayoutGate).inner
            as InkenViewerController;

    // Gezinme aracıyla belgeye tıkla: görüntüleyici klavye odağını alır.
    container.read(toolProvider.notifier).select(Tool.hand);
    await t.pump();
    await t.tapAt(t.getCenter(find.byType(InkLayer)));
    await t.pump(const Duration(milliseconds: 300));
    expect(c.currentPage, 0);

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settle();
    expect(c.currentPage, 1);

    // Animasyon bitmeden art arda üç basış: tam üç sayfa.
    for (var i = 0; i < 3; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pump(const Duration(milliseconds: 30));
    }
    await settle();
    expect(c.currentPage, 4);

    await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await settle();
    expect(c.currentPage, 3);

    // Basılı tutma (tuş tekrarı ~30 ms): her tekrar bir sayfa, animasyon
    // durmadan yeni hedefe devam eder; sayfa konumu hep ileri gider.
    await t.sendKeyDownEvent(LogicalKeyboardKey.pageDown);
    var lastTop = c.scrollFraction!;
    var backwards = false;
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 30));
      await t.sendKeyRepeatEvent(LogicalKeyboardKey.pageDown);
      await t.pump(const Duration(milliseconds: 16));
      final now = c.scrollFraction!;
      if (now < lastTop) backwards = true;
      lastTop = now;
    }
    await t.sendKeyUpEvent(LogicalKeyboardKey.pageDown);
    await settle();
    expect(backwards, isFalse);
    expect(c.currentPage, 9); // 3 + basış + 5 tekrar

    // Boşluk: kısa basış sonraki sayfa, Shift+boşluk önceki.
    final atSpace = c.currentPage!;
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await settle();
    expect(c.currentPage, atSpace + 1);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle();
    expect(c.currentPage, atSpace);

    // Basılı tutmak: geçici el aracı, sayfa çevirmez; bırakınca kalem döner.
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.sendKeyDownEvent(LogicalKeyboardKey.space);
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.hand);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.sendKeyUpEvent(LogicalKeyboardKey.space);
    await settle();
    expect(container.read(toolProvider).tool, Tool.pen);
    expect(c.currentPage, atSpace);

    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await settle();
    expect(c.currentPage, 99);
    await t.sendKeyEvent(LogicalKeyboardKey.home);
    await settle();
    expect(c.currentPage, 0);
  });
}
