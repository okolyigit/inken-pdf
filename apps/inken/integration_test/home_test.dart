// Açılış ekranı ve son belgeler, gerçek uygulamada (pdfrx ile küçük resim).
// Çalıştır: flutter test integration_test/home_test.dart -d linux
// INKEN_SHOT=<klasör> verilirse ekran görüntüsü oraya yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/app_licenses.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
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

  testWidgets('aç → küçük resim → kapat → karttan yeniden aç', (t) async {
    await initInkenPdf();
    registerAppLicenses();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_home_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/Limit Fasikülü.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final settings = await SettingsStore.load(directory: dir);
    final recentStore = await RecentStore.load(directory: dir);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        recentStoreProvider.overrideWithValue(recentStore),
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
    await t.pump(const Duration(milliseconds: 300));
    await _shot(t, 'home-bos');

    // Hızlı erişim çubuğundan ayarlar.
    await t.tap(find.byKey(const ValueKey('quick-settings')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-quick-bar')), findsOneWidget);
    await _shot(t, 'home-ayarlar');
    await t.tap(find.byKey(const ValueKey('settings-tab-shortcuts')));
    await t.pumpAndSettle();
    await _shot(t, 'home-ayarlar-kisayollar');
    await t.tap(find.byKey(const ValueKey('settings-tab-about')));
    await t.pumpAndSettle();
    // Sürüm varlıklardaki pubspec.yaml'dan.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: (\S+)\+(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec)!;
    await _until(
      t,
      () => find
          .text('Sürüm ${version[1]} (derleme ${version[2]})')
          .evaluate()
          .isNotEmpty,
    );
    await _shot(t, 'home-hakkinda');
    await t.tap(find.byKey(const ValueKey('settings-tab-info')));
    await t.pumpAndSettle();
    expect(find.text('PDF motoru'), findsOneWidget);
    await _shot(t, 'home-bilgiler');
    await t.tap(find.byKey(const ValueKey('settings-tab-about')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('about-licenses')));
    await t.pumpAndSettle();
    await _until(t, () => find.textContaining('DejaVu').evaluate().isNotEmpty);
    await _shot(t, 'home-lisanslar');
    // Lisans sayfası geniş ekranda iki bölmeli, geri düğmesi yok.
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings-close')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-tab-about')), findsNothing);

    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'Limit Fasikülü.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    final thumb = recentStore.thumbnailFile(pdf.path)!;
    await _until(t, thumb.existsSync);
    expect(container.read(recentDocumentsProvider).single.pageCount, 2);

    container.read(openDocumentProvider.notifier).close();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Son açılanlar'), findsOneWidget);
    expect(find.text('Limit Fasikülü.pdf'), findsOneWidget);
    expect(find.textContaining('2 sayfa'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await _shot(t, 'home-son');

    // Liste kalıcı: yeniden okununca aynı belge.
    await recentStore.flush();
    final reloaded = await RecentStore.load(directory: dir);
    expect(reloaded.initial.single.location, pdf.path);

    await t.tap(find.text('Limit Fasikülü.pdf'));
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    expect(container.read(openDocumentProvider)!.path, pdf.path);
  });
}
