// Belge özellikleri gerçek uygulamada: Ctrl+D pencereyi açar; PDF bilgileri
// (Türkçe başlık, yazar, tarih, sürüm), dosya adı, sayfa sayısı ve geçerli
// sayfanın boyutu görünür; Dosya menüsünden de açılır.
// Çalıştır: flutter test integration_test/properties_test.dart -d linux
import 'dart:io';

import 'package:flutter/material.dart';
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

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

/// Pencere açılırken yükleme göstergesi dönebilir: pumpAndSettle yerine.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('belge özellikleri', (t) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_props_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/kitap.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/links.pdf').readAsBytesSync(),
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
      UncontrolledProviderScope(container: container, child: const InkenApp()),
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
    await _until(t, () => gate.open && viewer.pageCount == 3);

    final dialog = find.byKey(const ValueKey('properties-dialog'));
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.text(text));

    // 1) Ctrl+D: bilgiler.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(dialog, findsOneWidget);
    await _until(t, () => inDialog('Işık ve Gölge').evaluate().isNotEmpty);
    expect(inDialog('Inken Test'), findsOneWidget);
    expect(inDialog('kitap.pdf'), findsOneWidget);
    expect(inDialog(pdf.path), findsOneWidget);
    expect(inDialog('3'), findsOneWidget);
    expect(inDialog('210 × 297 mm (A4, Dikey)'), findsOneWidget);
    expect(inDialog('1.7'), findsOneWidget);
    expect(inDialog('Yok'), findsOneWidget, reason: 'güvenlik');
    expect(
      find.descendant(of: dialog, matching: find.textContaining('2026')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('properties-close')));
    await _settle(t);
    expect(dialog, findsNothing);

    // 2) Sayfa eklenince sayı modelden gelir; Dosya menüsünden açılır.
    final session = layer.session;
    session.insertPage(
      3,
      newPageLike(
        session.document,
        2,
        PageTemplate.blank,
        orientation: PageOrientation.landscape,
      ),
    );
    await _until(t, () => gate.open && viewer.pageCount == 4);
    await viewer.jumpToPage(3);
    await _until(t, () => viewer.currentPage == 3);
    await t.tap(find.text('Dosya'));
    await _settle(t);
    await t.tap(find.byKey(const ValueKey('menu-properties')));
    await _settle(t);
    expect(inDialog('4'), findsOneWidget);
    expect(inDialog('297 × 210 mm (A4, Yatay)'), findsOneWidget);
  });
}
