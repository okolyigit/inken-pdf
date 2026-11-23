// Sayfa sıralama gerçek uygulamada: panelde sağ tık → Aşağı taşı, Ctrl ile
// iki sayfa seç → şeritten iki kez yukarı, fareyle sürükle bırak,
// dokunmatikte uzun basıp sürükle, kıpırdamadan uzun basış seçim kipini
// açar, Ctrl+Z, kaydet → dosyada sayfalar ve açıklama yeni sırada.
// Çalıştır: flutter test integration_test/page_move_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
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
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('menü → şerit → fare → dokunmatik → geri al → kaydet', (t) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final dir = Directory.systemTemp.createTempSync('inken_page_move_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    // mixed_sizes.pdf: beş sayfa, hepsi farklı boyutta; sıra boyuttan
    // anlaşılır.
    final fixture = File('../../test/fixtures/mixed_sizes.pdf');
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(fixture.readAsBytesSync());
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore.memory({'pagePanel': true}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(openDocumentProvider.notifier);
    await t.runAsync(
      () => notifier.openBytes(
        name: 'ders.pdf',
        bytes: original.readAsBytesSync(),
        path: original.path,
      ),
    );
    await t.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                final doc = ref.watch(openDocumentProvider);
                return doc == null
                    ? const SizedBox()
                    : ViewerPage(key: ValueKey(doc.sourceName), document: doc);
              },
            ),
          ),
        ),
      ),
    );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    InkLayer layer() => t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer().session;
    final gate = layer().geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    List<PageLayer> pages() => session.document.pages;
    List<int?> order() => pages().map((p) => p.sourceIndex).toList();
    final sizes0 = [for (final p in pages()) (p.width, p.height)];

    /// Ekrandaki kopya modelin düzeninde (sayı ve boyutlar) ve katman açık.
    Future<void> settled() => _until(t, () {
      final sizes = viewer.pageSizes;
      if (!gate.open || sizes.length != pages().length) return false;
      for (final (i, p) in pages().indexed) {
        if ((sizes[i].width - p.width).abs() > 0.5 ||
            (sizes[i].height - p.height).abs() > 0.5) {
          return false;
        }
      }
      return true;
    });

    Finder thumb(int i) => find.byKey(ValueKey('page-thumb-$i'));
    Future<Rect> showThumb(int i) async {
      await _until(t, () => thumb(i).evaluate().isNotEmpty);
      await t.ensureVisible(thumb(i));
      await t.pumpAndSettle();
      return t.getRect(thumb(i));
    }

    await settled();
    expect(pages(), hasLength(5));
    session.pasteItems(0, const [
      Shape(
        id: 'line',
        kind: ShapeKind.line,
        color: 0xFFD42A3F,
        width: 6,
        x1: 60,
        y1: 80,
        x2: 260,
        y2: 80,
      ),
    ]);
    session.clearSelection();

    // 1) Sağ tık → Aşağı taşı; görüntüleyici taşınan sayfaya gider.
    await showThumb(0);
    await t.tap(thumb(0), buttons: kSecondaryButton);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('panel-move-down')));
    await t.pump();
    await settled();
    expect(order(), [1, 0, 2, 3, 4]);
    expect((pages()[1].items.single as Shape).kind, ShapeKind.line);
    await _until(t, () => viewer.currentPage == 1);

    // 2) Ctrl ile 4. ve 5. sayfa; şeritten iki kez yukarı (seçim gider).
    await showThumb(3);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(thumb(3));
    await showThumb(4);
    await t.tap(thumb(4));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(find.text('2 sayfa seçili'), findsOneWidget);
    final panelRight = t
        .getRect(find.byKey(const ValueKey('page-panel')))
        .right;
    for (final id in [
      'move-up',
      'move-down',
      'rotate-left',
      'rotate-right',
      'delete',
      'clear',
    ]) {
      final r = t.getRect(find.byKey(ValueKey('panel-selection-$id')));
      expect(r.right, lessThanOrEqualTo(panelRight), reason: id);
    }
    await t.tap(find.byKey(const ValueKey('panel-selection-move-up')));
    await t.pump();
    await settled();
    expect(order(), [1, 0, 3, 4, 2]);
    await t.tap(find.byKey(const ValueKey('panel-selection-move-up')));
    await t.pump();
    await settled();
    expect(order(), [1, 3, 4, 0, 2]);
    expect(find.text('2 sayfa seçili'), findsOneWidget, reason: 'seçim gider');
    await _shot(t, 'move-1-serit');
    await t.tap(find.byKey(const ValueKey('panel-selection-clear')));
    await t.pump();

    // 3) Fareyle: 2. sayfayı 1. sayfanın üst yarısına bırak.
    await showThumb(0);
    final first = t.getRect(thumb(0));
    final second = t.getRect(thumb(1));
    final mouse = await t.startGesture(
      second.center,
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -20));
    await t.pump();
    for (var k = 1; k <= 5; k++) {
      await mouse.moveTo(
        Offset.lerp(
          second.center,
          first.topCenter + const Offset(0, 20),
          k / 5,
        )!,
      );
      await t.pump();
    }
    await _shot(t, 'move-2-surukle');
    await mouse.up();
    await t.pump();
    await settled();
    expect(order(), [3, 1, 4, 0, 2]);

    // 4) Dokunmatik: 1. sayfaya uzun bas, 2. sayfanın alt yarısına sürükle.
    await showThumb(0);
    final a = t.getRect(thumb(0));
    final b = t.getRect(thumb(1));
    final touch = await t.startGesture(a.center);
    // Uzun basış zamanlayıcısı gerçek zamanla dolar.
    await Future<void>.delayed(kLongPressTimeout * 2);
    await t.pump();
    for (var k = 1; k <= 6; k++) {
      await touch.moveTo(
        Offset.lerp(a.center, b.bottomCenter - const Offset(0, 20), k / 6)!,
      );
      await t.pump();
    }
    await touch.up();
    await t.pump();
    await settled();
    expect(order(), [1, 3, 4, 0, 2]);
    expect(
      find.byKey(const ValueKey('panel-selection')),
      findsNothing,
      reason: 'taşıyınca seçim kipi açılmaz',
    );

    // 5) Kıpırdamadan uzun basış: taşımaz, seçim kipini açar.
    await showThumb(2);
    final hold = await t.startGesture(t.getCenter(thumb(2)));
    // Uzun basış zamanlayıcısı gerçek zamanla dolar.
    await Future<void>.delayed(kLongPressTimeout * 2);
    await t.pump();
    await hold.up();
    await t.pump();
    expect(order(), [1, 3, 4, 0, 2]);
    expect(find.text('1 sayfa seçili'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('panel-selection-clear')));
    await t.pump();

    // 6) Ctrl+Z son taşımayı geri alır.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await settled();
    expect(order(), [3, 1, 4, 0, 2]);

    // 7) Kaydet: dosyada sayfalar yeni sırada, çizgi 4. sayfada; orijinal
    // değişmez.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyS);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await _until(t, () => !session.isDirty);
    await settled();
    final saved = File('${dir.path}/ders_inken.pdf').readAsBytesSync();
    final read = (await t.runAsync(() => loadInkenFile(saved)))!;
    expect(read.pageCount, 5);
    final model = decodeInkenDocument(read.inkenJson!);
    expect(
      [for (final p in model.pages) (p.width, p.height)],
      [
        for (final s in [3, 1, 4, 0, 2]) sizes0[s],
      ],
    );
    expect((model.pages[3].items.single as Shape).kind, ShapeKind.line);
    final annots = (await t.runAsync(() => inspectAnnotations(saved)))!;
    expect(annots.map((a) => a.page), [3]);
    expect(order(), [0, 1, 2, 3, 4], reason: 'kayıttan sonra yeni numaralar');
    expect(
      original.readAsBytesSync(),
      fixture.readAsBytesSync(),
      reason: 'orijinale dokunulmaz',
    );
    await _shot(t, 'move-3-kayit');
  });
}
