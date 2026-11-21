import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  group('onaltılık kod', () {
    test('okunan biçimler', () {
      expect(parseHexColor('#1F5AD6'), 0xFF1F5AD6);
      expect(parseHexColor('1f5ad6'), 0xFF1F5AD6);
      expect(parseHexColor('  #abc '), 0xFFAABBCC);
      expect(parseHexColor('F00'), 0xFFFF0000);
    });

    test('geçersiz kodlar', () {
      for (final s in ['', '#', '12345', '#1234567', 'GGGGGG', '#12 456']) {
        expect(parseHexColor(s), isNull, reason: s);
      }
    });

    test('yazılan biçim saydamlığı atar', () {
      expect(formatHexColor(0xFF1F5AD6), '#1F5AD6');
      expect(formatHexColor(0x66000A0B), '#000A0B');
    });

    test('gidiş-dönüş', () {
      for (final c in [0xFF000000, 0xFFFFFFFF, 0xFF7A3CC0, 0xFF0000FF]) {
        expect(parseHexColor(formatHexColor(c)), c);
      }
    });
  });

  group('HSV', () {
    test('ana renkler', () {
      expect(hsvToArgb(0, 1, 1), 0xFFFF0000);
      expect(hsvToArgb(120, 1, 1), 0xFF00FF00);
      expect(hsvToArgb(240, 1, 1), 0xFF0000FF);
      expect(hsvToArgb(360, 1, 1), 0xFFFF0000);
      expect(hsvToArgb(77, 0, 1), 0xFFFFFFFF);
      expect(hsvToArgb(200, 0.5, 0), 0xFF000000);
    });

    test('sınır dışı değerler kırpılır', () {
      expect(hsvToArgb(-120, 2, 3), 0xFF0000FF);
    });

    test('RGB → HSV → RGB aynı rengi verir', () {
      for (final c in [
        0xFF1A1A1A,
        0xFF1F5AD6,
        0xFFD42A3F,
        0xFF178A47,
        0xFFE07F00,
        0xFF7A3CC0,
        0xFFFFE34D,
        0xFF808080,
      ]) {
        final (h, s, v) = argbToHsv(c);
        expect(hsvToArgb(h, s, v), c, reason: formatHexColor(c));
      }
    });

    test('gri renkte ton 0, doygunluk 0', () {
      final (h, s, v) = argbToHsv(0xFF808080);
      expect(h, 0);
      expect(s, 0);
      expect(v, closeTo(128 / 255, 1e-9));
    });
  });

  group('son renkler', () {
    test('en başa eklenir, tekrar etmez, sınırı aşmaz', () {
      var r = <int>[];
      r = pushRecentColor(r, 1);
      r = pushRecentColor(r, 2);
      expect(r, [2, 1]);
      r = pushRecentColor(r, 1);
      expect(r, [1, 2]);
      for (var i = 3; i <= 8; i++) {
        r = pushRecentColor(r, i, max: 5);
      }
      expect(r, [8, 7, 6, 5, 4]);
    });
  });

  group('gece modu rengi', () {
    test('griler ters çevrilir', () {
      expect(nightInkColor(0xFF000000), 0xFFFFFFFF);
      expect(nightInkColor(0xFFFFFFFF), 0xFF000000);
      expect(nightInkColor(0xFF333333), 0xFFCCCCCC);
    });

    test('koyu renk açılır, ton korunur', () {
      final blue = nightInkColor(0xFF1565C0);
      final (h0, _, _) = argbToHsv(0xFF1565C0);
      final (h1, _, v1) = argbToHsv(blue);
      expect(h1, closeTo(h0, 2));
      expect(v1, greaterThan(0.85));
    });

    test('açık renk ve saydamlık olduğu gibi', () {
      expect(nightInkColor(0x66FFEB3B), 0x66FFEB3B, reason: 'fosforlu');
      expect(nightInkColor(0xFFD32F2F) & 0xFF000000, 0xFF000000);
      expect(nightInkColor(0x80000000), 0x80FFFFFF);
    });
  });
}
