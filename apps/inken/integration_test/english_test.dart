// İngilizce arayüzün gözden geçirilmesi: uygulama İngilizce açılır, ekranlar
// masaüstü, tablet ve telefon boyutunda gezilir. Taşan metin (RenderFlex
// overflow) testi düşürür. INKEN_SHOT=<klasör> verilirse her ekranın
// görüntüsü yazılır (elle okumak için).
// Çalıştır: flutter test integration_test/english_test.dart -d linux
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
import 'package:inken/features/settings/language.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _shotDir = String.fromEnvironment('INKEN_SHOT');
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester t, String name) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (_shotDir.isEmpty) return;
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_shotDir/en-$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue, reason: 'zaman aşımı');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('İngilizce arayüz: masaüstü, tablet, telefon', (t) async {
    await initInkenPdf();
    // Sistem Türkçe; İngilizce ayardan gelir.
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 720);
    addTearDown(t.view.reset);
    final dir = Directory.systemTemp.createTempSync('inken_en_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/lesson.pdf')
      ..writeAsBytesSync(
        File('../../test/fixtures/two_pages.pdf').readAsBytesSync(),
      );
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          SettingsStore.memory({'language': 'en'}),
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
    await _shot(t, 'home');
    expect(find.text('What you can do'), findsOneWidget);

    // Menüler.
    for (final menu in ['File', 'Edit', 'View', 'Page', 'Tools', 'Help']) {
      await t.tap(find.widgetWithText(SubmenuButton, menu).first);
      await t.pumpAndSettle();
      await _shot(t, 'menu-${menu.toLowerCase()}');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
    }

    // Ayarlar: her sekme.
    await t.tap(find.byKey(const ValueKey('quick-settings')));
    await t.pumpAndSettle();
    for (final tab in ['appearance', 'input', 'shortcuts', 'about', 'info']) {
      await t.tap(find.byKey(ValueKey('settings-tab-$tab')));
      await t.pumpAndSettle();
      await _shot(t, 'settings-$tab');
    }
    await t.tap(find.byKey(const ValueKey('settings-close')));
    await t.pumpAndSettle();

    // Belge ve araç panelleri.
    await container
        .read(openDocumentProvider.notifier)
        .openBytes(
          name: 'lesson.pdf',
          bytes: pdf.readAsBytesSync(),
          path: pdf.path,
        );
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    await _shot(t, 'viewer');
    for (final tool in ['pen', 'highlighter', 'laser', 'eraser', 'shape']) {
      final button = find.byKey(ValueKey('tool-$tool'));
      await t.tap(button);
      await t.pumpAndSettle();
      if (find.byKey(ValueKey('options-$tool')).evaluate().isEmpty) {
        await t.tap(button);
        await t.pumpAndSettle();
      }
      await _shot(t, 'options-$tool');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const ValueKey('cover-button')));
    await t.pumpAndSettle();
    await _shot(t, 'cover-menu');
    await t.tap(find.byKey(const ValueKey('cover-curtain')));
    await t.pumpAndSettle();
    await _shot(t, 'curtain');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // Tablet (dikey) ve telefon yerleşimleri.
    for (final (name, size) in [
      ('tablet', const Size(800, 1280)),
      ('phone', const Size(400, 800)),
      ('phone-landscape', const Size(800, 400)),
    ]) {
      t.view.physicalSize = size;
      await t.pumpAndSettle();
      await _shot(t, name);
    }
    // Telefonda yan menü.
    t.view.physicalSize = const Size(400, 800);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('app-menu')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('drawer-file')));
    await t.pumpAndSettle();
    await _shot(t, 'phone-drawer');
    await t.drag(find.byType(Drawer), const Offset(0, -600));
    await t.pumpAndSettle();
    await _shot(t, 'phone-drawer-2');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    t.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await t.pumpAndSettle();
    // Telefonda ⋮ menüsü: sağ kenara hizalı.
    await t.tap(find.byKey(const ValueKey('more')));
    await t.pumpAndSettle();
    await _shot(t, 'phone-more');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // Telefonda raf kapalı gelir; üst çubuktaki düğmeyle açılır.
    await t.tap(find.byKey(const ValueKey('phone-tools')));
    await t.pumpAndSettle();
    await _shot(t, 'phone-dock');

    // Raf adları kısa: telefonda kesilmez. Türkçede de bakılır.
    expect(find.text('Marker'), findsOneWidget);
    expect(find.text('Laser'), findsOneWidget);
    container.read(appLanguageProvider.notifier).set(AppLanguage.tr);
    await t.pumpAndSettle();
    expect(find.text('Fosforlu'), findsOneWidget);
    await _shot(t, 'phone-tr');
  });
}
