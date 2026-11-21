import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

final _font = TextFont.parse(
  File('../../apps/inken/assets/fonts/DejaVuSans.ttf').readAsBytesSync(),
);

int _contours(List<OutlineCommand> o) => o.whereType<MoveTo>().length;

({double l, double t, double r, double b}) _bounds(List<OutlineCommand> o) {
  var l = double.infinity, b = double.infinity;
  var r = -double.infinity, t = -double.infinity;
  void add(double x, double y) {
    l = math.min(l, x);
    r = math.max(r, x);
    b = math.min(b, y);
    t = math.max(t, y);
  }

  for (final c in o) {
    switch (c) {
      case MoveTo(:final x, :final y) || LineTo(:final x, :final y):
        add(x, y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        add(cx, cy);
        add(x, y);
      case ClosePath():
    }
  }
  return (l: l, t: t, r: r, b: b);
}

List<OutlineCommand> _glyph(String c) =>
    _font.outlineOf(_font.glyphOf(c.runes.single));

void main() {
  group('TextFont', () {
    test('ölçüler ve Türkçe + matematik kapsamı', () {
      expect(_font.unitsPerEm, 2048);
      expect(_font.ascender, greaterThan(0));
      expect(_font.descender, lessThan(0));
      for (final c in 'ğĞüÜşŞıİöÖçÇ√π∞≤≥≠≈±×÷°²³∑∫Δ→⇒∈∪∩'.runes) {
        expect(_font.covers(c), isTrue, reason: String.fromCharCode(c));
      }
      expect(_font.covers(0x4E2D), isFalse); // 中
      expect(_font.glyphOf(0x4E2D), 0);
    });

    test('ilerleme genişlikleri', () {
      int adv(String c) => _font.advanceOf(_font.glyphOf(c.runes.single));
      expect(adv('i'), lessThan(adv('m')));
      expect(adv(' '), greaterThan(0));
    });

    test('basit glifler: "o" iki kontur, "l" taban çizgisinden yukarı', () {
      expect(_contours(_glyph('o')), 2);
      expect(_contours(_glyph('l')), 1);
      final l = _bounds(_glyph('l'));
      expect(l.b, closeTo(0, 1));
      expect(l.t, greaterThan(1400));
      expect(_glyph(' '), isEmpty);
      // Her kontur kapanır.
      final o = _glyph('o');
      expect(o.whereType<ClosePath>().length, _contours(o));
    });

    test('bileşik glifler: ğ, İ, ş taban harften daha fazla kontur', () {
      expect(_contours(_glyph('ğ')), greaterThan(_contours(_glyph('g'))));
      expect(_contours(_glyph('İ')), greaterThan(_contours(_glyph('I'))));
      expect(
        _contours(_glyph('ş')),
        greaterThanOrEqualTo(_contours(_glyph('s'))),
      );
      // ğ'nin kısası g'nin üstünde.
      expect(_bounds(_glyph('ğ')).t, greaterThan(_bounds(_glyph('g')).t));
      // İ'nin noktası I'nın üstünde.
      expect(_bounds(_glyph('İ')).t, greaterThan(_bounds(_glyph('I')).t));
    });

    test('bozuk ya da TrueType olmayan veri', () {
      expect(
        () => TextFont.parse(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('layoutText', () {
    test('genişlik = ilerlemelerin toplamı; satırlar \\n ile', () {
      final s = 20 / 2048;
      int adv(String c) => _font.advanceOf(_font.glyphOf(c.runes.single));
      final one = layoutText(_font, 'ab', 20);
      expect(one.width, closeTo((adv('a') + adv('b')) * s, 1e-9));
      expect(one.height, closeTo(one.lineHeight, 1e-9));
      expect(one.glyphs, hasLength(2));
      expect(one.glyphs[1].x, closeTo(adv('a') * s, 1e-9));

      final two = layoutText(_font, 'ab\nabc', 20);
      expect(two.height, closeTo(2 * two.lineHeight, 1e-9));
      expect(two.width, closeTo((adv('a') + adv('b') + adv('c')) * s, 1e-9));
      expect(
        two.glyphs[2].baseline - two.glyphs[0].baseline,
        closeTo(two.lineHeight, 1e-9),
      );
    });

    test('büyüklükle doğrusal ölçeklenir', () {
      final a = layoutText(_font, 'x² + √2', 12);
      final b = layoutText(_font, 'x² + √2', 24);
      expect(b.width, closeTo(a.width * 2, 1e-9));
      expect(b.height, closeTo(a.height * 2, 1e-9));
    });

    test('boş metin bir satır yüksekliğinde', () {
      final l = layoutText(_font, '', 16);
      expect(l.width, 0);
      expect(l.height, closeTo(l.lineHeight, 1e-9));
    });

    test('dış hat kutunun içinde kalır', () {
      final item = measureTextItem(
        _font,
        const TextItem(
          id: 't',
          text: 'Ağ\nx²',
          color: 0xFF000000,
          fontSize: 18,
          x: 100,
          y: 200,
          width: 0,
          height: 0,
        ),
      );
      final b = _bounds(
        textOutline(_font, layoutText(_font, item.text, 18), item.x, item.y),
      );
      expect(b.l, greaterThanOrEqualTo(item.x - 1));
      expect(b.r, lessThanOrEqualTo(item.x + item.width + 1));
      expect(b.b, greaterThanOrEqualTo(item.y)); // y aşağı: üst kenar
      expect(b.t, lessThanOrEqualTo(item.y + item.height));
    });
  });

  group('metin görünümü', () {
    const item = TextItem(
      id: 'm1',
      text: 'Çöz: x² = 4',
      color: 0xFFD42A3F,
      fontSize: 20,
      x: 50,
      y: 60,
      width: 0,
      height: 0,
    );

    test('Stamp, dolgu yolu, metin /Contents\'te', () {
      final ap = appearanceFor(item, const PdfAffine.flipY(800), font: _font)!;
      expect(ap.kind, AnnotationKind.stamp);
      expect(ap.contents, 'Çöz: x² = 4');
      expect(ap.stream, contains(' c\n'));
      expect(ap.stream.trim(), endsWith('f\nQ'));
      expect(ap.stream, contains('rg'));
      // Kutu: sayfada y=60'tan aşağı → PDF'te 800-60'ın altı.
      expect(ap.rect.top, lessThanOrEqualTo(800 - 60 + 1.01));
      expect(ap.rect.left, closeTo(50 - 1, 0.5));
    });

    test('font yoksa metin atlanır', () {
      expect(appearanceFor(item, const PdfAffine.flipY(800)), isNull);
    });
  });
}
