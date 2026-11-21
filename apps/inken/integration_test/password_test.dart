// Açılış parolalı PDF gerçek uygulamada: parola sorulur → vazgeç (açılmaz)
// → yanlış parola (uyarıyla yeniden sorulur) → doğru parola → çiz → sayfa
// döndür (görüntüleme kopyası parolayla yeniden üretilir) → kaydet →
// kaydedilen kopya da parola ister; orijinal değişmez.
// Çalıştır: flutter test integration_test/password_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  if (_shotDir.isEmpty) return;
  for (var i = 0; i < 8; i++) {
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parolalı PDF: sor → yanlış → doğru → çiz → kaydet', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_password_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final fixture = File('../../test/fixtures/user_password.pdf')
        .readAsBytesSync();
    final pdf = File('${dir.path}/sinav.pdf')..writeAsBytesSync(fixture);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory({})),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
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
    await t.pump();
    final notifier = container.read(openDocumentProvider.notifier);
    final dialog = find.byKey(const ValueKey('password-dialog'));
    Future<void> open() => notifier.openBytes(
      name: 'sinav.pdf',
      bytes: pdf.readAsBytesSync(),
      path: pdf.path,
    );

    // 1) Vazgeç: belge açılmaz, hata yok.
    var opening = open();
    await _until(t, () => dialog.evaluate().isNotEmpty);
    expect(find.textContaining('sinav.pdf'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('password-cancel')));
    await t.pumpAndSettle();
    await opening;
    expect(container.read(openDocumentProvider), isNull);

    // 2) Yanlış parola: yeniden sorulur, uyarıyla.
    opening = open();
    await _until(t, () => dialog.evaluate().isNotEmpty);
    await t.enterText(find.byKey(const ValueKey('password-field')), '0000');
    await t.tap(find.byKey(const ValueKey('password-open')));
    await t.pump();
    await _until(
      t,
      () => find.text('Parola yanlış. Yeniden deneyin.').evaluate().isNotEmpty,
    );
    // Eski pencere kapanma animasyonunda iken yenisi açılır.
    await _until(
      t,
      () => find.byKey(const ValueKey('password-field')).evaluate().length == 1,
    );
    await _shot(t, 'parola-yanlis');

    // 3) Doğru parola (Enter ile).
    await t.enterText(find.byKey(const ValueKey('password-field')), '1234');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    await opening;
    final doc = container.read(openDocumentProvider);
    expect(doc, isNotNull);
    expect(doc!.password, '1234');
    expect(doc.isProtected, isTrue);
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    InkLayer layer() => t.widget<InkLayer>(find.byType(InkLayer));
    final session = layer().session;
    final gate = layer().geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    await _until(t, () => gate.open && viewer.pageCount == 2);

    // 4) Çiz ve ilk sayfayı döndür: görüntüleme kopyası parolayla üretilir.
    session.pasteItems(0, const [
      Shape(
        id: 'r',
        kind: ShapeKind.rectangle,
        color: 0xFFD42A3F,
        width: 6,
        x1: 60,
        y1: 60,
        x2: 300,
        y2: 200,
      ),
    ]);
    session.clearSelection();
    session.rotatePages({0}, 1);
    await _until(
      t,
      () =>
          gate.open &&
          viewer.pageSizes.isNotEmpty &&
          viewer.pageSizes[0].width > viewer.pageSizes[0].height,
    );
    await _shot(t, 'parola-acik');

    // 5) Kaydet: korumalı dosya kopyaya; kopya da parola ister.
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyS);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    await _until(t, () => !session.isDirty);
    final saved = File('${dir.path}/sinav_inken.pdf').readAsBytesSync();
    final noPassword = await t.runAsync(() async {
      try {
        await loadInkenFile(saved);
        return false;
      } on PdfPasswordRequired {
        return true;
      }
    });
    expect(noPassword, isTrue, reason: 'kopya da parolalı');
    final read = (await t.runAsync(
      () => loadInkenFile(saved, password: '1234'),
    ))!;
    final model = decodeInkenDocument(read.inkenJson!);
    expect(model.pages[0].items, hasLength(1));
    expect(model.pages[0].width, greaterThan(model.pages[0].height));
    expect(pdf.readAsBytesSync(), fixture, reason: 'orijinale dokunulmaz');
    // Açık belge artık kaydedilen kopya; parola onunla kalır.
    expect(container.read(openDocumentProvider)!.password, '1234');
  });
}
