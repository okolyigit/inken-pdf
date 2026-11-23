// Bölge yakalama gerçek uygulamada: Ctrl+Shift+C → alan sürüklenir →
// Kopyala: panoda çizimleri gömülü, 200 dpi PNG; dokunuş → sayfanın tamamı
// → "Yeni sayfaya al": arkasına eklenen sayfanın üstünde görsel, tek geri
// alma adımı; Esc örtüyü kapatır. Pano sahte (gerçek panoya dokunulmaz).
// Çalıştır: flutter test integration_test/capture_test.dart -d linux
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
import 'package:inken/features/capture/capture_layer.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/platform/clipboard_service.dart';
import 'package:inken/platform/share_service.dart';
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

class _FakeClipboard implements ClipboardService {
  Uint8List? image;

  @override
  Future<Uint8List?> readImage() async => image;

  @override
  Future<bool> writeImage(Uint8List png) async {
    image = png;
    return true;
  }
}

class _FakeSharer implements ShareService {
  final shared = <(String name, String mime, List<String> files)>[];

  @override
  bool get supported => true;

  @override
  Future<ShareOutcome> sharePdf(String path, {required String name}) async =>
      ShareOutcome.shared;

  @override
  Future<ShareOutcome> shareFiles(
    List<String> paths, {
    required String name,
    required String mime,
  }) async {
    shared.add((name, mime, [for (final p in paths) p.split('/').last]));
    for (final p in paths) {
      expect(File(p).lengthSync(), greaterThan(1000));
    }
    return ShareOutcome.shared;
  }

  @override
  Future<bool> shareText(String text, {required String subject}) async => false;
}

Future<void> _captureKey(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyC);
  await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump(const Duration(milliseconds: 100));
}

