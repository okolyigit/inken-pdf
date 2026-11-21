import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_store.dart';

/// Arayüz dili. [system] işletim sisteminin dilini izler (desteklenmiyorsa
/// İngilizce); diğerleri onu geçersiz kılar.
enum AppLanguage {
  system(null),
  tr(Locale('tr')),
  en(Locale('en'));

  const AppLanguage(this.locale);

  /// `MaterialApp.locale`; sistemi izlerken `null`.
  final Locale? locale;
}

/// Seçilen dil; kalıcıdır (`settings.json` → `language`).
class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref
      .read(settingsStoreProvider)
      .getEnum('language', AppLanguage.values, AppLanguage.system);

  void set(AppLanguage language) {
    state = language;
    ref.read(settingsStoreProvider).put('language', language.name);
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, AppLanguage>(
  AppLanguageNotifier.new,
);

/// Seçenekler ve adları. Dil adları her arayüzde kendi dilinde yazılır
/// (Türkçe / English): yanlış dili seçen kullanıcı geri dönebilsin.
List<(AppLanguage, String)> languageChoices(AppLocalizations l10n) => [
  (AppLanguage.system, l10n.languageSystem),
  (AppLanguage.tr, l10n.languageTurkish),
  (AppLanguage.en, l10n.languageEnglish),
];
