// Seçim komutları gerçek uygulamada: Ctrl+A, Ctrl+C / V / X, başka sayfaya
// yapıştırma, Inken panosu ile panodaki görselin önceliği. Sistem panosu
// taklit edilir (kullanıcının gerçek panosu ezilmez).
// Çalıştır: flutter test integration_test/selection_test.dart -d linux
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/platform/clipboard_service.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

class _FakeImageClipboard implements ClipboardService {
  Uint8List? image;
  @override
  Future<Uint8List?> readImage() async => image;

  @override
  Future<bool> writeImage(Uint8List png) async {
    image = png;
    return true;
  }
}

Future<void> _ctrl(WidgetTester t, LogicalKeyboardKey key) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(key);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump(const Duration(milliseconds: 200));
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(const Color(0xFF1E88E5), BlendMode.src);
  final image = await recorder.endRecording().toImage(40, 20);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ctrl+A / C / V / X ve panonun önceliği', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    // Sistem panosunun metni taklit edilir.
    String? systemText;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.setData' => () {
          systemText = (call.arguments as Map)['text'] as String?;
          return null;
        }(),
        'Clipboard.getData' =>
          systemText == null ? null : <String, Object?>{'text': systemText},
        _ => null,
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final dir = Directory.systemTemp.createTempSync('inken_sel_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final images = _FakeImageClipboard();
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
        clipboardServiceProvider.overrideWithValue(images),
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
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await t.pump(const Duration(milliseconds: 300));
    final session = t.widget<InkLayer>(find.byType(InkLayer)).session;
    List<InkItem> items(int p) => session.document.pages[p].items;

    // İlk sayfaya iki öğe.
    session.pasteItems(0, const [
      Shape(
        id: 'a',
        kind: ShapeKind.rectangle,
        color: 0xFF1A1A1A,
        width: 2,
        x1: 100,
        y1: 100,
        x2: 200,
        y2: 160,
      ),
      Shape(
        id: 'b',
        kind: ShapeKind.line,
        color: 0xFF1A1A1A,
        width: 2,
        x1: 100,
        y1: 200,
        x2: 200,
        y2: 220,
      ),
    ]);
    session.clearSelection();
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.pump();

    // Ctrl+A: seç aracına geçer, sayfadaki her şey seçili.
    await _ctrl(t, LogicalKeyboardKey.keyA);
    expect(container.read(toolProvider).tool, Tool.select);
    expect(session.selection, hasLength(2));

    // Ctrl+C → sistem panosunda işaret; Ctrl+V → kaydırılmış kopya.
    await _ctrl(t, LogicalKeyboardKey.keyC);
    expect(systemText, startsWith('Inken PDF öğeleri'));
    await _ctrl(t, LogicalKeyboardKey.keyV);
    expect(items(0), hasLength(4));
    expect(session.selection, hasLength(2), reason: 'kopyalar seçili');

    // Ctrl+X: seçili kopyalar silinir, panoda kalır.
    await _ctrl(t, LogicalKeyboardKey.keyX);
    expect(items(0), hasLength(2));

    // İkinci sayfaya geç ve yapıştır: aynı koordinatlarda.
    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await _until(
      t,
      () =>
          t.widget<Text>(find.byKey(const ValueKey('page-number'))).data == '2',
    );
    await _ctrl(t, LogicalKeyboardKey.keyV);
    expect(items(1), hasLength(2));
    expect((items(1).first as Shape).x1, closeTo(100 + 12, 1e-6));
    expect(session.selectionPage, 1);

    // Başka uygulamada görsel kopyalandı: sistem panosundaki işaret gitti,
    // Ctrl+V görseli yapıştırır.
    systemText = null;
    images.image = await _png();
    await _ctrl(t, LogicalKeyboardKey.keyV);
    await _until(t, () => items(1).whereType<ImageItem>().isNotEmpty);
    expect(items(1), hasLength(3));
  });
}
