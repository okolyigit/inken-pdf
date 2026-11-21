// Sayfa küçük resimleri paneli gerçek uygulamada: küçük resimler çizilir,
// dokunmak sayfaya gider, uzak sayfada panel o sayfayı gösterir, paneli
// açıp kapatmak belgeyi yeniden yüklemez (çizim oturumu yerinde).
// Çalıştır: flutter test integration_test/page_panel_test.dart -d linux
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
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/page_panel.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (_shotDir.isEmpty) return;
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

  testWidgets('sayfa küçük resimleri paneli', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_panel_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/kitap.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/hundred_pages.pdf').readAsBytesSync(),
      );
    final settings = SettingsStore.memory({'pagePanel': true});
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
          name: 'kitap.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await _until(
      t,
      () => find.byKey(const ValueKey('page-thumb-0')).evaluate().isNotEmpty,
    );
    final session = t.widget<InkLayer>(find.byType(InkLayer)).session;
    // İlk sayfaya bir çizim: küçük resimde de görünür.
    session.pasteItems(0, const [
      Shape(
        id: 's',
        kind: ShapeKind.rectangle,
        color: 0xFFD42A3F,
        width: 8,
        x1: 60,
        y1: 60,
        x2: 400,
        y2: 300,
      ),
    ]);
    session.clearSelection();
    await _shot(t, 'panel');
    expect(find.byType(PagePanel), findsOneWidget);
    String page() =>
        t.widget<Text>(find.byKey(const ValueKey('page-number'))).data!;

    // Dokunmak sayfaya gider.
    await t.ensureVisible(find.byKey(const ValueKey('page-thumb-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('page-thumb-2')));
    await _until(t, () => page() == '3');

    // Uzak sayfa: panel o sayfayı gösterir.
    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await _until(t, () => page() == '100');
    await _until(
      t,
      () => find.byKey(const ValueKey('page-thumb-99')).evaluate().isNotEmpty,
    );
    await t.pump(const Duration(milliseconds: 500));
    final thumb = t.getRect(find.byKey(const ValueKey('page-thumb-99')));
    final panel = t.getRect(find.byType(PagePanel));
    expect(thumb.top, greaterThanOrEqualTo(panel.top - 1));
    expect(thumb.bottom, lessThanOrEqualTo(panel.bottom + 1));
    await _shot(t, 'panel-100');

    // Panelin dışında, sağ kenarına bitişik sekme kapatır (panelin kaydırma
    // çubuğuyla çakışmaz); belge yeniden yüklenmez, çizim oturumu aynı.
    final grip = t.getRect(find.byKey(const ValueKey('page-panel-close')));
    expect(grip.left, closeTo(panel.right, 2), reason: 'panelin dışında');
    expect(grip.left, greaterThanOrEqualTo(panel.right - 0.5));
    expect(grip.center.dy, closeTo(panel.center.dy, 2), reason: 'dikey orta');
    await t.tap(find.byKey(const ValueKey('page-panel-close')));
    await t.pumpAndSettle();
    expect(find.byType(PagePanel), findsNothing);
    expect(settings.get<bool>('pagePanel'), isFalse);
    expect(
      identical(t.widget<InkLayer>(find.byType(InkLayer)).session, session),
      isTrue,
    );
    expect(page(), '100');

    // Kapalıyken belgenin sol kenarında, dikey ortada açma sekmesi.
    final open = find.byKey(const ValueKey('page-panel-open'));
    expect(open, findsOneWidget);
    final tab = t.getRect(open);
    final docArea = t.getRect(find.byType(InkLayer));
    expect(tab.left, closeTo(docArea.left, 2));
    expect(tab.center.dy, closeTo(docArea.center.dy, 2));
    await _shot(t, 'panel-kapali');

    // Araç kutusu soldayken sekmeyle çakışmaz.
    container.read(toolDockProvider.notifier).set(DockEdge.left);
    await t.pumpAndSettle();
    final dock = t.getRect(find.byKey(const ValueKey('tool-dock')));
    expect(dock.left, greaterThan(t.getRect(open).right));
    await _shot(t, 'panel-kapali-kutu-solda');

    // Tam ekranda sekme yok (panel de yok).
    await t.sendKeyEvent(LogicalKeyboardKey.f11);
    await t.pumpAndSettle();
    expect(open, findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.f11);
    await t.pumpAndSettle();

    // Sekmeye dokunmak paneli açar; sekme kalkar.
    await t.tap(open);
    await t.pumpAndSettle();
    expect(find.byType(PagePanel), findsOneWidget);
    expect(open, findsNothing);
    expect(settings.get<bool>('pagePanel'), isTrue);
    expect(session.document.pages[0].items, hasLength(1));
  });
}
