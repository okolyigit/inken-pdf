import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/app_info.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/l10n/app_localizations_tr.dart';
import 'package:inken_core/inken_core.dart' show currentFormatVersion;

void main() {
  final AppLocalizations l10n = AppLocalizationsTr();

  test('pubspec sürümü okunur; yoksa null', () {
    expect(
      parsePubspecVersion('name: inken\nversion: 0.1.0+11\n\nenvironment:\n'),
      (version: '0.1.0', build: '11'),
    );
    expect(parsePubspecVersion("version: '1.2.0' # yorum"), (
      version: '1.2.0',
      build: '',
    ));
    expect(parsePubspecVersion('version: 1.0.0-rc.1+12'), (
      version: '1.0.0-rc.1',
      build: '12',
    ));
    expect(parsePubspecVersion('  version: 9.9.9\nname: x'), isNull);
    expect(parsePubspecVersion('bozuk'), isNull);
  });

  test('uygulamanın pubspec sürümü okunur', () {
    final v = parsePubspecVersion(File('pubspec.yaml').readAsStringSync());
    expect(v?.build, isNotEmpty);
  });

  test('sürüm etiketi', () {
    expect(
      versionLabel(l10n, (version: '0.1.0', build: '3')),
      '0.1.0 (derleme 3)',
    );
    expect(versionLabel(l10n, (version: '0.1.0', build: '')), '0.1.0');
    expect(versionLabel(l10n, null), '?');
  });

  test('bilgi satırları ve kopyalanan metin', () {
    final rows = appInfoRows(
      l10n,
      version: (version: '0.1.0', build: '3'),
      dataFolder: '/home/x/.local/share/inken',
      tools: const ToolState(inputMode: InputMode.pen, stylusSeen: true),
      screen: const Size(1280, 720),
      pixelRatio: 1.25,
      locale: 'tr',
    );
    final text = appInfoText('Inken PDF', rows);
    expect(text.split('\n').first, 'Inken PDF');
    expect(text, contains('Sürüm: 0.1.0 (derleme 3)'));
    expect(text, contains('Ekran: 1280 × 720 · 1.25x'));
    expect(text, contains('Kalem algılandı: Evet'));
    expect(text, contains('Veri klasörü (ayarlar, yedekler): /home/x/'));
    expect(text, contains('Kayıt formatı (inken.json): $currentFormatVersion'));
  });
}
