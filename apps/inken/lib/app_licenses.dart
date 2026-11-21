import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uygulamaya gömülü fontların lisansları, Flutter'ın lisans sayfasına
/// (Ayarlar → Hakkında → Lisanslar) eklenir. Paketlerinkiler zaten oradadır.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('DejaVu Sans', 'LICENSE-DejaVu.txt'),
      ('Figtree', 'OFL-Figtree.txt'),
      ('Fraunces', 'OFL-Fraunces.txt'),
      ('JetBrains Mono', 'OFL-JetBrainsMono.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
