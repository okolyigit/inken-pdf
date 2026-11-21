// Sayfa döndürme, yönlü sayfa ekleme ve yan panelden sayfa işlemleri
// gerçek uygulamada: panelde sağ tık → sağa döndür (çizim sayfayla döner) →
// "+" ile dikey kareli sayfa → Ctrl ile iki sayfa seç → sola döndür → sil →
// geri al → Sayfa menüsünden yatay sayfa → kaydet → dosyada boyutlar ve
// açıklamalar doğru.
// Çalıştır: flutter test integration_test/page_ops_test.dart -d linux
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

  testWidgets('döndür → ekle → çoklu seçim → sil → geri al → kaydet', (
    t,
  ) async {
    await initInkenPdf();
    await t.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final dir = Directory.systemTemp.createTempSync('inken_page_ops_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
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
                // Dokunmatik platformlardaki gibi 48 px dokunma alanı
                // (Android'de panel şeridi bununla taşıyordu).
                return doc == null
                    ? const SizedBox()
                    : Theme(
                        data: Theme.of(context).copyWith(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        child: ViewerPage(
                          key: ValueKey(doc.sourceName),
                          document: doc,
                        ),
                      );
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

    await settled();
    await _until(
      t,
      () => find.byKey(const ValueKey('page-thumb-1')).evaluate().isNotEmpty,
    );
    final portrait = (w: pages()[0].width, h: pages()[0].height);
    expect(portrait.h, greaterThan(portrait.w));

    // Birinci sayfanın sol üstüne çizgi.
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

    // 1) Küçük resimde sağ tık → Sağa döndür.
    await t.tap(
      find.byKey(const ValueKey('page-thumb-0')),
      buttons: kSecondaryButton,
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('panel-rotate-right')));
    await t.pump();
    await settled();
    expect(pages()[0].rotation, 1);
    expect((pages()[0].width, pages()[0].height), (portrait.h, portrait.w));
    final line = pages()[0].items.single as Shape;
    // Yatay çizgi dikey oldu, sayfanın sağ tarafında.
    expect(line.x1, closeTo(line.x2, 0.01));
    expect(line.x1, greaterThan(pages()[0].width / 2));
    await _shot(t, 'ops-1-donduruldu');

    // 2) Birinci sayfanın altındaki "+": dikey seç, kareli ekle.
    await t.tap(find.byKey(const ValueKey('page-add-0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('panel-insert-portrait')).first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('panel-insert-grid')));
    await t.pump();
    await settled();
    expect(pages().map((p) => p.sourceIndex), [0, null, 1]);
    expect(pages()[1].template, PageTemplate.grid);
    expect(
      orientationOf(pages()[1]),
      PageOrientation.portrait,
      reason: 'yatay sayfanın arkasına dikey',
    );
    expect(pages()[1].width, closeTo(portrait.w, 0.01));

    // 3) Ctrl ile 2. ve 3. sayfayı seç; şeritten sola döndür.
    await _until(
      t,
      () => find.byKey(const ValueKey('page-thumb-2')).evaluate().isNotEmpty,
    );
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(find.byKey(const ValueKey('page-thumb-1')));
    await t.tap(find.byKey(const ValueKey('page-thumb-2')));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(find.text('2 sayfa seçili'), findsOneWidget);
    // Şeridin düğmeleri panelin içinde kalır.
    final panelRight = t
        .getRect(find.byKey(const ValueKey('page-panel')))
        .right;
    for (final id in ['rotate-left', 'rotate-right', 'delete', 'clear']) {
      final r = t.getRect(find.byKey(ValueKey('panel-selection-$id')));
      expect(r.right, lessThanOrEqualTo(panelRight), reason: id);
    }
    await t.tap(find.byKey(const ValueKey('panel-selection-rotate-left')));
    await t.pump();
    await settled();
    expect(pages().map(orientationOf), everyElement(PageOrientation.landscape));
    expect(pages()[2].rotation, 3);
    expect(pages()[1].rotation, isNull, reason: 'eklenen sayfa: yalnız boyut');
    await _shot(t, 'ops-2-secim');

    // 4) Seçileni sil; bildirim; Ctrl+Z ile geri.
    await t.tap(find.byKey(const ValueKey('panel-selection-delete')));
    await t.pump();
    await settled();
    expect(pages().map((p) => p.sourceIndex), [0]);
    expect(find.text('2 sayfa silindi'), findsOneWidget);
    expect(find.byKey(const ValueKey('panel-selection')), findsNothing);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await settled();
    expect(pages().map((p) => p.sourceIndex), [0, null, 1]);

    // 5) Sayfa menüsünden: yön yatay, siyah, çizgili sayfa (son sayfanın
    // arkasına).
    await viewer.jumpToPage(2);
    await t.pump();
    await t.tap(find.text('Sayfa'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sayfa ekle'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('insert-landscape')).first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('insert-color-black')).first);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('insert-lined')));
    await t.pump();
    await settled();
    expect(pages(), hasLength(4));
    expect(pages()[3].template, PageTemplate.lined);
    expect(orientationOf(pages()[3]), PageOrientation.landscape);
    expect(pages()[3].color, PageColor.black);
    await _shot(t, 'ops-3-menu');

    // 6) Kaydet: dosyada döndürülmüş sayfalar, çizgi açıklaması 1. sayfada;
    // model sıfırlanır, orijinal değişmez.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyS);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await _until(t, () => !session.isDirty);
    await settled();
    final saved = File('${dir.path}/ders_inken.pdf').readAsBytesSync();
    final read = (await t.runAsync(() => loadInkenFile(saved)))!;
    expect(read.pageCount, 4);
    final model = decodeInkenDocument(read.inkenJson!);
    expect(model.pages.every((p) => p.rotation == null), isTrue);
    expect(
      model.pages.map(orientationOf),
      everyElement(PageOrientation.landscape),
    );
    expect(model.pages[0].items.single, line);
    expect(model.pages[3].color, PageColor.black);
    final annots = (await t.runAsync(() => inspectAnnotations(saved)))!;
    expect(annots.map((a) => a.page), [0]);
    expect(pages().every((p) => p.rotation == null), isTrue);
    expect(session.canUndo, isFalse);
    expect(
      File('${dir.path}/ders.pdf').readAsBytesSync(),
      File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      reason: 'orijinale dokunulmaz',
    );
    await _shot(t, 'ops-4-kayit');
  });
}
