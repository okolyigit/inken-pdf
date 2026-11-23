// Yazdır gerçek uygulamada, sahte yazdırma servisiyle (gerçek yazıcıya iş
// gitmez): Ctrl+P ve hızlı erişim düğmesi → Inken'in yazdırma penceresi
// (önizleme, yazıcı, sayfalar, kopya, çizimler, diğer seçenekler) →
// servis; sonuç bildirimi; geçici dosyalar silinir.
// Çalıştır: flutter test integration_test/print_test.dart -d linux
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
import 'package:inken/features/print/print_dialog.dart';
import 'package:inken/theme/dialog_form.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/platform/print_service.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

class _FakePrinter implements PrintService {
  _FakePrinter(this.outcome);

  PrintOutcome Function() outcome;
  bool choosing = true;
  final calls =
      <(String path, String title, PrintRequest r, Uint8List bytes)>[];
  final properties = <String>[];

  @override
  bool get supported => true;

  @override
  bool get choosesPrinter => choosing;

  @override
  bool get hasPrinterProperties => choosing;

  @override
  Future<List<PrinterInfo>> printers() async => const [
    PrinterInfo(name: 'Kat 2'),
    PrinterInfo(name: 'Ofis', isDefault: true, status: 'Hazır'),
  ];

  @override
  Future<void> printerProperties(String printer) async =>
      properties.add(printer);

  @override
  Future<PrintOutcome> printPdf(
    String path, {
    required String title,
    required PrintRequest request,
  }) async {
    calls.add((path, title, request, File(path).readAsBytesSync()));
    return outcome();
  }
}

/// `INKEN_SHOT=<klasör>` verilirse ekran görüntüsü oraya yazılır.
const _shotDir = String.fromEnvironment('INKEN_SHOT');

Future<void> _shot(WidgetTester t, String name) async {
  if (_shotDir.isEmpty) return;
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final dpr = t.view.devicePixelRatio;
  final size = view.size * dpr;
  final bytes = await t.runAsync(() async {
    final image = await layer.toImage(Offset.zero & size, pixelRatio: 1 / dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File('$_shotDir/print-$name.png').writeAsBytesSync(bytes!);
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

    Future<void> openDialog(Future<void> Function() open) async {
      await open();
      await _until(
        t,
        () => find
            .byKey(const ValueKey('print-preview-image'))
            .evaluate()
            .isNotEmpty,
      );
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<void> submit() async {
      await t.tap(find.byKey(const ValueKey('print-submit')));
      await t.pump();
    }

    // 1) Hızlı erişim düğmesi: pencere, varsayılan yazıcı, tüm sayfalar.
    await openDialog(() => t.tap(find.byKey(const ValueKey('quick-print'))));
    expect(find.byType(PrintDialog), findsOneWidget);
    expect(find.text('Ofis'), findsOneWidget, reason: 'varsayılan yazıcı');
    expect(find.text('Hazır · varsayılan yazıcı'), findsOneWidget);
    expect(find.text('2 sayfa · 1 kopya'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('print-next')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('2 / 2'), findsOneWidget);
    await _shot(t, 'desktop');
    await submit();
    await _until(t, () => printer.calls.isNotEmpty);
    await t.pump(const Duration(milliseconds: 200));
    final (path, title, request, bytes) = printer.calls.single;
    expect(title, 'Limit: 1-2.pdf');
    expect(path.endsWith('/Limit_ 1-2.pdf'), isTrue, reason: path);
    expect(path, isNot(original.path));
    expect(request.printer, 'Ofis');
    expect(request.pages, [0, 1]);
    expect(request.pageCount, 2);
    expect(request.copies, 1);
    expect(request.fit, isTrue);
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

    // 2) Ctrl+P: aralık, kopya, çizimsiz, gri, yazıcı özellikleri.
    ScaffoldMessenger.of(t.element(find.byType(InkLayer)))
        .removeCurrentSnackBar();
    await t.pump();
    await openDialog(() async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyP);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });
    await t.tap(find.byKey(const ValueKey('seg-PrintPages.range')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('print-range')), '9');
    await t.pump();
    expect(find.textContaining('Geçersiz aralık'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('print-submit')))
          .onPressed,
      isNull,
      reason: 'geçersiz aralıkta yazdırılamaz',
    );
    await t.enterText(find.byKey(const ValueKey('print-range')), '2');
    await t.tap(find.byKey(const ValueKey('print-copies-up')));
    await t.tap(find.byKey(const ValueKey('print-drawings')));
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.byKey(const ValueKey('print-more')));
    await t.tap(find.byKey(const ValueKey('print-more')));
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('seg-true')).first);
    await t.tap(find.byKey(const ValueKey('seg-true')).last); // gri
    await t.pump(const Duration(milliseconds: 300));
    await t.ensureVisible(find.byKey(const ValueKey('print-properties')));
    await t.tap(find.byKey(const ValueKey('print-properties')));
    await t.pump();
    expect(printer.properties, ['Ofis']);
    await _shot(t, 'desktop-more');
    expect(find.text('1 sayfa · 2 kopya'), findsOneWidget);
    await submit();
    await _until(t, () => printer.calls.length == 2);
    await t.pump(const Duration(milliseconds: 200));
    final second = printer.calls.last;
    expect(second.$3.pages, [1]);
    expect(second.$3.copies, 2);
    expect(second.$3.grayscale, isTrue);
    expect(second.$1, contains('cizimsiz-'), reason: 'çizimler basılmaz');
    expect(File(second.$1).existsSync(), isFalse);

    // 3) Vazgeç: servise gitmez; ayarlar hatırlanır (çizimsiz, gri).
    ScaffoldMessenger.of(t.element(find.byType(InkLayer)))
        .removeCurrentSnackBar();
    await openDialog(() => t.tap(find.byKey(const ValueKey('quick-print'))));
    expect(
      t.widget<FormSwitch>(find.byKey(const ValueKey('print-drawings'))).value,
      isFalse,
    );
    await t.tap(find.byKey(const ValueKey('print-cancel')));
    await t.pumpAndSettle();
    expect(find.byType(PrintDialog), findsNothing);
    expect(printer.calls, hasLength(2));

    // 4) Yazıcı PDF kabul etmiyor: açıklayıcı mesaj.
    printer.outcome = () => throw const PrinterUnsupported();
    await openDialog(() => t.tap(find.byKey(const ValueKey('quick-print'))));
    await submit();
    await _until(t, () => printer.calls.length == 3);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('PDF kabul etmiyor'), findsOneWidget);

    // 5) Telefon (Android gibi): yan menüde Dosya → Yazdır; yazıcı ve kopya
    // sistemin ekranında, pencerede yok.
    ScaffoldMessenger.of(t.element(find.byType(InkLayer)))
        .removeCurrentSnackBar();
    printer.outcome = () => PrintOutcome.started;
    printer.choosing = false;
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('app-menu')));
    await t.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    await openDrawerSection(t, 'file');
    await openDialog(() => t.tap(find.widgetWithText(ListTile, 'Yazdır…')));
    expect(find.byKey(const ValueKey('print-printer')), findsNothing);
    expect(find.byKey(const ValueKey('print-copies')), findsNothing);
    expect(find.textContaining('bir sonraki ekranda'), findsOneWidget);
    await _shot(t, 'phone');
    expect(t.takeException(), isNull);
    await submit();
    await _until(t, () => printer.calls.length == 4);
    await t.pumpAndSettle();
    expect(printer.calls.last.$3.printer, isNull);
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
