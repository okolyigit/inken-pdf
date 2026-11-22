import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/guide.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_pdf/inken_pdf.dart';

final _bytes = Uint8List.fromList([1, 2, 3]);

InkenReadResult _read() => (
  displayPdf: _bytes,
  inkenJson: null,
  pageCount: 9,
  isProtected: false,
  images: const {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kılavuz varlığı', () {
    test('Türkçe arayüze Başlarken, diğerlerine Getting Started', () {
      expect(guideAssetFor('tr'), 'assets/guide/baslarken.pdf');
      expect(guideAssetFor('tr_TR'), 'assets/guide/baslarken.pdf');
      expect(guideAssetFor('en'), 'assets/guide/getting-started.pdf');
      expect(guideAssetFor('de'), 'assets/guide/getting-started.pdf');
    });

    test("iki dilin PDF'i pakette ve adı arayüz dilinde", () async {
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = lookupAppLocalizations(locale);
        final guide = await loadGuide(l10n);
        expect(String.fromCharCodes(guide.bytes.take(5)), '%PDF-');
        expect(guide.name, l10n.guideFileName);
      }
      expect(
        lookupAppLocalizations(const Locale('tr')).guideFileName,
        'Başlarken.pdf',
      );
    });
  });

  group('ilk açılış', () {
    test('yeni kurulumda bir kez açılır ve işaret kalıcıdır', () {
      final settings = SettingsStore.memory(null, true);
      expect(takeFirstRunGuide(settings), isTrue);
      expect(settings.get<bool>(guideShownKey), isTrue);
      expect(takeFirstRunGuide(settings), isFalse);
    });

    test('önceki sürümden gelende açılmaz', () {
      expect(takeFirstRunGuide(SettingsStore.memory()), isFalse);
      expect(
        takeFirstRunGuide(SettingsStore.memory({'theme': 'dark'})),
        isFalse,
      );
    });
  });

  group('kılavuz belgesi', () {
    test('yeri yok: ilk kayıt Farklı kaydet ile', () {
      final d = documentFromRead(
        name: 'Başlarken.pdf',
        bytes: _bytes,
        read: _read(),
        isGuide: true,
      );
      expect(d.isGuide, isTrue);
      expect(d.path, isNull);
      expect(saveTargetFor(d), isNull);
    });

    test('sıradan açılan belge kılavuz değildir', () {
      final d = documentFromRead(name: 'a.pdf', bytes: _bytes, read: _read());
      expect(d.isGuide, isFalse);
    });
  });
}
