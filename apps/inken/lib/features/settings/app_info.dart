import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../ink/tool_state.dart';

/// Projenin GitHub deposu (geri bildirim ve kaynak).
const repositoryUrl = 'https://github.com/okolyigit/inken-pdf';

/// Uygulamanın sürümü: `pubspec.yaml`'daki `version` (ör. 0.1.0+3 →
/// sürüm 0.1.0, derleme 3).
typedef AppVersion = ({String version, String build});

/// Varlıklara konan `pubspec.yaml`'ın `version:` satırından okunur (ek
/// eklenti gerekmez; Flutter'ın `version.json`'u Android ve Windows
/// derlemelerine girmiyor). Okunamazsa `null`.
AppVersion? parsePubspecVersion(String text) {
  final match = RegExp(
    r'''^version:[ \t]*['"]?([0-9A-Za-z.\-]+)(?:\+([0-9A-Za-z.\-]+))?''',
    multiLine: true,
  ).firstMatch(text);
  if (match == null) return null;
  return (version: match[1]!, build: match[2] ?? '');
}

final appVersionProvider = FutureProvider<AppVersion?>((ref) async {
  try {
    return parsePubspecVersion(await rootBundle.loadString('pubspec.yaml'));
  } on Object {
    return null;
  }
});

/// Ayarların, yedeklerin ve küçük resimlerin durduğu klasör.
final dataFolderProvider = FutureProvider<String?>((ref) async {
  try {
    return (await getApplicationSupportDirectory()).path;
  } on Object {
    return null;
  }
});

/// "0.1.0 (derleme 3)"; bilinmiyorsa "?".
String versionLabel(AppLocalizations l10n, AppVersion? v) {
  if (v == null) return '?';
  return v.build.isEmpty
      ? v.version
      : l10n.versionWithBuild(v.version, v.build);
}

/// Uygulama bilgilerinin satırları (etiket, değer): ekranda liste, "Kopyala"
/// ile hata bildirimine yapıştırılacak metin.
List<(String, String)> appInfoRows(
  AppLocalizations l10n, {
  required AppVersion? version,
  required String? dataFolder,
  required ToolState tools,
  required Size screen,
  required double pixelRatio,
  required String locale,
}) => [
  (l10n.infoVersion, versionLabel(l10n, version)),
  (
    l10n.infoPlatform,
    '${_platformName()} · ${Platform.operatingSystemVersion}',
  ),
  (l10n.infoDart, Platform.version.split(' ').first),
  (l10n.infoPdfEngine, 'pdfrx $pdfrxVersion · pdfium_dart $pdfiumDartVersion'),
  (l10n.infoFormat, '$currentFormatVersion'),
  (l10n.infoLanguage, locale),
  (
    l10n.infoScreen,
    '${screen.width.round()} × ${screen.height.round()} · '
        '${pixelRatio.toStringAsFixed(2)}x',
  ),
  (
    l10n.inputMode,
    switch (tools.inputMode) {
      InputMode.auto => l10n.inputModeAuto,
      InputMode.pen => l10n.inputModePen,
      InputMode.touch => l10n.inputModeTouch,
    },
  ),
  (l10n.infoStylusSeen, tools.stylusSeen ? l10n.yes : l10n.no),
  (l10n.infoDataFolder, dataFolder ?? '?'),
];

/// Kopyalanacak düz metin.
String appInfoText(String title, List<(String, String)> rows) =>
    [title, for (final (k, v) in rows) '$k: $v'].join('\n');

String _platformName() {
  if (Platform.isLinux) return 'Linux';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isIOS) return 'iOS';
  return Platform.operatingSystem;
}
