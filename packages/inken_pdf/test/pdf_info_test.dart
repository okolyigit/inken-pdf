// Belge özellikleri: bilgi sözlüğü, sürüm, şifre; PDF tarih biçimi.
import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'pdfium_test_helper.dart';

void main() {
  setUpAll(setUpPdfium);

  test('bilgi sözlüğü (UTF-16 başlık, tarih) ve sürüm', () {
    final info = readPdfInfo(fixture('links.pdf'));
    expect(info.title, 'Işık ve Gölge');
    expect(info.author, 'Inken Test');
    expect(info.subject, 'Baglantilar');
    expect(info.creator, 'make_fixtures.py');
    expect(info.producer, isEmpty);
    expect(info.keywords, isEmpty);
    expect(info.created, DateTime.utc(2026, 11, 19, 6, 30).toLocal());
    expect(info.modified, isNull);
    expect(info.version, '1.7');
    expect(info.encrypted, isFalse);
    expect(info.signed, isFalse);
  });

  test('parolalı belge: parola ister, verilince şifreli görünür', () {
    final pdf = fixture('user_password.pdf');
    expect(() => readPdfInfo(pdf), throwsA(isA<PdfPasswordRequired>()));
    final info = readPdfInfo(pdf, password: '1234');
    expect(info.encrypted, isTrue);
    expect(info.producer, contains('Ghostscript'));
  });

  group('parsePdfDate', () {
    test('tam biçim ve saat dilimi', () {
      expect(
        parsePdfDate("D:20231015123000+03'00'"),
        DateTime.utc(2023, 10, 15, 9, 30).toLocal(),
      );
      expect(
        parsePdfDate("D:20231015123000-05'30"),
        DateTime.utc(2023, 10, 15, 18).toLocal(),
      );
      expect(
        parsePdfDate('D:20231015123000Z'),
        DateTime.utc(2023, 10, 15, 12, 30).toLocal(),
      );
    });

    test('eksik parçalar ve D: öneki olmadan', () {
      expect(parsePdfDate('D:2023'), DateTime(2023));
      expect(parsePdfDate('202310'), DateTime(2023, 10));
      expect(parsePdfDate('D:20231015'), DateTime(2023, 10, 15));
    });

    test('okunamayan', () {
      expect(parsePdfDate(''), isNull);
      expect(parsePdfDate('dün'), isNull);
      expect(parsePdfDate('D:20231315'), isNull);
    });
  });
}
