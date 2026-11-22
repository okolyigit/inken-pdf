// Yazdır gerçek uygulamada, sahte yazdırma servisiyle (gerçek yazıcıya iş
// gitmez): Ctrl+P ve hızlı erişim düğmesi → çizimleri gömülü geçici PDF →
// servis; sonuç bildirimi; geçici dosya silinir.
// Çalıştır: flutter test integration_test/print_test.dart -d linux
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/platform/print_service.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

class _FakePrinter implements PrintService {
  _FakePrinter(this.outcome);

  PrintOutcome Function() outcome;
  final calls = <(String path, String title, Uint8List bytes)>[];

  @override
  bool get supported => true;

  @override
  Future<PrintOutcome> printPdf(String path, {required String title}) async {
    calls.add((path, title, File(path).readAsBytesSync()));
    return outcome();
  }
}

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('yazdır: gömülü PDF servise gider, geçici dosya silinir', (
    t,
  ) async {
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_print_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final printer = _FakePrinter(() => PrintOutcome.printed);
    final container = ProviderContainer(
      overrides: [printServiceProvider.overrideWithValue(printer)],
    );
    addTearDown(container.dispose);
    await t.runAsync(
      () => container
          .read(openDocumentProvider.notifier)
          .openBytes(
            name: 'Limit: 1-2.pdf',
            bytes: original.readAsBytesSync(),
            path: original.path,
          ),
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
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
    );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 300));
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final box = t.getRect(find.byType(InkLayer));
    final v = layer.geometry.viewportOf(0)!;
    final g = await t.startGesture(
      box.topLeft + v.toView(const Offset(80, 120)),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(box.topLeft + v.toView(Offset(80 + i * 15.0, 140)));
      await t.pump();
    }
    await g.up();
    await t.pump();

    // 1) Hızlı erişim çubuğundaki düğme.
    await t.tap(find.byKey(const ValueKey('quick-print')));
    await _until(t, () => printer.calls.isNotEmpty);
    await t.pump(const Duration(milliseconds: 200));
    final (path, title, bytes) = printer.calls.single;
    expect(title, 'Limit: 1-2.pdf');
    expect(path.endsWith('/Limit_ 1-2.pdf'), isTrue, reason: path);
    expect(path, isNot(original.path));
    final read = (await t.runAsync(() => loadInkenFile(bytes)))!;
    expect(read.inkenJson, isNull, reason: 'Inken verisi yazdırılmaz');
    expect(read.pageCount, 2);
    expect(
      (await t.runAsync(() => inspectAnnotations(bytes)))!,
      isEmpty,
      reason: 'çizimler sayfaya gömülü',
    );
    expect(find.text('Yazıcıya gönderildi'), findsOneWidget);
    expect(File(path).existsSync(), isFalse, reason: 'geçici dosya silinir');
    expect(
      original.readAsBytesSync(),
      File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      reason: 'açık belge değişmez',
    );

    // 2) Ctrl+P; vazgeçilirse bildirim yok.
    printer.outcome = () => PrintOutcome.cancelled;
    ScaffoldMessenger.of(t.element(find.byType(InkLayer)))
        .removeCurrentSnackBar();
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyP);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _until(t, () => printer.calls.length == 2);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Yazıcıya gönderildi'), findsNothing);
    expect(File(printer.calls.last.$1).existsSync(), isFalse);

    // 3) Yazıcı PDF kabul etmiyor: açıklayıcı mesaj.
    printer.outcome = () => throw const PrinterUnsupported();
    await t.tap(find.byKey(const ValueKey('quick-print')));
    await _until(t, () => printer.calls.length == 3);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('PDF kabul etmiyor'), findsOneWidget);

    // 4) Telefon: yan menüde Dosya → Yazdır.
    printer.outcome = () => PrintOutcome.started;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('app-menu')));
    await t.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    await openDrawerSection(t, 'file');
    await t.tap(find.widgetWithText(ListTile, 'Yazdır…'));
    await _until(t, () => printer.calls.length == 4);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(Drawer), findsNothing, reason: 'menü kapanır');

    // Yan menü: bölümler kapanır, Ayarlar altta hep görünür.
    await t.tap(find.byKey(const ValueKey('app-menu')));
    await t.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Yazdır…'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('drawer-file')));
    await t.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Yazdır…'), findsNothing);
    final settings = find.widgetWithText(ListTile, 'Ayarlar…');
    expect(settings, findsOneWidget);
    expect(t.getRect(settings).bottom, lessThanOrEqualTo(800));
    t.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await t.pumpAndSettle();

    // ⋮ menüsü düğmenin altında, sağ kenara hizalı açılır.
    final more = t.getRect(find.byKey(const ValueKey('more')));
    await t.tap(find.byKey(const ValueKey('more')));
    await t.pumpAndSettle();
    final redo = t.getRect(find.widgetWithText(MenuItemButton, 'Yinele'));
    expect(redo.right, greaterThan(more.left), reason: '$redo $more');
    expect(redo.right, lessThanOrEqualTo(400));
    expect(redo.top, greaterThanOrEqualTo(more.bottom - 1));
    await t.tapAt(const Offset(100, 600));
    await t.pumpAndSettle();
  });
}
