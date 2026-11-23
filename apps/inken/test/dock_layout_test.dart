import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/ink_toolbar.dart';

void main() {
  test('iki sütunun ölçülerinden tek sütun yüksekliği', () {
    // Geri al (40) + 8 + max(iç 300, dış 200) + 8 + tutamak (24) = 380.
    expect(
      singleColumnHeight(twoColumns: 380, inner: 300, outer: 200, gap: 8),
      380 - 300 + 300 + 8 + 200,
    );
  });

  test('tek sütun sığıyorsa evet; ölçülmediyse hayır', () {
    expect(
      dockFitsSingleColumn(singleHeight: 700, maxHeight: 712, padding: 6),
      isTrue,
    );
    expect(
      dockFitsSingleColumn(singleHeight: 700, maxHeight: 711, padding: 6),
      isFalse,
    );
    expect(
      dockFitsSingleColumn(singleHeight: null, maxHeight: 5000, padding: 6),
      isFalse,
    );
  });
}
