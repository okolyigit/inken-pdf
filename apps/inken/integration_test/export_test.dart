// Dışa aktarma penceresi gerçek uygulamada: Ctrl+E → biçim, sayfalar,
// boş eklenen sayfaları atla, önizleme → kayıt yeri → dosya. Çizimli PDF
// (inken.json yok, seçilen sayfalar), görsel (çok sayfa ZIP), düzenlenebilir
// PDF (aralık; inken.json var). Seçimler hatırlanır. Kayıt penceresi sahte,
// dosyalar diske gerçekten yazılır.
// Çalıştır: flutter test integration_test/export_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/export/export_dialog.dart';
import 'package:inken/features/files/document_io.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

import 'ui.dart';

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
  for (var i = 0; i < 150 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

/// Kayıt penceresi yerine: istenen adla klasöre yazar; dosyalar gerçek.
class _SaveIo extends PlatformDocumentIo {
  _SaveIo(this.dir);
  final Directory dir;
  final asked = <(String name, SaveFormat format)>[];

  @override
  Future<DocTarget?> pickSave({
    required String suggestedName,
    required String typeLabel,
    String? near,
    SaveFormat format = SaveFormat.pdf,
  }) async {
    asked.add((suggestedName, format));
    final path = '${dir.path}/out/$suggestedName';
    Directory('${dir.path}/out').createSync(recursive: true);
    return (location: path, name: suggestedName);
  }
}

/// ZIP'in son kaydındaki dosya sayısı.
int _zipCount(Uint8List zip) {
  final data = ByteData.sublistView(zip);
  final end = zip.length - 22;
  expect(data.getUint32(end, Endian.little), 0x06054b50);
  return data.getUint16(end + 10, Endian.little);
}

Future<void> _ctrlE(WidgetTester t) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(LogicalKeyboardKey.keyE);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pumpAndSettle();
}

String _summary(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('export-summary'))).data!;

