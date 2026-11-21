// Gece modu gerçek uygulamada: Görünüm → Gece modu sayfayı koyulaştırır
// (beyaz kâğıt koyu, siyah yazı açık), siyah kalem çizgisi açık görünür;
// kaydedilen dosya değişmez; ayar kalıcıdır; kapatınca eski hâl.
// Çalıştır: flutter test integration_test/night_test.dart -d linux
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
import 'package:inken/features/viewer/night_mode.dart';
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
  expect(done(), isTrue, reason: 'zaman aşımı');
}

/// Ekrandaki [at] noktasının rengi (ARGB).
Future<int> _pixel(WidgetTester t, Offset at) async {
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = (await image.toByteData())!;
  final i = (at.dy.round() * image.width + at.dx.round()) * 4;
  final (r, g, b) = (
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
  image.dispose();
  return 0xFF000000 | r << 16 | g << 8 | b;
}

double _lightness(int argb) =>
    ((argb >> 16 & 0xFF) + (argb >> 8 & 0xFF) + (argb & 0xFF)) / 3 / 255;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gece modu', (t) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_night_it');
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
    // Siyah, kalın bir çizgi: sayfanın boş bir yerinde.
    layer.session.pasteItems(0, const [
      Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 14,
        points: [InkPoint(300, 200), InkPoint(500, 200)],
      ),
    ]);
    layer.session.clearSelection();
    await t.pump(const Duration(milliseconds: 800));
    final box = t.getRect(find.byType(InkLayer));
    Offset at(double x, double y) =>
        box.topLeft + gate.viewportOf(0)!.toView(Offset(x, y));
    final paper = at(40, 40); // kenar boşluğu: beyaz kâğıt
    final ink = at(400, 200);

    expect(_lightness(await _pixel(t, paper)), greaterThan(0.9));
    expect(_lightness(await _pixel(t, ink)), lessThan(0.15));

    // 1) Görünüm → Gece modu.
    await t.tap(find.text('Görünüm'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-night-mode')).first);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(nightModeProvider), isTrue);
    expect(
      container.read(settingsStoreProvider).get<bool>('nightMode'),
      isTrue,
      reason: 'kalıcı',
    );
    await _shot(t, 'gece');
    expect(_lightness(await _pixel(t, paper)), lessThan(0.2), reason: 'kâğıt');
    expect(
      _lightness(await _pixel(t, ink)),
      greaterThan(0.85),
      reason: 'kalem',
    );

    // 2) Model ve kaydedilecek renk değişmez.
    final item = layer.session.document.pages[0].items.single as Stroke;
    expect(item.color, 0xFF000000);

    // 3) Kapatınca eski hâl.
    container.read(nightModeProvider.notifier).set(false);
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(_lightness(await _pixel(t, paper)), greaterThan(0.9));
    expect(_lightness(await _pixel(t, ink)), lessThan(0.15));
  });
}
