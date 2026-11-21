import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/files/open_document.dart';
import 'features/files/password_dialog.dart';
import 'features/settings/language.dart';
import 'features/viewer/home_page.dart';
import 'features/viewer/viewer_page.dart';
import 'l10n/app_localizations.dart';
import 'theme/inken_theme.dart';
import 'theme/theme_mode.dart';
import 'theme/ui_scale.dart';

class InkenApp extends ConsumerWidget {
  const InkenApp({super.key});

  static final _light = inkenTheme(Brightness.light);
  static final _dark = inkenTheme(Brightness.dark);

  /// Parola penceresi, hangi ekrandan açılırsa açılsın buradan gösterilir.
  static final _navigator = GlobalKey<NavigatorState>();

  static Future<String?> _askPassword(String name, {required bool wrong}) {
    final context = _navigator.currentContext;
    if (context == null) return Future.value();
    return askPdfPassword(context, name: name, wrong: wrong);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(openDocumentProvider);
    ref.read(openDocumentProvider.notifier).passwordPrompt = _askPassword;
    return MaterialApp(
      navigatorKey: _navigator,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(appLanguageProvider).locale,
      theme: _light,
      darkTheme: _dark,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      // Arayüz boyutu (akıllı tahta): menüler, pencereler dahil her şey.
      builder: (context, child) => ScaledApp(
        scale: ref.watch(uiScaleProvider).factor,
        child: child ?? const SizedBox.shrink(),
      ),
      home: document == null
          ? const HomePage()
          // Anahtar: başka bir belge açılınca çizim oturumu sıfırlansın.
          : ViewerPage(key: ValueKey(document.sourceName), document: document),
    );
  }
}
