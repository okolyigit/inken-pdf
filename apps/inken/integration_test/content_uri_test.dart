// Android (SAF) akışı, sahte content:// katmanıyla Linux'ta: düz PDF'in ilk
// kaydında yer sorulur, sonraki kayıtlar aynı URI'ye gider; dışa aktarma,
// yedek ve kurtarma URI ile çalışır.
// Çalıştır: flutter test integration_test/content_uri_test.dart -d linux
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/document_io.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

/// Bellekte content:// belgeleri; kayıt penceresi sıradaki hazır yanıtı döner.
class _FakeSaf extends DocumentIo {
  final Map<String, Uint8List> files = {};
  final List<DocTarget> nextSave = [];
  final List<String> suggested = [];

  @override
  Future<PickedDocument?> pickOpen({required String typeLabel}) async => null;

  @override
  Future<DocTarget?> pickSave({
    required String suggestedName,
    required String typeLabel,
    String? near,
    SaveFormat format = SaveFormat.pdf,
  }) async {
    suggested.add(suggestedName);
    return nextSave.isEmpty ? null : nextSave.removeAt(0);
  }

  @override
  Future<Uint8List> read(String location) async =>
      files[location] ?? (throw FileSystemException('yok', location));

  @override
  Future<void> write(String location, Uint8List bytes) async =>
      files[location] = bytes;

  @override
  Future<DocStat?> stat(String location) async {
    final f = files[location];
    return f == null
        ? null
        : (size: f.length, modified: DateTime.fromMillisecondsSinceEpoch(0));
  }
}

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

Future<String?> _json(WidgetTester t, Uint8List pdf) async =>
    (await t.runAsync(() => loadInkenFile(pdf)))!.inkenJson;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('content:// belge: kaydet, yeniden kaydet, dışa aktar, kurtar', (
    t,
  ) async {
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    await initInkenPdf();
    final dir = Directory.systemTemp.createTempSync('inken_saf_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final saf = _FakeSaf();
    const original = 'content://fake/document/1';
    const saved = 'content://fake/document/2';
    const exported = 'content://fake/document/3';
    final originalBytes = File('../../test/fixtures/two_pages.pdf')
        .readAsBytesSync();
    saf.files[original] = originalBytes;

    ProviderContainer start() {
      final c = ProviderContainer(
        overrides: [
          documentIoProvider.overrideWithValue(saf),
          backupStoreProvider.overrideWithValue(
            BackupStore.at(Directory('${dir.path}/backups')),
          ),
          backupIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 200),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<List<InkenBackup>> backups() =>
        BackupStore.at(Directory('${dir.path}/backups')).list();

    var container = start();
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await t.pump();
    await t.runAsync(
      () => container
          .read(openDocumentProvider.notifier)
          .openBytes(name: 'ders.pdf', bytes: originalBytes, path: original),
    );
    await t.pump();
    await _until(t, () => _sync(find.byType(InkLayer).evaluate().isNotEmpty));

    // 1. Çiz: yedek URI ve adla alınır.
    await _draw(t, 200);
    await _until(t, () async => (await backups()).isNotEmpty);
    final first = (await t.runAsync(backups))!.single;
    expect(first.sourcePath, original);
    expect(first.sourceName, 'ders.pdf');

    // 2. Kaydet: yanına yazılamadığı için yer sorulur.
    saf.nextSave.add((location: saved, name: 'ders_inken.pdf'));
    await fileCommand(t, 'Kaydet');
    await _until(t, () async => saf.files.containsKey(saved));
    await _until(t, () async => (await backups()).isEmpty);
    expect(saf.suggested, ['ders_inken.pdf']);
    expect(saf.files[original], same(originalBytes), reason: 'orijinal');
    expect(container.read(openDocumentProvider)!.path, saved);
    await t.pump();
    // Ad pencere başlığında; açık belgenin adı güncellenmiş olmalı.
    expect(container.read(openDocumentProvider)!.name, 'ders_inken.pdf');

    // 3. Yeniden çiz ve kaydet: sorulmadan aynı URI'ye.
    await _draw(t, 240);
    await fileCommand(t, 'Kaydet');
    await _until(t, () async {
      final read = await loadInkenFile(saf.files[saved]!);
      return decodeInkenDocument(read.inkenJson!).pages[0].items.length == 2;
    });
    expect(saf.suggested, hasLength(1), reason: 'ikinci kayıtta sorulmamalı');

    // 4. Dışa aktar (menüden): yeni URI, inken.json yok.
    saf.nextSave.add((location: exported, name: 'ders (çizimli).pdf'));
    await fileCommand(t, 'Dışa aktar…');
    await t.tap(find.byKey(const ValueKey('export-format-flattened')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('export-submit')));
    await _until(t, () async => saf.files.containsKey(exported));
    expect(await _json(t, saf.files[exported]!), isNull);

    // 5. Çiz, yedek alınsın, "çök", yeniden başlat ve kurtar.
    await _draw(t, 220);
    await _until(t, () async => (await backups()).isNotEmpty);
    await t.pumpWidget(const SizedBox());
    container.dispose();
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
    expect(session.document.pages[0].items, hasLength(3));
    expect(session.isDirty, isTrue);
    expect(container.read(openDocumentProvider)!.path, saved);
  });
}
