import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/src/viewer.dart';

void main() {
  bool finds(String query, String text) => searchPattern(query).hasMatch(text);

  test('büyük / küçük harf ayrımsız, Türkçe I / ı / İ / i', () {
    expect(finds('ışık', 'IŞIK'), isTrue);
    expect(finds('İstanbul', 'istanbul'), isTrue);
    expect(finds('istanbul', 'İSTANBUL'), isTrue);
    expect(finds('Işık', 'ışık'), isTrue);
    expect(finds('üçgen', 'ÜÇGEN'), isTrue);
    expect(finds('üçgen', 'ucgen'), isFalse);
  });

  test('boşluklar esnek, satır sonu dahil; özel karakterler düz metin', () {
    expect(finds('iç  açı', 'iç\naçı'), isTrue);
    expect(finds('2x + 3', '2x + 3 = 11'), isTrue);
    expect(finds('(a)', 'a'), isFalse);
    expect(finds('a.b', 'axb'), isFalse);
    expect(finds('  denklem ', 'denklemini'), isTrue);
  });
}
