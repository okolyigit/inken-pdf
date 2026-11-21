// Gerçek uygulamada (PDFium yüklü) görüntüleme ve çizimi doğrular.
// Çalıştır: flutter test integration_test/viewer_test.dart -d linux
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
import 'package:inken/features/ink/ink_toolbar.dart';
import 'package:inken/features/ink/tool_state.dart';
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
  // pdfrx sayfa görüntülerini eşzamansız üretir; yerleşmesini bekle.
  for (var i = 0; i < 15; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_shotDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

InkenViewerController layerController(WidgetTester t) =>
    (t.widget<InkLayer>(find.byType(InkLayer)).geometry as LayoutGate).inner
        as InkenViewerController;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PDF açılır; çizim sayfaya bağlıdır ve kaydırmayla birlikte gider',
    (t) async {
      await initInkenPdf();
      final bytes = File('../../test/fixtures/two_pages.pdf').readAsBytesSync();
      final doc = OpenDocument(name: 'two_pages.pdf', bytes: bytes);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await t.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ViewerPage(document: doc),
            ),
          ),
        ),
      );
      for (var i = 0; i < 50 && find.byType(InkLayer).evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pump(const Duration(milliseconds: 100));
      expect(
        t.widget<Text>(find.byKey(const ValueKey('page-number'))).data,
        '1',
      );
      expect(find.text(' / 2'), findsOneWidget);

      final layer = t.widget<InkLayer>(find.byType(InkLayer));
      final session = layer.session;
      final geometry = layer.geometry;
      final box = t.getRect(find.byType(InkLayer));
      expect(geometry.isReady, isTrue);
      PageViewport page0() => geometry.viewportOf(0)!;
      expect(page0().scale, greaterThan(0));

      Future<void> stroke(List<Offset> pagePoints, {int stepMs = 12}) async {
        final v = page0();
        Offset global(Offset p) => box.topLeft + v.toView(p);
        final g = await t.startGesture(
          global(pagePoints.first),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        );
        for (final (i, p) in pagePoints.indexed.skip(1)) {
          await g.moveTo(
            global(p),
            timeStamp: Duration(milliseconds: stepMs * i),
          );
        }
        await g.up(
          timeStamp: Duration(milliseconds: stepMs * pagePoints.length),
        );
        await t.pump();
      }

      // 1) Kalem: sayfa uzayında bilinen bir yerde dalgalı çizgi.
      final before = page0().rect;
      await stroke([
        for (var i = 0; i <= 40; i++)
          Offset(80 + i * 8.0, 200 + 18 * (i.isEven ? 1 : -1) * (i % 5) / 5),
      ]);
      expect(page0().rect, before, reason: 'çizerken sayfa kaymamalı');
      var items = session.document.pages[0].items;
      expect(items.length, 1);
      var s = items.single as Stroke;
      expect(s.points.first.x, closeTo(80, 0.5));
      expect(s.points.first.y, closeTo(200, 0.5));
      expect(s.points.last.x, closeTo(400, 0.5));

      // 2) Fosforlu: başlığın üstünden (fixture'da başlık y≈60–90 pt).
      container.read(toolProvider.notifier).select(Tool.highlighter);
      await t.pump();
      await stroke([
        const Offset(70, 74),
        const Offset(200, 74),
        const Offset(330, 74),
      ]);
      // 3) Kırmızı kalın kalem, yavaş ve hızlı kısımlar (hıza göre kalınlık).
      container.read(toolProvider.notifier)
        ..select(Tool.pen)
        ..setPenColor(penColors[1])
        ..setPenWidth(2);
      await t.pump();
      await stroke([
        for (var i = 0; i <= 30; i++) Offset(80 + i * 1.5, 235 + i * 0.5),
        for (var i = 1; i <= 12; i++) Offset(125 + i * 28.0, 250 - i * 1.0),
      ]);
      items = session.document.pages[0].items;
      expect(items.length, 3);
      s = items.last as Stroke;
      expect(
        s.points.first.p,
        greaterThan(s.points.last.p),
        reason: 'hızlı kısım daha ince',
      );
      await _shot(t, '1-cizim');

      // 4) Fare tekerleği: görüntüleyici kayar, model değişmez, çizgi sayfayla gider.
      final modelBefore = session.document;
      final center = box.center;
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(pointer.hover(center));
      await t.sendEventToBinding(pointer.scroll(const Offset(0, 240)));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(
        page0().rect.top,
        lessThan(before.top),
        reason: 'sayfa yukarı kaydı',
      );
      expect(page0().rect.width, closeTo(before.width, 0.01));
      expect(session.document, modelBefore);
      await _shot(t, '2-kaydirilmis');

      // 5) Kaydırılmış haldeyken çizilen çizgi yine doğru sayfa koordinatında.
      //    Noktalar ekranın görünen kısmından seçilir.
      final p1 = page0().toPage(const Offset(300, 510));
      final p2 = page0().toPage(const Offset(700, 540));
      await stroke([p1, p2]);
      expect(session.document.pages[0].items.length, 4);
      s = session.document.pages[0].items.last as Stroke;
      expect(s.points.first.x, closeTo(p1.dx, 0.5));
      expect(s.points.first.y, closeTo(p1.dy, 0.5));
      expect(s.points.last.x, closeTo(p2.dx, 0.5));

      // 6) Silgi (klavyeden: E) ve geri al (Ctrl+Z).
      await t.sendKeyEvent(LogicalKeyboardKey.keyE);
      await t.pump();
      expect(container.read(toolProvider).tool, Tool.eraser);
      final mid = (p1 + p2) / 2;
      await stroke([mid.translate(0, -20), mid.translate(0, 20)]);
      expect(session.document.pages[0].items.length, 3);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(session.document.pages[0].items.length, 4);
      await t.pump();
      await _shot(t, '3-son');

      // 7) Alt ortadaki sayfa gezgini ve sağ alttaki yakınlaştırma.
      final numberBox = t.getRect(
        find.byKey(const ValueKey('page-number-button')),
      );
      await t.tap(find.byKey(const ValueKey('page-number-button')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-input')), findsOneWidget);
      expect(
        t.getRect(find.byKey(const ValueKey('page-number-button'))),
        numberBox,
      );
      await t.enterText(find.byKey(const ValueKey('page-input')), '2');
      await t.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 30 && layerController(t).currentPage != 1; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(layerController(t).currentPage, 1);
      await t.tap(find.byKey(const ValueKey('page-prev')));
      for (var i = 0; i < 30 && layerController(t).currentPage != 0; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }

      // Sağ alttaki yakınlaştırma: + ve kaydırma çubuğu.
      final z0 = layerController(t).zoom;
      await t.tap(find.byKey(const ValueKey('zoom-in')));
      for (var i = 0; i < 30 && layerController(t).zoom <= z0; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(layerController(t).zoom, greaterThan(z0));
      final slider = t.getRect(find.byKey(const ValueKey('zoom-slider')));
      await t.tapAt(slider.centerLeft.translate(4, 0));
      await t.pump(const Duration(milliseconds: 300));
      expect(layerController(t).zoom, lessThan(z0));
      await layerController(t).setZoom(z0);
      await t.pump(const Duration(milliseconds: 300));

      // 8) Tam ekran (F11): menü çubuğu gider, yüzen kutular (geri al
      //    dahil) kalır; Esc geri getirir. Masaüstünde ikinci çubuk yok.
      expect(find.byType(InkToolbar), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.f11);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byType(ToolDock), findsOneWidget);
      expect(find.byKey(const ValueKey('undo')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-hand')), findsOneWidget);
      expect(find.byType(PageNav), findsOneWidget);
      expect(find.byType(ZoomControl), findsOneWidget);
      expect(find.byKey(const ValueKey('exit-fullscreen')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(MenuBar), findsOneWidget);
      expect(find.byKey(const ValueKey('exit-fullscreen')), findsNothing);
    },
  );
}
