// İçindekiler gerçek uygulamada: panelde sekme → başlıklar → başlığa
// dokunmak sayfaya gider → alt başlık açılır → sayfa eklenince ağaç yeniden
// okunur (sayfa numaraları kayar) → içindekiler olmayan belgede bilgi.
// Çalıştır: flutter test integration_test/outline_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüleri oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken/features/viewer/page_panel.dart';
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

  testWidgets('içindekiler sekmesi', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_outline_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File copy(String name) => File('${dir.path}/$name')
      ..writeAsBytesSync(File('../../test/fixtures/$name').readAsBytesSync());
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
    Future<(InkLayer, LayoutGate, InkenViewerController)> open(
      String name,
      int pages,
    ) async {
      final f = copy(name);
      await container
          .read(openDocumentProvider.notifier)
          .openBytes(name: name, bytes: f.readAsBytesSync(), path: f.path);
      await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
      final layer = t.widget<InkLayer>(find.byType(InkLayer));
      final gate = layer.geometry as LayoutGate;
      final viewer = gate.inner as InkenViewerController;
      await _until(t, () => gate.open && viewer.pageCount == pages);
      return (layer, gate, viewer);
    }

    final (layer, gate, viewer) = await open('links.pdf', 3);
    final panel = find.byType(PagePanel);
    final narrow = t.getSize(panel).width;

    // 1) Sekme: başlıklar görünür, panel genişler.
    await t.tap(find.byKey(const ValueKey('panel-tab-outline')));
    await t.pumpAndSettle();
    expect(t.getSize(panel).width, greaterThan(narrow));
    expect(find.text('Bolum 1'), findsOneWidget);
    expect(find.text('Bolum 2'), findsOneWidget);
    expect(find.text('Bolum 3'), findsOneWidget);
    expect(find.text('Alt baslik'), findsNothing, reason: 'kapalı');

    // 2) Başlığa dokunmak sayfaya gider; geçerli bölüm vurgulu.
    await t.tap(find.text('Bolum 3'));
    await _until(t, () => viewer.currentPage == 2);

    // 3) Alt başlık açılır; ona dokunmak sayfasına gider.
    await t.tap(find.byKey(const ValueKey('outline-toggle-1')));
    await t.pumpAndSettle();
    expect(find.text('Alt baslik'), findsOneWidget);
    await t.tap(find.text('Alt baslik'));
    await _until(t, () => viewer.currentPage == 1);
    // Başlığın yerine gidilir (hedef /XYZ 0 530: sayfanın üstünden 312 pt),
    // sayfanın başına değil: başlık ekranın üst kısmında.
    await t.pumpAndSettle();
    final heading = gate.viewportOf(1)!.toView(const Offset(0, 312)).dy;
    expect(heading, inInclusiveRange(0, 80));
    await _shot(t, 'icindekiler');

    // 4) Başa sayfa eklenince ağaç yeniden okunur: numaralar kayar.
    final session = layer.session;
    session.insertPage(0, newPageLike(session.document, 0, PageTemplate.blank));
    await _until(t, () => gate.open && viewer.pageCount == 4);
    await t.pumpAndSettle();
    final row = find.byKey(const ValueKey('outline-2'));
    await _until(
      t,
      () => find
          .descendant(of: row, matching: find.text('4'))
          .evaluate()
          .isNotEmpty,
    );

    // 5) Sayfalar sekmesine dönülür; panel daralır.
    await t.tap(find.byKey(const ValueKey('panel-tab-pages')));
    await t.pumpAndSettle();
    expect(t.getSize(panel).width, narrow);
    expect(find.byKey(const ValueKey('page-thumb-0')), findsOneWidget);

    // 6) İçindekiler olmayan belge.
    container.read(openDocumentProvider.notifier).close();
    await t.pumpAndSettle();
    await open('two_pages.pdf', 2);
    await t.tap(find.byKey(const ValueKey('panel-tab-outline')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('outline-empty')), findsOneWidget);
  });
}
