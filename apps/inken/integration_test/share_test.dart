// Paylaş gerçek uygulamada, sahte paylaşma servisiyle: hızlı erişim
// düğmesi → ekrandaki hâlin düzenlenebilir kopyası (inken: açıklamaları ve
// inken.json) geçici klasöre → servis; açık dosya değişmez. Telefonda araç
// rafı kapalı gelir (el aracı), üst çubuktaki düğmeyle açılır; paylaş
// düğmesi de üst çubukta.
// Çalıştır: flutter test integration_test/share_test.dart -d linux
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/mobile_dock.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/platform/share_service.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

class _FakeSharer implements ShareService {
  ShareOutcome Function() outcome = () => ShareOutcome.mailed;
  final calls = <(String path, String name, Uint8List bytes)>[];

  @override
  bool get supported => true;

  @override
  Future<ShareOutcome> sharePdf(String path, {required String name}) async {
    calls.add((path, name, File(path).readAsBytesSync()));
    return outcome();
  }

  @override
  Future<ShareOutcome> shareFiles(
    List<String> paths, {
    required String name,
    required String mime,
  }) async {
    for (final path in paths) {
      calls.add((path, name, File(path).readAsBytesSync()));
    }
    return outcome();
  }

  @override
  Future<bool> shareText(String text, {required String subject}) async => false;
}

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paylaş: düzenlenebilir kopya; telefonda raf kapalı gelir', (
    t,
  ) async {
    await initInkenPdf();
    final fixture = File('../../test/fixtures/two_pages.pdf').readAsBytesSync();
    final dir = Directory.systemTemp.createTempSync('inken_share_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')..writeAsBytesSync(fixture);
    final sharer = _FakeSharer();
    final container = ProviderContainer(
      overrides: [shareServiceProvider.overrideWithValue(sharer)],
    );
    addTearDown(container.dispose);
    await t.runAsync(
      () => container
          .read(openDocumentProvider.notifier)
          .openBytes(
            name: 'ders.pdf',
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

    // Kaydedilmemiş bir çizgi.
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.pump();
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

    // 1) Masaüstü: ayarların yanındaki düğme.
    await t.tap(find.byKey(const ValueKey('quick-share')));
    await _until(t, () => sharer.calls.isNotEmpty);
    await t.pump(const Duration(milliseconds: 200));
    final (path, name, bytes) = sharer.calls.single;
    expect(name, 'ders.pdf');
    expect(path.endsWith('/ders.pdf'), isTrue, reason: path);
    expect(path, isNot(original.path));
    expect(File(path).existsSync(), isTrue, reason: 'alan uygulama okuyacak');
    final read = (await t.runAsync(() => loadInkenFile(bytes)))!;
    expect(read.inkenJson, isNotNull, reason: 'düzenlenebilir');
    expect(read.pageCount, 2);
    final annots = (await t.runAsync(() => inspectAnnotations(bytes)))!;
    expect(annots.where((a) => a.name.startsWith('inken:')), hasLength(1));
    expect(find.text('Dosya yeni e-postaya eklendi'), findsOneWidget);
    expect(original.readAsBytesSync(), fixture, reason: 'açık dosya değişmez');

    // 2) Telefon: raf kapalı, el aracı; düğmeyle açılır, kalem geri gelir.
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpAndSettle();
    expect(find.byType(MobileDock), findsNothing);
    expect(container.read(toolProvider).tool, Tool.hand);
    await t.tap(find.byKey(const ValueKey('phone-tools')));
    await t.pumpAndSettle();
    expect(find.byType(MobileDock), findsOneWidget);
    expect(container.read(toolProvider).tool, Tool.pen);
    await t.tap(find.byKey(const ValueKey('phone-tools')));
    await t.pumpAndSettle();
    expect(find.byType(MobileDock), findsNothing);
    expect(container.read(toolProvider).tool, Tool.hand);

    // Üst çubukta paylaş.
    sharer.outcome = () => ShareOutcome.started;
    await t.tap(find.byKey(const ValueKey('share')));
    await _until(t, () => sharer.calls.length == 2);
    await t.pump(const Duration(milliseconds: 200));

    // Masaüstü yerleşimine dönünce araç geri gelir.
    t.view.reset();
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.pen);
  });
}
