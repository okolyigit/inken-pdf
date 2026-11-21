// Bağlantılar gerçek uygulamada: el aracında belge içi bağlantı sayfaya
// gider; web bağlantısı önce sorar (vazgeç / aç); kalemle bağlantıya basmak
// çizer, sayfadan çıkmaz.
// Çalıştır: flutter test integration_test/links_test.dart -d linux
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/features/viewer/layout_gate.dart';
import 'package:inken/platform/link_opener.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('belge içi ve web bağlantıları', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_links_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/kitap.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/links.pdf').readAsBytesSync(),
      );
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory({})),
        recentStoreProvider.overrideWithValue(
          await RecentStore.load(directory: dir),
        ),
        backupStoreProvider.overrideWithValue(
          BackupStore.at(Directory('${dir.path}/backups')),
        ),
        linkOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'kitap.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    final layer = t.widget<InkLayer>(find.byType(InkLayer));
    final gate = layer.geometry as LayoutGate;
    final viewer = gate.inner as InkenViewerController;
    await _until(t, () => gate.open && viewer.pageCount == 3);
    await t.pump(const Duration(milliseconds: 500));
    final box = t.getRect(find.byType(InkLayer));

    /// 1. sayfadaki bir noktanın ekran konumu (sayfa uzayında pt).
    Offset at(double x, double y) =>
        box.topLeft + gate.viewportOf(0)!.toView(Offset(x, y));
    // fixture: "Bolum 2" y 128..152, "Bolum 3" y 168..192, "Web sitesi"
    // y 208..232 (sol üst orijinli pt).
    final bolum3 = at(136, 180);
    final web = at(166, 220);
    final bolum2 = at(136, 140);

    // 1) El aracında belge içi bağlantı o sayfaya gider.
    container.read(toolProvider.notifier).select(Tool.hand);
    await t.pump();
    await t.tapAt(bolum3, kind: PointerDeviceKind.mouse);
    await _until(t, () => viewer.currentPage == 2);

    // 2) Web bağlantısı önce sorar: vazgeç açmaz, aç açar.
    await viewer.jumpToPage(0);
    await t.pump(const Duration(milliseconds: 300));
    await t.tapAt(web, kind: PointerDeviceKind.mouse);
    await _until(
      t,
      () => find.byKey(const ValueKey('link-dialog')).evaluate().isNotEmpty,
    );
    expect(find.textContaining('https://example.org'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('link-cancel')));
    await t.pumpAndSettle();
    expect(opened, isEmpty);
    await t.tapAt(web, kind: PointerDeviceKind.mouse);
    await _until(
      t,
      () => find.byKey(const ValueKey('link-dialog')).evaluate().isNotEmpty,
    );
    await t.tap(find.byKey(const ValueKey('link-open')));
    await t.pumpAndSettle();
    expect(opened, [Uri.parse('https://example.org')]);

    // 3) Kalemle bağlantıya basmak çizer; sayfa değişmez.
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.pump();
    await t.tapAt(bolum2, kind: PointerDeviceKind.mouse);
    await t.pump(const Duration(milliseconds: 500));
    expect(viewer.currentPage, 0);
    expect(layer.session.document.pages[0].items, hasLength(1));
  });
}
