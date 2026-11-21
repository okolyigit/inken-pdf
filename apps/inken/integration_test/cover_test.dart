// Spot ışığı ve perde gerçek uygulamada: S / C kısayolları ve araç kutusu
// düğmeleri, ışığın içinde çizim, karartıyı / perdeyi sürükleme, Esc, belge
// kapanınca örtünün kalkması.
// Çalıştır: flutter test integration_test/cover_test.dart -d linux
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
import 'package:inken/features/presentation/stage_cover.dart';
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

  testWidgets('spot ışığı ve perde', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_cover_it');
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

    final area = t.getRect(find.byType(StageCoverLayer));
    StageCoverState cover() => container.read(stageCoverProvider);
    int items() => t
        .widget<InkLayer>(find.byType(InkLayer))
        .session
        .document
        .pages
        .fold(0, (n, p) => n + p.items.length);

    Future<void> mouseDrag(Offset from, Offset by) async {
      final g = await t.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(from + by * (i / 10));
        await t.pump();
      }
      await g.up();
      await t.pump();
    }

    // 1) S: spot ışığı. İçinde kalem çizer.
    await t.sendKeyEvent(LogicalKeyboardKey.keyS);
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.spotlight);
    expect(find.byKey(const ValueKey('spotlight')), findsOneWidget);
    final center = area.topLeft + cover().spotCenterIn(area.size);
    await mouseDrag(center - const Offset(30, 0), const Offset(60, 10));
    expect(items(), 1, reason: 'ışığın içinde çizilir');
    await _shot(t, 'spot');

    // 2) Karartıyı sürüklemek ışığı taşır, çizmez.
    final dim = area.bottomLeft + const Offset(80, -120);
    await mouseDrag(dim, const Offset(150, -60));
    expect(items(), 1);
    final moved = area.topLeft + cover().spotCenterIn(area.size);
    expect((moved - center - const Offset(150, -60)).distance, lessThan(30));

    // 3) C: perde (ışık kapanır). Tamamen örter; aşağı çekilince iner.
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.curtain);
    expect(find.byKey(const ValueKey('spotlight')), findsNothing);
    await mouseDrag(area.center, const Offset(0, 220));
    expect(items(), 1, reason: 'perdede çizilmez');
    expect(cover().curtainTopIn(area.size), closeTo(220, 30));
    await _shot(t, 'perde');

    // 4) Esc perdeyi kapatır.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.none);
    expect(find.byKey(const ValueKey('curtain')), findsNothing);

    // 5) Araç kutusundaki tek düğme: kapalıyken menü, açıkken kapatır.
    final button = find.byKey(const ValueKey('cover-button'));
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('cover-curtain')));
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.curtain);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.none);
    expect(find.byKey(const ValueKey('cover-spotlight')), findsNothing);
    await t.tap(button);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('cover-spotlight')));
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.spotlight);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.none);

    // 6) Tam ekranda da çalışır; belge kapanınca örtü kalkar.
    await t.sendKeyEvent(LogicalKeyboardKey.f11);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.keyS);
    await t.pumpAndSettle();
    await _shot(t, 'spot-tamekran');
    container.read(openDocumentProvider.notifier).close();
    await t.pumpAndSettle();
    expect(cover().mode, StageCover.none);
  });
}
