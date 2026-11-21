import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/document_properties.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('dosya boyutu', () {
    expect(formatFileSize(512, 'tr'), '512 B');
    expect(formatFileSize(2048, 'tr'), '2 KB');
    expect(formatFileSize(1572864, 'tr'), '1,5 MB');
    expect(formatFileSize(1572864, 'en'), '1.5 MB');
  });

  test('sayfa boyutu: kâğıt adı ve yön', () {
    final tr = lookupAppLocalizations(const Locale('tr'));
    expect(describePageSize(tr, 595.28, 841.89), '210 × 297 mm (A4, Dikey)');
    expect(describePageSize(tr, 842, 595), '297 × 210 mm (A4, Yatay)');
    expect(describePageSize(tr, 600, 400), '212 × 141 mm (Yatay)');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(describePageSize(en, 612, 792), '216 × 279 mm (Letter, Portrait)');
  });
}
