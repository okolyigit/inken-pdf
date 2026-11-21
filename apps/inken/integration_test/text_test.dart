// Metin aracı gerçek uygulamada: yaz → kaydet → PDF'te Stamp → yeniden aç.
// Çalıştır: flutter test integration_test/text_test.dart -d linux
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
import 'package:inken/features/ink/text_font_provider.dart';
import 'package:inken/features/ink/tool_state.dart';
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

  testWidgets('yaz → kaydet → PDF\'te Stamp → yeniden aç', (t) async {
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_text_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final font = await InkenTextFont.load();
    final container = ProviderContainer(
      overrides: [textFontProvider.overrideWithValue(font)],
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
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer.session;
    final box = t.getRect(find.byType(InkLayer));
    final v = layer.geometry.viewportOf(0)!;

    container.read(toolProvider.notifier)
      ..select(Tool.text)
      ..setTextColor(penColors[2]);
    await t.pump();
    final at = box.topLeft + v.toView(const Offset(80, 150));
    await t.tapAt(at, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 200));
    final editor = find.byKey(const ValueKey('text-editor'));
    expect(editor, findsOneWidget);
    await t.enterText(editor, 'Çöz: √x ≤ 2\nİyi şanslar');
    await t.pump();
    await _shot(t, 'metin-yazarken');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    final item = session.document.pages[0].items.whereType<TextItem>().single;
    expect(item.width, greaterThan(50));
    await _shot(t, 'metin-bitti');

    await t.runAsync(() => notifier.save(session.document));
    final saved = File('${dir.path}/ders_inken.pdf');
    expect(saved.existsSync(), isTrue);
    final annots = (await t.runAsync(
      () => inspectAnnotations(saved.readAsBytesSync()),
    ))!;
    expect(annots.where((a) => a.subtype == 13), hasLength(1)); // Stamp
    // Font gömülmedi: dosya küçük kaldı.
    expect(saved.lengthSync() - original.lengthSync(), lessThan(40 * 1024));

    // Yeniden aç: metin modelde aynen.
    final read = await t.runAsync(() => loadInkenFile(saved.readAsBytesSync()));
    final model = decodeInkenDocument(read!.inkenJson!);
    expect(model.pages[0].items.whereType<TextItem>().single, item);
  });
}
