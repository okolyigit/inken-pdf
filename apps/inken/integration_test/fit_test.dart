// Sığdırma gerçek uygulamada: Ctrl+0 sayfanın tamamı görünür, Ctrl+2
// sayfanın genişliği ekranı doldurur, Ctrl+1 %100; yakınlaştırma kutusunun
// yüzdesi ve Görünüm menüsü aynı komutları verir. Ctrl+R / Ctrl+Shift+R
// sayfayı döndürür.
// Çalıştır: flutter test integration_test/fit_test.dart -d linux
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
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sayfaya / genişliğe sığdır, gerçek boyut', (t) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_fit_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
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
          name: 'ders.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final gate = layer.geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    await _until(t, () => gate.open && viewer.pageCount == 2);
    final view = Offset.zero & t.getSize(find.byType(InkLayer));

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(key);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
    }

    Rect page() => gate.viewportOf(viewer.currentPage!)!.rect;

    // 1) Ctrl+2: sayfa genişliği ekranı doldurur (kenar boşlukları kadar).
    await ctrl(LogicalKeyboardKey.digit2);
    expect(viewer.zoom, closeTo(viewer.fitZoom(width: true)!, 0.001));
    final wide = page();
    expect(wide.left, closeTo(view.width - wide.right, 1), reason: 'ortalı');
    expect(wide.width, greaterThan(view.width * 0.9));
    expect(wide.height, greaterThan(view.height), reason: 'A4 taşar');

    // 2) Ctrl+0: sayfanın tamamı görünür ve ortada.
    await ctrl(LogicalKeyboardKey.digit0);
    final whole = page();
    expect(view.contains(whole.topLeft), isTrue);
    expect(view.contains(whole.bottomRight - const Offset(1, 1)), isTrue);
    expect(whole.center.dx, closeTo(view.center.dx, 1));
    expect(whole.center.dy, closeTo(view.center.dy, 1));
    expect(whole.height, greaterThan(view.height * 0.85), reason: 'dolu');

    // 3) Ctrl+1: %100.
    await ctrl(LogicalKeyboardKey.digit1);
    expect(viewer.zoom, closeTo(1, 0.001));

    // 4) Yakınlaştırma kutusunun yüzdesi → Genişliğe sığdır.
    await t.tap(find.byKey(const ValueKey('zoom-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('zoom-fit-width')));
    await t.pumpAndSettle();
    expect(viewer.zoom, closeTo(viewer.fitZoom(width: true)!, 0.001));

    // 5) Görünüm → Sayfaya sığdır.
    await t.tap(find.text('Görünüm'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-fit-page')));
    await t.pumpAndSettle();
    expect(viewer.zoom, closeTo(viewer.fitZoom(width: false)!, 0.001));

    // 6) Ctrl+R sayfayı sağa, Ctrl+Shift+R sola döndürür (tek adımda geri).
    final session = layer.session;
    final index = viewer.currentPage!;
    await ctrl(LogicalKeyboardKey.keyR);
    expect(session.document.pages[index].pendingTurns, 1);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyR);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(session.document.pages[index].pendingTurns, 0);
  });
}
