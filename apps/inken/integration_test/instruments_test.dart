// Ölçme araçları ve koordinat düzlemi gerçek uygulamada: şekil panelinden
// cetveli açma, koordinat düzlemi çizme, cetvelin kenarı boyunca çizgi,
// dört aracın birlikte görünümü, pergelle yay, Esc ile kapatma.
// Çalıştır: flutter test integration_test/instruments_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:math' as math;
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
import 'package:inken/features/ink/instruments.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  for (var i = 0; i < 6; i++) {
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
  expect(done(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ölçme araçları ve koordinat düzlemi', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final dir = Directory.systemTemp.createTempSync('inken_instruments_it');
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
    await t.pump(const Duration(milliseconds: 500));

    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final geometry = layer.geometry;
    final session = layer.session;
    final origin = t.getTopLeft(find.byType(InkLayer));
    List<InkItem> items() => session.document.pages[0].items;
    PageViewport page() => geometry.viewportOf(0)!;
    Offset screen(double x, double y) => origin + page().toView(Offset(x, y));
    InstrumentPose? pose(InstrumentKind k) =>
        container.read(instrumentsProvider)[k];

    Future<void> mouse(List<Offset> path) async {
      final g = await t.startGesture(
        path.first,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      for (final p in path.skip(1)) {
        await g.moveTo(p);
        await t.pump();
      }
      await g.up();
      await t.pump();
    }

    // 1) Şekil panelinde koordinat düzlemi ve ölçme araçları.
    await t.tap(find.byKey(const ValueKey('tool-shape')));
    await t.pumpAndSettle();
    if (find.byKey(const ValueKey('options-shape')).evaluate().isEmpty) {
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.pumpAndSettle();
    }
    expect(find.text('Ölçme araçları'), findsOneWidget);
    await _shot(t, 'sekil-paneli');
    await t.tap(find.byKey(const ValueKey('seg-ShapeKind.coordinate')));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // 2) Koordinat düzlemi: sayfanın üst kısmına 8 × 6 cm.
    const left = 150.0, topY = 90.0;
    await mouse([
      screen(left, topY),
      screen(left + 4 * ptPerCm, topY + 3 * ptPerCm),
      screen(left + 8 * ptPerCm, topY + 6 * ptPerCm),
    ]);
    final plane = items().single as Shape;
    expect(plane.kind, ShapeKind.coordinate);

    // 3) Panelden cetvel: ortaya konur, kalem seçilir.
    await t.tap(find.byKey(const ValueKey('tool-shape')));
    await t.pumpAndSettle();
    if (find.byKey(const ValueKey('options-shape')).evaluate().isEmpty) {
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const ValueKey('instrument-toggle-ruler')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.pen);
    await _until(t, () => (pose(InstrumentKind.ruler)?.page ?? -1) >= 0);
    await t.sendKeyEvent(LogicalKeyboardKey.escape); // paneli kapat
    await t.pumpAndSettle();

    // Cetveli koordinat düzleminin altına taşı (gövdeden sürükle).
    final ruler0 = pose(InstrumentKind.ruler)!;
    final target = Offset(left + 4 * ptPerCm, topY + 9 * ptPerCm);
    final from = screen(ruler0.x, ruler0.y);
    final to = screen(target.dx, target.dy);
    await mouse([for (var i = 0; i <= 8; i++) Offset.lerp(from, to, i / 8)!]);
    final ruler = pose(InstrumentKind.ruler)!;
    expect(ruler.x, closeTo(target.dx, 0.5));
    expect(ruler.y, closeTo(target.dy, 0.5));

    // 4) Üst kenarı boyunca titrek çizgi: düz çıkar.
    final edge = ruler.y - rulerHeight / 2;
    await mouse([
      for (var i = 0; i <= 12; i++)
        screen(
          ruler.x - 5 * ptPerCm + i * ptPerCm * 10 / 12,
          edge - 5 + (i.isEven ? 3 : -3),
        ),
    ]);
    final line = items().last as Stroke;
    final ys = line.points.map((p) => p.y).toSet();
    expect(ys.length, 1, reason: 'bütün noktalar aynı yükseklikte');
    await _shot(t, 'cetvel');

    // 5) Dört araç birlikte; cetvel 30° döndürülmüş.
    final n = container.read(instrumentsProvider.notifier);
    for (final k in [
      InstrumentKind.setSquare,
      InstrumentKind.protractor,
      InstrumentKind.compass,
    ]) {
      n.open(k);
    }
    await t.pumpAndSettle();
    final w = session.document.pages[0].width;
    n.update(pose(InstrumentKind.ruler)!.copyWith(angle: -math.pi / 6));
    n.update(
      pose(InstrumentKind.setSquare)!.copyWith(page: 0, x: w * 0.15, y: 330),
    );
    n.update(
      pose(InstrumentKind.protractor)!.copyWith(page: 0, x: w * 0.66, y: 395),
    );
    n.update(
      pose(InstrumentKind.compass)!
          .copyWith(page: 0, x: w * 0.30, y: 385, radius: 3 * ptPerCm),
    );
    await _shot(t, 'dort-arac');

    // 6) Pergelin tutamağını çevir: yarım tur yay.
    n.close(InstrumentKind.setSquare);
    await _shot(t, 'pergel-once');
    final c = pose(InstrumentKind.compass)!;
    final needle = screen(c.x, c.y);
    final k = compassKnob(c);
    final knob = screen(k.x, k.y);
    final arm = (knob - needle).distance;
    final a0 = (knob - needle).direction;
    final before = items().length;
    await mouse([
      for (var i = 0; i <= 24; i++)
        needle +
            Offset(
                  math.cos(a0 + i * math.pi / 24),
                  math.sin(a0 + i * math.pi / 24),
                ) *
                arm,
    ]);
    expect(items().length, before + 1);
    final arc = items().last as Stroke;
    for (final p in arc.points) {
      final d = math.sqrt(math.pow(p.x - c.x, 2) + math.pow(p.y - c.y, 2));
      expect(d, closeTo(3 * ptPerCm, 0.01));
    }
    await _shot(t, 'pergel');

    // 7) Esc araçları kapatır; çizilenler kalır.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(container.read(instrumentsProvider), isEmpty);
    expect(items(), hasLength(before + 1));
    await _shot(t, 'kapali');
  });
}