/// PNG'nin boyutu ve kırmızı (çizim) piksel sayısı.
Future<({int width, int height, int red})> _inspect(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  var red = 0;
  for (var i = 0; i + 3 < px.length; i += 4) {
    if (px[i] > 180 && px[i + 1] < 90 && px[i + 2] < 90) red++;
  }
  final r = (width: image.width, height: image.height, red: red);
  image.dispose();
  codec.dispose();
  return r;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alan yakala → kopyala; dokun → yeni sayfaya al; Esc', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_capture_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final clipboard = _FakeClipboard();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
        clipboardServiceProvider.overrideWithValue(clipboard),
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
    InkLayer layer() => t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer().session;

    // İlk sayfaya kalın kırmızı bir çizgi (yakalanan görüntüde görünmeli).
    session.pasteItems(0, const [
      Shape(
        id: 'kirmizi',
        kind: ShapeKind.line,
        color: 0xFFD42A3F,
        width: 8,
        x1: 120,
        y1: 120,
        x2: 260,
        y2: 220,
      ),
    ]);
    session.clearSelection();
    await t.pump();

    // 1) Ctrl+Shift+C: örtü açılır.
    await _captureKey(t);
    expect(find.byType(CaptureLayer), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-bar')), findsNothing);

    // 2) Sayfa uzayında (80, 80) – (300, 260) sürükle: çubuk çıkar.
    final origin = t.getRect(find.byType(InkLayer)).topLeft;
    final view = layer().geometry.viewportOf(0)!;
    final from = origin + view.toView(const Offset(80, 80));
    final to = origin + view.toView(const Offset(300, 260));
    final g = await t.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 10)!);
      await t.pump();
    }
    await g.up();
    await t.pump();
    expect(find.byKey(const ValueKey('capture-bar')), findsOneWidget);
    await _shot(t, 'yakalama_secim');

    // 3) Kopyala: panoda 200 dpi PNG, kırmızı çizgi içinde; örtü kapanır.
    await t.tap(find.byKey(const ValueKey('capture-copy')));
    await _until(t, () => clipboard.image != null);
    await _until(t, () => find.byType(CaptureLayer).evaluate().isEmpty);
    final copied = await _inspect(clipboard.image!);
    // Bölge ekran pikseline yuvarlanır: kenarlarda bir iki pt pay.
    expect(copied.width, closeTo(220 * 200 / 72, 12));
    expect(copied.height, closeTo(180 * 200 / 72, 12));
    expect(copied.red, greaterThan(1000), reason: 'çizim görüntüde');
    expect(find.text('Görsel panoya kopyalandı'), findsOneWidget);

    // 4) Yeniden aç, sayfaya dokun: sayfanın tamamı seçilir.
    await _captureKey(t);
    final center = origin + view.toView(const Offset(200, 160));
    await t.tapAt(center, kind: PointerDeviceKind.mouse);
    await t.pump();
    expect(find.byKey(const ValueKey('capture-bar')), findsOneWidget);

    // 5) Yeni sayfaya al: 2. sırada eklenen sayfanın üstünde görsel.
    final before = session.document.pages.length;
    final source = session.document.pages[0];
    await t.tap(find.byKey(const ValueKey('capture-newPage')));
    await _until(t, () => session.document.pages.length == before + 1);
    await _until(t, () => find.byType(CaptureLayer).evaluate().isEmpty);
    final added = session.document.pages[1];
    expect(added.isInserted, isTrue);
    expect((added.width, added.height), (source.width, source.height));
    final image = added.items.single as ImageItem;
    expect(
      image.width / image.height,
      closeTo(source.width / source.height, 0.01),
    );
    expect(image.height, lessThanOrEqualTo(added.height * 0.6 + 1e-6));
    expect(image.y, closeTo(36, 1e-6));
    expect(session.images.png(image.imageId), isNotNull);
    await _shot(t, 'yakalama_yeni_sayfa');

    // Tek geri alma adımı: sayfa görseliyle birlikte gider.
    session.undo();
    await t.pump();
    expect(session.document.pages.length, before);

    // 6) Esc örtüyü kapatır.
    await _captureKey(t);
    expect(find.byType(CaptureLayer), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byType(CaptureLayer), findsNothing);
  });

  testWidgets('bölge görüntüsü tam sayfanın aynı yerinden kırpılmışıdır', (
    t,
  ) async {
    await initInkenPdf();
    final imager = await PdfPageImager.open(
      File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
    );
    addTearDown(imager.dispose);
    final size = imager.pageSize(0);
    const scale = 2.0;
    final full = await imager.render(0, (
      left: 0,
      top: 0,
      right: size.width,
      bottom: size.height,
    ), scale: scale);
    const region = (left: 50.0, top: 60.0, right: 350.0, bottom: 160.0);
    final part = await imager.render(0, region, scale: scale);
    expect((part.width, part.height), (600, 200));
    expect(full.width, (size.width * scale).round());

    Future<Uint8List> rgba(Uint8List png) async {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      return data!.buffer.asUint8List();
    }

    final a = await rgba(full.bytes);
    final b = await rgba(part.bytes);
    var diff = 0, ink = 0, samples = 0;
    for (var y = 0; y < part.height; y += 3) {
      for (var x = 0; x < part.width; x += 3) {
        final i = (y * part.width + x) * 4;
        final j = ((y + 120) * full.width + (x + 100)) * 4;
        diff += (b[i] - a[j]).abs();
        if (b[i] < 128) ink++;
        samples++;
      }
    }
    expect(ink, greaterThan(50), reason: 'bölgede metin olmalı');
    expect(diff / samples, lessThan(4), reason: 'aynı yer');

    // Gri tonlama: her pikselde R = G = B.
    final gray = await rgba(
      (await imager.render(0, region, scale: 1, grayscale: true)).bytes,
    );
    for (var i = 0; i + 3 < gray.length; i += 4 * 97) {
      expect(gray[i], gray[i + 1]);
      expect(gray[i + 1], gray[i + 2]);
    }
  });

  testWidgets('sayfa paneli: görsel olarak kopyala; iki sayfayı paylaş', (
    t,
  ) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_capture_panel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final clipboard = _FakeClipboard();
    final sharer = _FakeSharer();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore.memory({'pagePanel': true}),
        ),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
        clipboardServiceProvider.overrideWithValue(clipboard),
        shareServiceProvider.overrideWithValue(sharer),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'ders.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(
      t,
      () => find.byKey(const ValueKey('page-thumb-1')).evaluate().isNotEmpty,
    );
    await t.pump(const Duration(milliseconds: 300));
    final page = t
        .widget<InkLayer>(find.byType(InkLayer))
        .session
        .document
        .pages[0];

    Future<void> openAsImage(int thumb) async {
      await t.tap(
        find.byKey(ValueKey('page-thumb-$thumb')),
        buttons: kSecondaryButton,
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('panel-as-image')));
      await t.pumpAndSettle();
    }

    // 1) Tek sayfa: Kopyala → panoda sayfanın tamamı, 200 dpi.
    await openAsImage(0);
    await t.tap(find.byKey(const ValueKey('panel-image-copy')));
    await _until(t, () => clipboard.image != null);
    final copied = await _inspect(clipboard.image!);
    expect(copied.width, closeTo(page.width * 200 / 72, 2));
    expect(copied.height, closeTo(page.height * 200 / 72, 2));

    // 2) İki sayfa seçili: Kopyala pasif, Paylaş iki PNG verir.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(find.byKey(const ValueKey('page-thumb-0')));
    await t.tap(find.byKey(const ValueKey('page-thumb-1')));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await openAsImage(1);
    final copy = t.widget<MenuItemButton>(
      find.byKey(const ValueKey('panel-image-copy')),
    );
    expect(copy.onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('panel-image-share')));
    await _until(t, () => sharer.shared.isNotEmpty);
    final (name, mime, files) = sharer.shared.single;
    expect(mime, 'image/png');
    expect(name, 'ders');
    expect(files, ['ders - sayfa 1.png', 'ders - sayfa 2.png']);
  });
}
