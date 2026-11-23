// Panodan görsel yapıştırma gerçek uygulamada: Ctrl+V → görsel ekranın
// ortasındaki sayfaya eklenir, seç aracı etkin ve görsel seçili → köşeden
// büyütülür → kaydedilir → dosyada görsel eki ve görünüm → yeniden açılınca
// görsel yerinde → düzleştirilmiş dışa aktarma. Pano sahte (gerçek panoya
// dokunulmaz); platform kanalı elle denenir.
// Çalıştır: flutter test integration_test/image_test.dart -d linux
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
import 'package:inken/features/ink/ink_painter.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/platform/clipboard_service.dart';
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

/// 600x300 "ekran görüntüsü": sol yarı kırmızı, sağ yarı mavi.
Future<Uint8List> _screenshot() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 300, 300),
      Paint()..color = const Color(0xFFE53935),
    )
    ..drawRect(
      const Rect.fromLTWH(300, 0, 300, 300),
      Paint()..color = const Color(0xFF1E88E5),
    );
  final image = await recorder.endRecording().toImage(600, 300);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> _ctrl(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('yapıştır → seçili → büyüt → kaydet → yeniden aç', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_image_it');
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
    final notifier = container.read(openDocumentProvider.notifier);
    await notifier.openBytes(
      name: 'ders.pdf',
      bytes: pdf.readAsBytesSync(),
      path: pdf.path,
    );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 500));
    InkLayer layer() => t.widget<InkLayer>(find.byType(InkLayer));

    // 1) Panoda görsel yok: bildirim, belge değişmez.
    await _ctrl(t, LogicalKeyboardKey.keyV);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Panoda görsel yok'), findsOneWidget);
    expect(layer().session.document.pages[0].items, isEmpty);

    // 2) Ctrl+V: görsel eklenir, seç aracı etkin, görsel seçili.
    clipboard.image = await _screenshot();
    await _ctrl(t, LogicalKeyboardKey.keyV);
    await _until(
      t,
      () => layer().session.document.pages.any((p) => p.items.isNotEmpty),
    );
    await t.pump(const Duration(milliseconds: 300));
    final session = layer().session;
    final page = session.document.pages.indexWhere((p) => p.items.isNotEmpty);
    final pasted = session.document.pages[page].items.single as ImageItem;
    expect(container.read(toolProvider).tool, Tool.select);
    expect(session.selection, {pasted.id});
    expect(pasted.width / pasted.height, closeTo(2, 1e-6), reason: 'oran');
    // 600 px → 450 pt doğal boyut; görünen alanın %80'ine sığdırılmış ya da
    // doğal boyutunda.
    expect(pasted.width, lessThanOrEqualTo(450 + 1e-6));
    expect(session.images.png(pasted.imageId), isNotNull);
    await _shot(t, 'yapistirildi');

    // 3) Sağ alt köşeden büyüt: sol üst sabit, oran korunur.
    final view = layer().geometry.viewportOf(page)!;
    final box = t.getRect(find.byType(InkLayer));
    final corner =
        box.topLeft +
        selectionCorners(selectionScreenRect(view, session, 4)!)[2];
    final g = await t.startGesture(corner, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(corner + Offset(6.0 * i, 3.0 * i));
      await t.pump();
    }
    await g.up();
    await t.pump();
    final resized = session.document.pages[page].items.single as ImageItem;
    expect(resized.width, greaterThan(pasted.width + 20));
    expect(resized.width / resized.height, closeTo(2, 1e-3));
    expect(resized.x, closeTo(pasted.x, 1e-6));
    expect(resized.y, closeTo(pasted.y, 1e-6));
    await _shot(t, 'buyutuldu');

    // 4) Kaydet: dosyada görsel eki ve Inken açıklaması.
    await _ctrl(t, LogicalKeyboardKey.keyS);
    final saved = File('${dir.path}/ders_inken.pdf');
    await _until(t, saved.existsSync);
    await _until(t, () => !session.isDirty);
    final bytes = saved.readAsBytesSync();
    final read = await loadInkenFile(bytes);
    final model = decodeInkenDocument(read.inkenJson!);
    expect(model.pages[page].items.single, resized);
    expect(read.images.keys, [resized.imageId]);
    final annots = await inspectAnnotations(bytes);
    expect(annots.where((a) => a.name == 'inken:${resized.id}'), hasLength(1));
    expect(annots.every((a) => a.hasAp), isTrue);

    // 5) Yeniden aç: görsel yerinde ve çözülmüş.
    await notifier.openBytes(
      name: 'ders_inken.pdf',
      bytes: bytes,
      path: saved.path,
    );
    await _until(
      t,
      () =>
          find.byType(InkLayer).evaluate().isNotEmpty &&
          !identical(layer().session, session),
    );
    final reopened = layer().session;
    expect(reopened.document.pages[page].items.single, resized);
    await _until(t, () => reopened.images.image(resized.imageId) != null);
    await _shot(t, 'yeniden-acildi');

    // 6) Düzleştirilmiş dışa aktarma: açıklama ve ek kalmaz.
    final target = '${dir.path}/ders (çizimli).pdf';
    await notifier.exportFlattened(
      reopened.document,
      target,
      images: await reopened.images.forWriting({resized.imageId}),
    );
    final flat = File(target).readAsBytesSync();
    expect(await inspectAnnotations(flat), isEmpty);
    final flatRead = await loadInkenFile(flat);
    expect(flatRead.inkenJson, isNull);
    expect(flatRead.images, isEmpty);
  });
}