Future<void> _segment(WidgetTester t, String key, String label) async {
  final target = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.text(label),
  );
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('çizimli PDF, görsel ZIP, düzenlenebilir PDF; hatırlanır', (
    t,
  ) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_export_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/ders.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final io = _SaveIo(dir);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
        documentIoProvider.overrideWithValue(io),
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
    await t.pump(const Duration(milliseconds: 300));
    final session = t.widget<InkLayer>(find.byType(InkLayer)).session;

    // 1. sayfada çizim; sona boş (eklenmiş) sayfa: 3 sayfa.
    session.pasteItems(0, const [
      Shape(
        id: 'cizgi',
        kind: ShapeKind.line,
        color: 0xFFD42A3F,
        width: 6,
        x1: 60,
        y1: 80,
        x2: 260,
        y2: 80,
      ),
    ]);
    session.clearSelection();
    session.insertPage(2, newPageLike(session.document, 1, PageTemplate.grid));
    await t.pump(const Duration(milliseconds: 500));
    expect(session.document.pages, hasLength(3));

    // 1) Ctrl+E: pencere, varsayılan çizimli PDF, tüm sayfalar, önizleme.
    await _ctrlE(t);
    expect(find.byType(ExportDialog), findsOneWidget);
    expect(_summary(t), '3 sayfa · Çizimli PDF');
    await _until(
      t,
      () => find
          .byKey(const ValueKey('export-preview-image'))
          .evaluate()
          .isNotEmpty,
    );
    await _shot(t, 'export_pencere');

    // Boş eklenen sayfayı atla → 2; yalnızca çizimli → 1.
    await t.ensureVisible(find.byKey(const ValueKey('export-skip-blank')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('export-skip-blank')));
    await t.pump();
    expect(_summary(t), '2 sayfa · Çizimli PDF');
    await _segment(t, 'export-pages', 'Çizimli');
    expect(_summary(t), '1 sayfa · Çizimli PDF');

    // Dışa aktar: çizimli PDF, tek sayfa, inken.json yok.
    await t.tap(find.byKey(const ValueKey('export-submit')));
    await t.pumpAndSettle();
    expect(io.asked.last, ('ders (çizimli).pdf', SaveFormat.pdf));
    final flat = File('${dir.path}/out/ders (çizimli).pdf');
    await _until(t, flat.existsSync);
    await _until(
      t,
      () => find.textContaining('Dışa aktarıldı').evaluate().isNotEmpty,
    );
    final flatRead = await loadInkenFile(flat.readAsBytesSync());
    expect(flatRead.pageCount, 1);
    expect(flatRead.inkenJson, isNull);

    // 2) Yeniden aç: çizimli PDF ve "Çizimli" hatırlandı. Görsel, 96 dpi,
    // tüm sayfalar (boş atlanır) → 2 PNG tek ZIP.
    await _ctrlE(t);
    expect(_summary(t), '1 sayfa · Çizimli PDF');
    await t.tap(find.byKey(const ValueKey('export-format-images')));
    await t.pump();
    await _segment(t, 'export-dpi', '96 dpi');
    await _segment(t, 'export-pages', 'Tümü');
    expect(_summary(t), '2 sayfa · PNG · 96 dpi · ZIP');
    await t.tap(find.byKey(const ValueKey('export-submit')));
    await t.pumpAndSettle();
    expect(io.asked.last, ('ders - sayfalar.zip', SaveFormat.zip));
    final zip = File('${dir.path}/out/ders - sayfalar.zip');
    await _until(t, zip.existsSync);
    expect(_zipCount(zip.readAsBytesSync()), 2);

    // Görsel, JPEG, bu sayfa: tek .jpg dosyası.
    await _ctrlE(t);
    await _segment(t, 'export-encoding', 'JPEG');
    await _segment(t, 'export-pages', 'Bu sayfa');
    expect(_summary(t), '1 sayfa · JPEG · 96 dpi');
    await t.tap(find.byKey(const ValueKey('export-submit')));
    await t.pumpAndSettle();
    expect(io.asked.last, ('ders - sayfa 1.jpg', SaveFormat.jpeg));
    final jpg = File('${dir.path}/out/ders - sayfa 1.jpg');
    await _until(t, jpg.existsSync);
    expect(jpg.readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);

    // 3) Düzenlenebilir PDF, aralık "2": inken.json var, tek sayfa.
    await _ctrlE(t);
    await t.tap(find.byKey(const ValueKey('export-format-editable')));
    await t.pump();
    await _segment(t, 'export-pages', 'Aralık');
    await t.enterText(find.byKey(const ValueKey('export-range')), '9');
    await t.pump();
    expect(find.text('Geçersiz aralık (1–3)'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('export-submit')))
          .onPressed,
      isNull,
    );
    await t.enterText(find.byKey(const ValueKey('export-range')), '2');
    await t.pump();
    expect(_summary(t), '1 sayfa · Düzenlenebilir PDF');
    await t.tap(find.byKey(const ValueKey('export-submit')));
    await t.pumpAndSettle();
    expect(io.asked.last, ('ders (düzenlenebilir).pdf', SaveFormat.pdf));
    final editable = File('${dir.path}/out/ders (düzenlenebilir).pdf');
    await _until(t, editable.existsSync);
    final editRead = await loadInkenFile(editable.readAsBytesSync());
    expect(editRead.pageCount, 1);
    expect(editRead.inkenJson, isNotNull);

    // 4) Vazgeç: dosya yazılmaz.
    final before = io.asked.length;
    await _ctrlE(t);
    await t.tap(find.byKey(const ValueKey('export-cancel')));
    await t.pumpAndSettle();
    expect(find.byType(ExportDialog), findsNothing);
    expect(io.asked.length, before);

    // 5) Telefon: tam ekran pencere, görsel seçenekleriyle taşmaz.
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('app-menu')));
    await t.pumpAndSettle();
    await openDrawerSection(t, 'file');
    await t.tap(find.widgetWithText(ListTile, 'Dışa aktar…'));
    await t.pumpAndSettle();
    expect(find.byType(ExportDialog), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('export-format-images')));
    await t.pumpAndSettle();
    await _shot(t, 'export_telefon');
    await t.tap(find.byKey(const ValueKey('export-cancel')));
    await t.pumpAndSettle();
  });
}
