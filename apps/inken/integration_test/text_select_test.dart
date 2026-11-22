// Metin seçip kopyalama gerçek uygulamada: Metin seç aracıyla fareyle
// sürüklemek metni seçer (çizim olmaz), Ctrl+C sistem panosuna kopyalar,
// Ctrl+A bütün metni seçer; kaleme geçince seçim kalkar ve sürüklemek çizer.
// Çalıştır: flutter test integration_test/text_select_test.dart -d linux
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
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:flutter/gestures.dart';
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
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('metin seçip kopyalama', (t) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_textsel_it');
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
    // Sistem panosu yerine bellekte: test makinenin panosuna dokunmasın.
    String? clipboard;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return {'text': clipboard};
          case 'Clipboard.hasStrings':
            return {'value': clipboard != null};
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
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
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final gate = layer.geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    await _until(t, () => gate.open && viewer.pageCount == 2);
    await t.pump(const Duration(milliseconds: 500));
    final box = t.getRect(find.byType(InkLayer));
    Offset at(double x, double y) =>
        box.topLeft + gate.viewportOf(0)!.toView(Offset(x, y));

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(key);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
    }

    // Tek bir fare: araca tıklar, metnin üstüne gelir, basıp sürükler.
    // (Görüntüleyici son işaretçinin türüne bakar: dokunmatikte sürükleyerek
    // seçme kapalıdır, tutamaçlar çıkar.)
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);

    Future<void> click(Offset at) async {
      await mouse.moveTo(at);
      await t.pump(const Duration(milliseconds: 50));
      await mouse.down(at);
      await t.pump(const Duration(milliseconds: 50));
      await mouse.up();
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<void> drag(Offset from, Offset to) async {
      await mouse.moveTo(from);
      await t.pump(const Duration(milliseconds: 300));
      await mouse.down(from);
      await t.pump(const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await mouse.moveTo(Offset.lerp(from, to, i / 10)!);
        await t.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await t.pump(const Duration(milliseconds: 300));
    }

    // 1) Araç kutusundan Metin seç; başlık satırı ("Inken fixture - Sayfa
    // 1", x 72.., y 62..88 pt) sürüklenerek seçilir; çizim olmaz. Sürükleme
    // metnin üstünden başlamalı (pdfrx metin dışını seçim saymaz).
    // Seç düğmesi: ilk tıklama seçer, ikincisi tür panelini açar.
    await click(t.getCenter(find.byKey(const ValueKey('tool-select'))));
    await t.pump();
    await click(t.getCenter(find.byKey(const ValueKey('tool-select'))));
    await t.pumpAndSettle();
    await click(t.getCenter(find.byKey(const ValueKey('seg-Tool.textSelect'))));
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.textSelect);
    await drag(at(72.5, 75), at(340, 75));
    await _shot(t, 'metin-secim');
    await _until(t, () => viewer.hasSelectedText);
    expect(layer.session.document.pages[0].items, isEmpty);

    // 2) Ctrl+C: panoda seçilen metin.
    await ctrl(LogicalKeyboardKey.keyC);
    await _until(t, () => clipboard != null);
    expect(clipboard, contains('Inken fixture'));
    expect(clipboard, isNot(contains('denklemini')));
    expect(find.text('Metin kopyalandı'), findsOneWidget);

    // 3) Ctrl+A: bütün metin.
    clipboard = null;
    await ctrl(LogicalKeyboardKey.keyA);
    await t.pump(const Duration(milliseconds: 300));
    await ctrl(LogicalKeyboardKey.keyC);
    await _until(t, () => clipboard != null);
    expect(clipboard, contains('denklemini'));
    expect(clipboard, contains('Sayfa 2'));

    // 4) Kaleme geçince seçim kalkar; sürüklemek çizer.
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.pump(const Duration(milliseconds: 300));
    expect(viewer.hasSelectedText, isFalse);
    await drag(at(80, 75), at(330, 75));
    expect(layer.session.document.pages[0].items, hasLength(1));
    expect(viewer.hasSelectedText, isFalse);
    await mouse.removePointer();
  });
}
