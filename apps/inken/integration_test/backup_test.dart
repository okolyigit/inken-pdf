// Otomatik yedek ve kurtarma, gerçek uygulamada (PDFium worker isolate'i ile).
// Çalıştır: flutter test integration_test/backup_test.dart -d linux
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

Future<void> _until(WidgetTester t, Future<bool> Function() done) async {
  for (var i = 0; i < 100; i++) {
    if (await t.runAsync(done) ?? false) return;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  fail('zaman aşımı');
}

Future<bool> _sync(bool value) async => value;

Future<void> _draw(WidgetTester t, double y) async {
  final layer = t.widget<InkLayer>(find.byType(InkLayer));
  final box = t.getRect(find.byType(InkLayer));
  final v = layer.geometry.viewportOf(0)!;
  final g = await t.startGesture(
    box.topLeft + v.toView(Offset(100, y)),
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  for (var i = 1; i <= 5; i++) {
    await g.moveTo(
      box.topLeft + v.toView(Offset(100 + i * 30.0, y + i * 2.0)),
      timeStamp: Duration(milliseconds: 12 * i),
    );
  }
  await g.up();
  await t.pump();
}

Future<void> _menu(WidgetTester t, String item) => fileCommand(t, item);

Future<void> _saveViaMenu(WidgetTester t) => _menu(t, 'Kaydet');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('yedek alınır, kayıtta silinir, çökmeden sonra geri yüklenir', (
    t,
  ) async {
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_backup_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final backupDir = Directory('${dir.path}/backups');
    final original = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );

    ProviderContainer start() {
      final c = ProviderContainer(
        overrides: [
          backupStoreProvider.overrideWithValue(BackupStore.at(backupDir)),
          backupIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 200),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<List<InkenBackup>> backups() => BackupStore.at(backupDir).list();

    // 1. Aç, çiz: yedek alınır.
    var container = start();
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await t.pump();
    await t.runAsync(
      () => container
          .read(openDocumentProvider.notifier)
          .openBytes(
            name: 'ders.pdf',
            bytes: original.readAsBytesSync(),
            path: original.path,
          ),
    );
    await t.pump();
    await _until(t, () => _sync(find.byType(InkLayer).evaluate().isNotEmpty));
    await _draw(t, 200);
    await _until(t, () async => (await backups()).isNotEmpty);
    var list = await t.runAsync(backups);
    expect(list!.single.sourcePath, original.path);
    expect(list.single.document.pages[0].items, hasLength(1));

    // 2. Kaydet: yedek silinir.
    await _saveViaMenu(t);
    await _until(t, () async => (await backups()).isEmpty);
    final saved = File('${dir.path}/ders_inken.pdf');
    expect(saved.existsSync(), isTrue);

    // 3. Yeniden çiz: yedek artık kaydedilen dosyaya ait.
    await _draw(t, 240);
    await _until(t, () async => (await backups()).isNotEmpty);
    list = await t.runAsync(backups);
    expect(list!.single.sourcePath, saved.path);
    expect(list.single.document.pages[0].items, hasLength(2));

    // 4. "Çökme": uygulama kaydetmeden gider, yedek kalır.
    await t.pumpWidget(const SizedBox());
    container.dispose();
    expect(await t.runAsync(backups), hasLength(1));

    // 5. Yeniden başlat: kurtarma sorulur, geri yüklenir.
    container = start();
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await _until(
      t,
      () => _sync(
        find.text('Kaydedilmemiş çizimler bulundu').evaluate().isNotEmpty,
      ),
    );
    expect(find.textContaining('ders_inken.pdf'), findsOneWidget);
    await t.tap(find.text('Geri yükle'));
    await _until(t, () => _sync(find.byType(InkLayer).evaluate().isNotEmpty));
    final session = t.widget<InkLayer>(find.byType(InkLayer)).session;
    expect(session.document.pages[0].items, hasLength(2));
    expect(session.isDirty, isTrue);
    // Geri al, dosyadaki hale döner.
    session.undo();
    expect(session.document.pages[0].items, hasLength(1));
    session.redo();

    // 6. Değişiklikleri bırakıp kapat: yedek silinir, yeniden sorulmaz.
    await _menu(t, 'Belgeyi kapat');
    await t.tap(find.text('Kaydetme'));
    await _until(t, () async => (await backups()).isEmpty);
    await t.pumpAndSettle();
    expect(find.text('Kaydedilmemiş çizimler bulundu'), findsNothing);
    expect(
      decodeInkenDocument(
        (await t.runAsync(() => loadInkenFile(saved.readAsBytesSync())))!
            .inkenJson!,
      ).pages[0].items,
      hasLength(1),
      reason: 'bırakılan değişiklik dosyaya yazılmamalı',
    );
  });
}
