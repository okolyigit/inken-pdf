// Özel renk gerçek uygulamada: kalem paneli → + → seçici → kod → çiz →
// ayar dosyasına yazıldı mı.
// Çalıştır: flutter test integration_test/color_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_core/inken_core.dart';
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

  testWidgets('kalem paneli → + → kodla renk → çiz → ayarlara yazıldı', (
    t,
  ) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_color_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final settings = await SettingsStore.load(directory: dir);
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

    // Kalem seçili: ikinci dokunuş paneli açar.
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-color-new')), findsOneWidget);
    await _shot(t, 'renk-1-panel');

    await t.tap(find.byKey(const ValueKey('custom-color-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('picker-hex')), '#0A7E8C');
    await t.pump();
    await _shot(t, 'renk-2-secici');
    await t.tap(find.byKey(const ValueKey('picker-ok')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).penColor, 0xFF0A7E8C);

    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final v = layer.geometry.viewportOf(0)!;
    final box = t.getRect(find.byType(InkLayer));
    final start = box.topLeft + v.toView(const Offset(80, 150));
    final g = await t.startGesture(start, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(start + Offset(i * 16.0, (i % 2) * 10.0));
      await t.pump();
    }
    await g.up();
    await t.pump();
    final stroke = layer.session.document.pages[0].items.single as Stroke;
    expect(stroke.color, 0xFF0A7E8C);

    // Panel yeniden açılınca özel renk listede ve seçili.
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-color-0')), findsOneWidget);
    await _shot(t, 'renk-3-cizgi');

    // İmleç: kalem ucu ve renk noktası. Çizimdeki fare hâlâ bağlı; panel
    // Esc ile kapanır, fare sayfanın üzerinde gezinir.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    await g.moveTo(box.topLeft + v.toView(const Offset(220, 170)));
    await _shot(t, 'imlec-kalem');
    container.read(toolProvider.notifier).select(Tool.highlighter);
    await g.moveBy(const Offset(2, 1));
    await _shot(t, 'imlec-fosforlu');
    container.read(toolProvider.notifier).select(Tool.laser);
    await g.moveBy(const Offset(2, 1));
    await _shot(t, 'imlec-gecici');

    await settings.flush();
    final reloaded = await SettingsStore.load(directory: dir);
    expect(reloaded.get<List<Object?>>('customColors'), ['#0A7E8C']);
  });
}
