// Sürükle-bırak gerçek uygulamada: açılış ekranına PDF bırak → açılır;
// açık belgenin üzerine başka PDF bırak → o açılır. Eklentinin yerel
// tarafının mesajları taklit edilir (gerçek sürükleme otomatikleştirilemez).
// Çalıştır: flutter test integration_test/drop_test.dart -d linux
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

Future<void> _drop(WidgetTester t, String path) async {
  for (final call in [
    const MethodCall('entered', [400.0, 400.0]),
    MethodCall('performOperation', [path]),
  ]) {
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
    await t.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF bırakınca açılır; açık belgenin üzerine de', (t) async {
    await initInkenPdf();
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    final dir = Directory.systemTemp.createTempSync('inken_drop_it');
    addTearDown(() => dir.deleteSync(recursive: true));
    File pdf(String name, String fixture) => File(
      '${dir.path}/$name',
    )..writeAsBytesSync(File('../../test/fixtures/$fixture').readAsBytesSync());
    final first = pdf('birinci.pdf', 'two_pages.pdf');
    final second = pdf('ikinci.pdf', 'single_page.pdf');
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
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
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await t.pump(const Duration(milliseconds: 500));

    await _drop(t, first.path);
    await _until(t, () => find.byType(InkLayer).evaluate().isNotEmpty);
    expect(container.read(openDocumentProvider)!.path, first.path);

    await t.pump(const Duration(milliseconds: 500));
    await _drop(t, second.path);
    await _until(
      t,
      () => container.read(openDocumentProvider)?.path == second.path,
    );
    expect(container.read(openDocumentProvider)!.name, 'ikinci.pdf');
  });
}
