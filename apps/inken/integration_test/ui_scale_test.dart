// Arayüz boyutu gerçek uygulamada: Büyük ölçekte (%125) çizgi
// sayfada dokunulan yere düşer, seçim tutamağı tutulur, sayfa keskin
// çizilir (ekran görüntüsü). Çalıştır:
// flutter test integration_test/ui_scale_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüsü oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('büyük ölçekte çizim yerinde', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1920, 1080);
    addTearDown(t.view.reset);
    final dir = Directory.systemTemp.createTempSync('inken_scale_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore.memory({'uiScale': 'large'}),
        ),
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

    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer.session;
    final view = layer.geometry.viewportOf(0)!;
    // Katmanın yerel (ölçeklenmemiş) koordinatından ekrana: ×1,25.
    final box = t.getRect(find.byType(InkLayer));
    const scale = 1.25;
    Offset screen(Offset page) => box.topLeft + view.toView(page) * scale;

    final g = await t.startGesture(
      screen(const Offset(100, 150)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(screen(Offset(100 + 20.0 * i, 150)));
      await t.pump();
    }
    await g.up();
    await t.pump();
    final s = session.document.pages[0].items.single as Stroke;
    expect(s.points.first.x, closeTo(100, 1));
    expect(s.points.first.y, closeTo(150, 1));
    expect(s.points.last.x, closeTo(300, 1));

    if (_shotDir.isNotEmpty) {
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final boundary =
          _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_shotDir/olcek-125.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    }
  });
}
