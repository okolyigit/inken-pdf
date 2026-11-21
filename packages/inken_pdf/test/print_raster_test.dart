import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';

void main() {
  // A4 (595 × 842 pt); yazdırılabilir alan 300 dpi'de kenar boşluklu A4.
  const boxW = 2400, boxH = 3400;

  test('dikey sayfa dikey kâğıda: döndürülmez, oran korunur', () {
    final f = fitPageToBox(595, 842, boxW, boxH);
    expect(f.rotate, isFalse);
    expect(f.width, lessThanOrEqualTo(boxW));
    expect(f.height, lessThanOrEqualTo(boxH));
    expect(f.width == boxW || f.height == boxH, isTrue);
    expect(f.width / f.height, closeTo(595 / 842, 0.002));
  });

  test('yatay sayfa dikey kâğıda: çeyrek tur döner, alanı doldurur', () {
    final f = fitPageToBox(842, 595, boxW, boxH);
    expect(f.rotate, isTrue);
    expect(f.width / f.height, closeTo(595 / 842, 0.002));
    expect(f.width == boxW || f.height == boxH, isTrue);
  });

  test('yatay sayfa yatay kâğıda: döndürülmez', () {
    final f = fitPageToBox(842, 595, boxH, boxW);
    expect(f.rotate, isFalse);
    expect(f.width / f.height, closeTo(842 / 595, 0.002));
  });

  test('kare sayfa ya da kare alan: döndürülmez', () {
    expect(fitPageToBox(500, 500, boxW, boxH).rotate, isFalse);
    expect(fitPageToBox(842, 595, 3000, 3000).rotate, isFalse);
    final sq = fitPageToBox(500, 500, boxW, boxH);
    expect(sq.width, boxW);
    expect(sq.height, boxW);
  });

  test('küçük sayfa büyütülür, büyük sayfa küçültülür', () {
    final a5 = fitPageToBox(420, 595, boxW, boxH);
    final a3 = fitPageToBox(842, 1191, boxW, boxH);
    expect(a5.width == boxW || a5.height == boxH, isTrue);
    expect(a3.width == boxW || a3.height == boxH, isTrue);
  });

  test('çok ince sayfa en az 1 piksel', () {
    final f = fitPageToBox(1, 100000, boxW, boxH);
    expect(f.width, greaterThanOrEqualTo(1));
    expect(f.height, boxH);
  });

  test('geçersiz boyut hata verir', () {
    expect(() => fitPageToBox(0, 842, boxW, boxH), throwsArgumentError);
    expect(() => fitPageToBox(595, 842, 0, boxH), throwsArgumentError);
  });
}
