// Sayfa ekle / sil gerçek uygulamada: hızlı erişim çubuğundan kareli sayfa
// ekle → yeni sayfaya çiz → sayfa sil → geri al → yeniden sil → kaydet →
// dosyada sayfalar ve açıklamalar doğru → yeniden aç.
// Çalıştır: flutter test integration_test/pages_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
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
  expect(done(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ekle → çiz → sil → geri al → kaydet → yeniden aç', (t) async {
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_pages_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final container = ProviderContainer();
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
    final box = t.getRect(find.byType(InkLayer));

    /// Görüntüleyici [pages] sayfayla yeniden yüklendi ve katman açık.
    Future<void> settled(int pages) => _until(
      t,
      () =>
          gate.open &&
          viewer.pageCount == pages &&
          session.document.pages.length == pages,
    );

    Future<void> drawOn(int page) async {
      final v = gate.viewportOf(page)!;
      final g = await t.startGesture(
        box.topLeft + v.toView(const Offset(80, 120)),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(box.topLeft + v.toView(Offset(80 + i * 15.0, 120)));
        await t.pump();
      }
      await g.up();
      await t.pump();
    }

    await settled(2);
    await drawOn(0);
    expect(session.document.pages[0].items, hasLength(1));

    // 1) Hızlı erişim çubuğu → Sayfa ekle → Kareli: 1. sayfanın arkasına.
    await t.tap(find.byKey(const ValueKey('quick-insert-page')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('quick-insert-grid')));
    await t.pump();
    await settled(3);
    expect(session.document.pages.map((p) => p.sourceIndex), [0, null, 1]);
    expect(session.document.pages[1].template, PageTemplate.grid);
    expect(viewer.currentPage, 1, reason: 'eklenen sayfaya geçer');
    expect(session.document.pages[0].items, hasLength(1));
    await _shot(t, 'sayfa-1-eklendi');

    // 1b) + : son seçimlerle (kareli) belgenin sonuna; geri alınır.
    await t.tap(find.byKey(const ValueKey('quick-append-page')));
    await t.pump();
    await settled(4);
    expect(session.document.pages.map((p) => p.sourceIndex), [
      0,
      null,
      1,
      null,
    ]);
    expect(session.document.pages[3].template, PageTemplate.grid);
    expect(viewer.currentPage, 3, reason: 'eklenen sayfaya geçer');
    session.undo();
    await t.pump();
    await settled(3);
    expect(session.document.pages.map((p) => p.sourceIndex), [0, null, 1]);
    await viewer.jumpToPage(1);
    await t.pump();

    // 2) Yeni sayfaya çiz.
    await drawOn(1);
    expect(session.document.pages[1].items, hasLength(1));

    // 3) Son sayfayı sil, bildirimden geri al, yeniden sil.
    await viewer.jumpToPage(2);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quick-delete-page')));
    await t.pump();
    await settled(2);
    expect(find.text('3. sayfa silindi'), findsOneWidget);
    await t.tap(find.text('Geri al'));
    await t.pump();
    await settled(3);
    expect(session.document.pages.map((p) => p.sourceIndex), [0, null, 1]);
    await viewer.jumpToPage(2);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quick-delete-page')));
    await t.pump();
    await settled(2);
    expect(session.document.pages.map((p) => p.sourceIndex), [0, null]);

    // 4) Kaydet: dosyada 2 sayfa (biri kareli), çizimler doğru sayfalarda.
    await t.tap(find.byKey(const ValueKey('quick-save')));
    await t.pump();
    await _until(t, () => !session.isDirty);
    await settled(2);
    final saved = File('${dir.path}/ders_inken.pdf').readAsBytesSync();
    final read = (await t.runAsync(() => loadInkenFile(saved)))!;
    expect(read.pageCount, 2);
    final model = decodeInkenDocument(read.inkenJson!);
    expect(model.pages.map((p) => p.sourceIndex), [0, 1]);
    expect(model.pages[1].template, PageTemplate.grid);
    final annots = (await t.runAsync(() => inspectAnnotations(saved)))!;
    expect(annots.map((a) => a.page).toList()..sort(), [0, 1]);
    expect(session.document.pages.map((p) => p.sourceIndex), [
      0,
      1,
    ], reason: 'kayıttan sonra yeni dosyanın numaraları');

    // 5) Kayıttan sonra çizim doğru sayfaya düşer; yeniden kayıt bozmaz.
    await viewer.jumpToPage(1);
    await t.pump();
    await drawOn(1);
    expect(session.document.pages[1].items, hasLength(2));
    await _shot(t, 'sayfa-2-kayit-sonrasi');
    await t.tap(find.byKey(const ValueKey('quick-save')));
    await t.pump();
    await _until(t, () => !session.isDirty);
    final again = File('${dir.path}/ders_inken.pdf').readAsBytesSync();
    final read2 = (await t.runAsync(() => loadInkenFile(again)))!;
    expect(read2.pageCount, 2);
    expect(decodeInkenDocument(read2.inkenJson!).pages[1].items, hasLength(2));
    expect(
      File('${dir.path}/ders.pdf').readAsBytesSync(),
      File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      reason: 'orijinale dokunulmaz',
    );
  });
}
