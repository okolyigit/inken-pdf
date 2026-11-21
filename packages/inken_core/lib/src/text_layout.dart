import 'dart:math' as math;

import 'model.dart';
import 'text_font.dart';

/// Yerleştirilmiş bir glif: kutunun sol üstüne göre x ve taban çizgisi y
/// (sayfa birimi, y aşağı).
typedef PlacedGlyph = ({int glyph, double x, double baseline});

/// Bir metnin yerleşimi. Satırlar yalnızca `\n` ile ayrılır (kendiliğinden
/// kaydırma yok): ekran ve PDF aynı satırları üretir.
class TextLayout {
  const TextLayout({
    required this.width,
    required this.height,
    required this.lineHeight,
    required this.scale,
    required this.glyphs,
  });

  /// Kutunun ölçüleri (pt): en uzun satır × satır sayısı.
  final double width;
  final double height;
  final double lineHeight;

  /// Font biriminden sayfa birimine çarpan.
  final double scale;
  final List<PlacedGlyph> glyphs;
}

/// [text]'i [font] ile [fontSize] (pt) büyüklüğünde yerleştirir.
TextLayout layoutText(TextFont font, String text, double fontSize) {
  final scale = fontSize / font.unitsPerEm;
  final lineHeight = (font.ascender - font.descender + font.lineGap) * scale;
  final ascent = font.ascender * scale;
  final glyphs = <PlacedGlyph>[];
  final space = font.glyphOf(0x20);
  var width = 0.0;
  final lines = text.replaceAll('\r', '').split('\n');
  for (final (i, line) in lines.indexed) {
    final baseline = i * lineHeight + ascent;
    var x = 0.0;
    for (final rune in line.runes) {
      if (rune == 0x09) {
        // Sekme: dört boşluk.
        x += 4 * font.advanceOf(space) * scale;
        continue;
      }
      final g = font.glyphOf(rune);
      glyphs.add((glyph: g, x: x, baseline: baseline));
      x += font.advanceOf(g) * scale;
    }
    width = math.max(width, x);
  }
  return TextLayout(
    width: width,
    height: lines.length * lineHeight,
    lineHeight: lineHeight,
    scale: scale,
    glyphs: glyphs,
  );
}

/// Metnin harf şekilleri, sayfa uzayında ((ox, oy) kutunun sol üstü, y
/// aşağı). Ekranda ve PDF'te aynı yol çizilir (dolgu, sıfırdan farklı
/// sarım kuralı).
List<OutlineCommand> textOutline(
  TextFont font,
  TextLayout layout,
  double ox,
  double oy,
) {
  final out = <OutlineCommand>[];
  final s = layout.scale;
  for (final g in layout.glyphs) {
    final bx = ox + g.x, by = oy + g.baseline;
    double x(double ux) => bx + ux * s;
    double y(double uy) => by - uy * s;
    for (final c in font.outlineOf(g.glyph)) {
      out.add(switch (c) {
        MoveTo() => MoveTo(x(c.x), y(c.y)),
        LineTo() => LineTo(x(c.x), y(c.y)),
        QuadTo() => QuadTo(x(c.cx), y(c.cy), x(c.x), y(c.y)),
        ClosePath() => c,
      });
    }
  }
  return out;
}

/// Metin öğesinin ölçülerini yerleşime göre günceller (boyutu, yazı ve
/// büyüklük belirler; kutu elle boyutlanmaz).
TextItem measureTextItem(TextFont font, TextItem item) {
  final l = layoutText(font, item.text, item.fontSize);
  return item.copyWith(width: l.width, height: l.height);
}
