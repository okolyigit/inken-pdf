import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'app.dart';
import 'app_licenses.dart';
import 'features/files/launch_file.dart';
import 'features/files/recent_documents.dart';
import 'features/ink/text_font_provider.dart';
import 'features/settings/settings_store.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initInkenPdf();
  registerAppLicenses();
  // Ayarlar ve son belgeler açılışta bir kez okunur; ilk karede tema doğru
  // olsun, liste boş görünüp sonra dolmasın.
  final (settings, recent, textFont) = await (
    SettingsStore.load(),
    RecentStore.load(),
    InkenTextFont.load(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        recentStoreProvider.overrideWithValue(recent),
        textFontProvider.overrideWithValue(textFont),
        launchFileProvider.overrideWithValue(LaunchFile.forPlatform(args)),
      ],
      child: const InkenApp(),
    ),
  );
}
