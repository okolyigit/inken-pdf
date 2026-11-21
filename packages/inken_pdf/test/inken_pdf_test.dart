import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';

void main() {
  test('paket yükleniyor', () {
    // Gerçek gidiş-dönüş testleri Faz 2'de yazma katmanıyla gelir.
    expect(initInkenPdf, isNotNull);
  });
}
