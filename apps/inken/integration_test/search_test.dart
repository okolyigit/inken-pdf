// Belgede arama gerçek uygulamada: Ctrl+F → yaz → ilk eşleşmeye gider →
// Enter / Shift+Enter → sonuç yok → Esc kapatır; Düzen menüsünden açma;
// sayfa eklenince arama yeniden yapılır.
// Çalıştır: flutter test integration_test/search_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  if (_shotDir.isEmpty) return;
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_shotDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (!done()) {
    final s = find.byKey(const ValueKey('search-status'));
    debugPrint('DURUM: ${s.evaluate().isEmpty ? '-' : t.widget<Text>(s).data}');
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ctrl+F ile arama, gezinme, kapatma', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_search_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/kitap.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/hundred_pages.pdf').readAsBytesSync(),
      );
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory({})),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const InkenApp(),
        ),
      ),
    );
    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'kitap.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final gate = layer.geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    await _until(t, () => gate.open && viewer.pageCount == 100);
    final box = find.byKey(const ValueKey('search-box'));
    final field = find.byKey(const ValueKey('search-field'));
    String status() =>
        t.widget<Text>(find.byKey(const ValueKey('search-status'))).data!;
    bool statusIs(String s) =>
        find.byKey(const ValueKey('search-status')).evaluate().isNotEmpty &&
        status() == s;

    // 1) Ctrl+F kutuyu açar ve odaklar.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await t.pump();
    expect(box, findsOneWidget);
    expect(
      t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus,
      isTrue,
    );

    // 2) Yazdıkça arar; tek eşleşme, o sayfaya gider. Büyük / küçük harf
    // ayrımı yok.
    await t.enterText(field, 'SAYFA 57');
    await _until(t, () => statusIs('1 / 1'));
    await _until(t, () => viewer.currentPage == 56);
    await _shot(t, 'arama-57');

    // 3) Birden çok eşleşme: Sayfa 5, 50..59 → 11. Arama ekrandaki sayfadan
    // (57) başlar: ilk eşleşme 57 (11'in 9.'su). Enter sonraki, Shift+Enter
    // önceki; sayfa izler.
    await t.enterText(field, 'sayfa 5');
    await _until(t, () => statusIs('9 / 11'));
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await _until(t, () => statusIs('10 / 11'));
    await _until(t, () => viewer.currentPage == 57);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _until(t, () => statusIs('9 / 11'));
    await _until(t, () => viewer.currentPage == 56);
    // Düğmeler de çalışır; sonda başa sarar (11 adımda aynı yere döner).
    await t.tap(find.byKey(const ValueKey('search-next')));
    await t.tap(find.byKey(const ValueKey('search-next')));
    await t.tap(find.byKey(const ValueKey('search-next')));
    await _until(t, () => statusIs('1 / 11'));
    await _until(t, () => viewer.currentPage == 4);
    await t.tap(find.byKey(const ValueKey('search-previous')));
    await _until(t, () => statusIs('11 / 11'));
    expect(
      t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus,
      isTrue,
      reason: 'düğmeden sonra yazmaya devam edilebilir',
    );
    await _until(t, () => viewer.currentPage == 58);

    // 4) Sonuç yok.
    await t.enterText(field, 'böyle bir şey yok');
    await _until(t, () => statusIs('Sonuç yok'));

    // 5) Esc kapatır, arama temizlenir.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(box, findsNothing);
    expect(viewer.search.query, isEmpty);
    expect(viewer.search.matchCount, 0);

    // 6) Düzen → Bul… açar; sayfa ekleyince (yeni kopya) arama yeniden
    // yapılır.
    await t.tap(find.text('Düzen'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-find')));
    await t.pumpAndSettle();
    expect(box, findsOneWidget);
    await t.enterText(field, 'sayfa 100');
    await _until(t, () => statusIs('1 / 1'));
    final session = layer.session;
    session.insertPage(0, newPageLike(session.document, 0, PageTemplate.grid));
    await _until(t, () => gate.open && viewer.pageCount == 101);
    // Eklenen sayfayla eşleşme bir sayfa kayar (101 sayfanın sonuncusu).
    await _until(t, () => viewer.search.currentPage == 100);
    expect(status(), '1 / 1');
    await _shot(t, 'arama-yeni-kopya');
  });
}
