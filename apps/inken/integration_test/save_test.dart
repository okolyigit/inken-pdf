// Gerçek uygulamada (PDFium worker isolate'i ile) kaydetme ve yeniden açma.
// Çalıştır: flutter test integration_test/save_test.dart -d linux
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/viewer/viewer_page.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

/// Dosya → Kaydet.
Future<void> _saveViaMenu(WidgetTester t) => fileCommand(t, 'Kaydet');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('çiz → kaydet → yeniden aç: çizim modelde ve dosyada', (t) async {
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final originalBytes = original.readAsBytesSync();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(openDocumentProvider.notifier);
    await t.runAsync(
      () => notifier.openBytes(
        name: 'ders.pdf',
        bytes: originalBytes,
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

    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer.session;
    final box = t.getRect(find.byType(InkLayer));
    final v = layer.geometry.viewportOf(0)!;
    final g = await t.startGesture(
      box.topLeft + v.toView(const Offset(100, 200)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(
        box.topLeft + v.toView(Offset(100 + i * 20.0, 200 + i * 3.0)),
        timeStamp: Duration(milliseconds: 12 * i),
      );
    }
    await g.up();
    await t.pump();
    expect(session.isDirty, isTrue);

    // Pencerenin kapat düğmesi: kaydedilmemiş değişiklik sorulur, Vazgeç
    // pencereyi açık tutar.
    final exit = t.binding.handleRequestAppExit();
    await t.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(await exit, AppExitResponse.cancel);
    expect(session.isDirty, isTrue);

    // Kaydet düğmesi.
    await _saveViaMenu(t);
    final target = File('${dir.path}/ders_inken.pdf');
    // Kayıt bitip durum satırı "Kaydedildi" olana kadar (isDirty daha
    // önce düşer, "Kaydediliyor…" bir an daha görünür).
    await _until(
      t,
      () => !session.isDirty && find.text('Kaydedildi').evaluate().isNotEmpty,
    );
    expect(target.existsSync(), isTrue);
    expect(
      original.readAsBytesSync(),
      originalBytes,
      reason: 'orijinale dokunulmamalı',
    );
    expect(container.read(openDocumentProvider)!.name, 'ders_inken.pdf');
    expect(find.text('Kaydedildi'), findsOneWidget, reason: 'durum satırı');
    expect(dir.listSync(), hasLength(2), reason: 'geçici dosya kalmamalı');

    // Düzleştirilmiş dışa aktarma: açıklama ve inken.json yok; açık dosyanın
    // üzerine yazılamaz, açık belge değişmez.
    final exported = File('${dir.path}/ders (çizimli).pdf');
    await t.runAsync(
      () => notifier.exportFlattened(session.document, exported.path),
    );
    final flat = exported.readAsBytesSync();
    expect((await t.runAsync(() => loadInkenFile(flat)))!.inkenJson, isNull);
    Object? overOpen;
    await t.runAsync(() async {
      try {
        await notifier.exportFlattened(session.document, target.path);
      } on ArgumentError catch (e) {
        overOpen = e;
      }
    });
    expect(overOpen, isA<ArgumentError>());
    expect(container.read(openDocumentProvider)!.path, target.path);
    exported.deleteSync();

    // Farklı kaydet: seçilen yola yazılır, açık belge artık o dosyadır;
    // önceki dosya değişmez.
    final before = target.readAsBytesSync();
    final copy = File('${dir.path}/kopya.pdf');
    final asOutcome = await t.runAsync(
      () => notifier.save(
        session.document,
        target: (location: copy.path, name: 'kopya.pdf'),
      ),
    );
    expect(asOutcome!.path, copy.path);
    expect(container.read(openDocumentProvider)!.path, copy.path);
    expect(target.readAsBytesSync(), before);
    expect(
      decodeInkenDocument(
        (await t.runAsync(() => loadInkenFile(copy.readAsBytesSync())))!
            .inkenJson!,
      ).pages[0].items,
      hasLength(1),
    );
    // Testin geri kalanı ders_inken.pdf ile sürer.
    await t.runAsync(
      () => notifier.save(
        session.document,
        target: (location: target.path, name: 'ders_inken.pdf'),
      ),
    );
    copy.deleteSync();

    // Kaydedilen dosyayı yeniden oku.
    final read = (await t.runAsync(
      () => loadInkenFile(target.readAsBytesSync()),
    ))!;
    final model = decodeInkenDocument(read.inkenJson!);
    final stroke = model.pages[0].items.single as Stroke;
    expect(stroke.points.first.x, closeTo(100, 0.5));
    expect(stroke.points.first.y, closeTo(200, 0.5));

    // İkinci kayıt aynı dosyaya gider (artık Inken dosyası). Nokta ekranın
    // görünen kısmında olmalı: sayfa ~2 kat büyütülmüş durumda.
    final g2 = await t.startGesture(
      box.topLeft + v.toView(const Offset(100, 240)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await g2.moveTo(
      box.topLeft + v.toView(const Offset(300, 250)),
      timeStamp: const Duration(milliseconds: 20),
    );
    await g2.up();
    await t.pump();
    await _saveViaMenu(t);
    await _until(t, () => !session.isDirty);
    expect(dir.listSync(), hasLength(2));
    final read2 = (await t.runAsync(
      () => loadInkenFile(target.readAsBytesSync()),
    ))!;
    expect(decodeInkenDocument(read2.inkenJson!).pages[0].items, hasLength(2));

    // Yeniden açınca model dosyadan gelir.
    await t.runAsync(
      () => notifier.openBytes(
        name: 'ders_inken.pdf',
        bytes: target.readAsBytesSync(),
        path: target.path,
      ),
    );
    await t.pump();
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    final reopened = t.widget<InkLayer>(find.byType(InkLayer)).session;
    expect(reopened, isNot(same(session)));
    expect(reopened.document.pages[0].items, hasLength(2));
    expect(reopened.isDirty, isFalse);
    // Değişiklik yokken pencere sormadan kapanır.
    expect(await t.binding.handleRequestAppExit(), AppExitResponse.exit);

    // Görüntüleyici Inken açıklamaları gizlenmiş kopyayı göstermeli; yoksa
    // çizimler hem PDF'ten hem katmandan çizilir ve silgi silemez gibi görünür.
    final reopenedDoc = container.read(openDocumentProvider)!;
    expect(reopenedDoc.displayBytes, isNot(same(reopenedDoc.bytes)));
    expect(
      t.widget<InkenPdfViewer>(find.byType(InkenPdfViewer)).data,
      same(reopenedDoc.displayBytes),
    );
  });
}
