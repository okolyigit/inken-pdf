import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_store.dart';

/// "Başlarken" kılavuzu: uygulamayla gelen, üzerine yazılarak denenen
/// tanıtım PDF'i. İlk kurulumda bir kez kendiliğinden, sonra Yardım
/// menüsünden açılır. Kaynakları `docs/baslarken/` (HTML → `build.sh`).

/// Arayüz diline göre kılavuzun varlık yolu: Türkçe ya da İngilizce
/// (başka diller İngilizceyi alır).
String guideAssetFor(String localeName) => localeName.startsWith('tr')
    ? 'assets/guide/baslarken.pdf'
    : 'assets/guide/getting-started.pdf';

/// Kılavuzun adı ve baytları (arayüz dilinde).
Future<({String name, Uint8List bytes})> loadGuide(
  AppLocalizations l10n, {
  AssetBundle? bundle,
}) async {
  final data = await (bundle ?? rootBundle).load(
    guideAssetFor(l10n.localeName),
  );
  return (name: l10n.guideFileName, bytes: data.buffer.asUint8List());
}

/// Ayarlardaki işaret: kılavuz ilk açılışta gösterildi.
const guideShownKey = 'guideShown';

/// İlk kurulumda kılavuz açılmalı mı? Yalnızca ayar dosyası olmadan
/// başlayan (yeni kurulum) ve kılavuzu henüz görmemiş uygulamada `true`
/// döner ve işareti düşer: bir kez açılır. Önceki sürümlerden gelenler
/// kılavuzu Yardım menüsünden açar.
bool takeFirstRunGuide(SettingsStore settings) {
  if (!settings.isFresh || settings.get<bool>(guideShownKey) == true) {
    return false;
  }
  settings.put(guideShownKey, true);
  return true;
}
