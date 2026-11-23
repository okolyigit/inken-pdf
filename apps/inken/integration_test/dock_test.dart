// Araç kutusunu kenara taşıma gerçek uygulamada: tutamaktan alta sürükle →
// kutu sayfa gezgininin üstüne oturur, kalem paneli yukarı açılır; menüden
// sağa al → panel sola açılır. Tam ekranda da çalışır.
// Çalıştır: flutter test integration_test/dock_test.dart -d linux
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
import 'package:inken/features/ink/ink_toolbar.dart';
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  if (_shotDir.isEmpty) return;
  for (var i = 0; i < 10; i++) {
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
  expect(done(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('kutu alta ve sağa taşınır; panel içeri açılır', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_dock_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final settings = SettingsStore.memory();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
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
          name: 'ders.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 500));
    final dock = find.byKey(const ValueKey('tool-dock'));
    final grip = find.byKey(const ValueKey('dock-move'));
    final screen = t.getSize(find.byType(InkenApp));

    // 1) Tutamaktan alta sürükle.
    final g = await t.startGesture(t.getCenter(grip));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(-30, 50));
      await t.pump();
    }
    await g.up();
    await t.pumpAndSettle();
    expect(container.read(toolDockProvider), DockEdge.bottom);
    final pageNav = t.getRect(find.byType(PageNav));
    expect(
      t.getRect(dock).bottom,
      lessThan(pageNav.top),
      reason: 'sayfa gezgininin üstünde',
    );
    // Kalem paneli yukarı açılır.
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byKey(const ValueKey('options-pen')));
    expect(panel.bottom, lessThan(t.getRect(dock).top));
    expect(panel.top, greaterThanOrEqualTo(0));
    await _shot(t, 'kutu-altta');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // 2) Menüden sağa: dikey, panel sola açılır.
    await t.tap(grip);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dock-right')));
    await t.pumpAndSettle();
    expect(container.read(toolDockProvider), DockEdge.right);
    expect(t.getRect(dock).right, lessThan(screen.width));
    expect(t.getRect(dock).height, greaterThan(t.getRect(dock).width));
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    final panel2 = t.getRect(find.byKey(const ValueKey('options-pen')));
    expect(panel2.right, lessThan(t.getRect(dock).left));
    await _shot(t, 'kutu-sagda');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // 3) Tam ekranda da kutu kenarında, çıkış düğmesiyle çakışmaz.
    await t.sendKeyEvent(LogicalKeyboardKey.f11);
    await t.pumpAndSettle();
    final exit = t.getRect(find.byKey(const ValueKey('exit-fullscreen')));
    expect(t.getRect(dock).overlaps(exit), isFalse);
    await _shot(t, 'kutu-tamekran-sagda');
    await t.sendKeyEvent(LogicalKeyboardKey.f11);
    await t.pumpAndSettle();
    expect(settings.get<String>('toolDock'), 'right');
  });

  testWidgets('yan kenarda sığarsa tek sütun, sığmazsa iki sütun', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_dock_fit_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Dikey tablet: uzun kenar.
    await t.binding.setSurfaceSize(const Size(820, 1180));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const InkenApp(),
        ),
      ),
    );
    container.read(toolDockProvider.notifier).set(DockEdge.right);
    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'ders.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await t.pumpAndSettle();
    final dock = find.byKey(const ValueKey('tool-dock'));
    final columns = find.byKey(const ValueKey('tool-dock-columns'));

    expect(columns, findsNothing, reason: 'dikey tablette tek sütun');
    final pen = t.getRect(find.byKey(const ValueKey('tool-pen')));
    final text = t.getRect(find.byKey(const ValueKey('tool-text')));
    expect(text.left, closeTo(pen.left, 1), reason: 'aynı sütunda');
    expect(text.top, greaterThan(pen.bottom));
    expect(t.getRect(dock).bottom, lessThanOrEqualTo(1180));
    await _shot(t, 'kutu-tek-sutun');

    // Alçak pencere: tek sütun sığmaz → iki sütun.
    await t.binding.setSurfaceSize(const Size(1280, 640));
    await t.pumpAndSettle();
    expect(columns, findsOneWidget, reason: 'alçak ekranda iki sütun');
    final dockRect = t.getRect(dock);
    expect(dockRect.top, greaterThanOrEqualTo(0));
    expect(dockRect.bottom, lessThanOrEqualTo(640));
    await _shot(t, 'kutu-iki-sutun');

    // Yeniden uzayınca tek sütuna döner.
    await t.binding.setSurfaceSize(const Size(820, 1180));
    await t.pumpAndSettle();
    expect(columns, findsNothing);
  });
}
