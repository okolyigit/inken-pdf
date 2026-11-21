import 'dart:typed_data';

/// Bir harf şeklinin (glyph) dış hat komutu, font biriminde (y yukarı).
sealed class OutlineCommand {
  const OutlineCommand();
}

class MoveTo extends OutlineCommand {
  const MoveTo(this.x, this.y);
  final double x, y;
}

class LineTo extends OutlineCommand {
  const LineTo(this.x, this.y);
  final double x, y;
}

/// İkinci derece Bézier (TrueType'ın eğrisi): (cx, cy) kontrol noktası.
class QuadTo extends OutlineCommand {
  const QuadTo(this.cx, this.cy, this.x, this.y);
  final double cx, cy, x, y;
}

class ClosePath extends OutlineCommand {
  const ClosePath();
}

/// TrueType (glyf) fontun metin yerleşimi ve harf şekilleri için gereken
/// kısmı: birim, satır ölçüleri, karakter → glif eşlemesi, ilerleme
/// genişlikleri ve dış hatlar (bileşik glifler dahil).
///
/// Ekran ve PDF aynı dış hatları kullanır: sayfaya yazılan metin her yerde
/// birebir aynı görünür, PDF'e font gömülmez. Kerning ve bağlantılı
/// harfler (ligature) uygulanmaz.
class TextFont {
  TextFont._(this._data);

  /// TrueType dosyasını okur. Desteklenmeyen biçimde [FormatException].
  factory TextFont.parse(Uint8List bytes) {
    final font = TextFont._(ByteData.sublistView(bytes));
    font._readTables();
    return font;
  }

  final ByteData _data;
  final Map<String, int> _tables = {};

  late final int unitsPerEm;

  /// Satır ölçüleri (font birimi): yükseliş (+), iniş (−), satır arası.
  late final int ascender;
  late final int descender;
  late final int lineGap;

  late final int _numGlyphs;
  late final int _numHMetrics;
  late final bool _longLoca;
  final Map<int, int> _cmap = {};
  final Map<int, List<OutlineCommand>> _outlines = {};

  int _u16(int o) => _data.getUint16(o);
  int _i16(int o) => _data.getInt16(o);
  int _u32(int o) => _data.getUint32(o);

  int _table(String tag) {
    final o = _tables[tag];
    if (o == null) throw FormatException('TrueType tablosu yok: $tag');
    return o;
  }

  void _readTables() {
    if (_data.lengthInBytes < 12) throw const FormatException('Font kısa');
    final version = _u32(0);
    if (version != 0x00010000 && version != 0x74727565 /* 'true' */ ) {
      throw const FormatException('TrueType (glyf) font değil');
    }
    final count = _u16(4);
    for (var i = 0; i < count; i++) {
      final r = 12 + i * 16;
      final tag = String.fromCharCodes([
        _data.getUint8(r),
        _data.getUint8(r + 1),
        _data.getUint8(r + 2),
        _data.getUint8(r + 3),
      ]);
      _tables[tag] = _u32(r + 8);
    }
    final head = _table('head');
    unitsPerEm = _u16(head + 18);
    _longLoca = _i16(head + 50) == 1;
    final hhea = _table('hhea');
    ascender = _i16(hhea + 4);
    descender = _i16(hhea + 6);
    lineGap = _i16(hhea + 8);
    _numHMetrics = _u16(hhea + 34);
    _numGlyphs = _u16(_table('maxp') + 4);
    _table('glyf');
    _table('loca');
    _table('hmtx');
    _readCmap();
  }

  void _readCmap() {
    final cmap = _table('cmap');
    final n = _u16(cmap + 2);
    int? best;
    var bestRank = -1;
    for (var i = 0; i < n; i++) {
      final r = cmap + 4 + i * 8;
      final platform = _u16(r), encoding = _u16(r + 2);
      final sub = cmap + _u32(r + 4);
      final format = _u16(sub);
      // Tercih: Unicode tam (format 12) > BMP (format 4).
      final rank = switch ((platform, encoding, format)) {
        (3, 10, 12) || (0, 4, 12) || (0, 6, 12) => 3,
        (3, 1, 4) || (0, 3, 4) => 2,
        (0, _, 4) => 1,
        _ => -1,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = sub;
      }
    }
    if (best == null) throw const FormatException('Unicode cmap yok');
    if (_u16(best) == 12) {
      final groups = _u32(best + 12);
      for (var g = 0; g < groups; g++) {
        final r = best + 16 + g * 12;
        final start = _u32(r), end = _u32(r + 4), glyph = _u32(r + 8);
        for (var c = start; c <= end; c++) {
          _cmap[c] = glyph + (c - start);
        }
      }
      return;
    }
    // Format 4.
    final segX2 = _u16(best + 6);
    final ends = best + 14;
    final starts = ends + segX2 + 2;
    final deltas = starts + segX2;
    final offsets = deltas + segX2;
    for (var s = 0; s < segX2 ~/ 2; s++) {
      final end = _u16(ends + s * 2);
      final start = _u16(starts + s * 2);
      final delta = _i16(deltas + s * 2);
      final ro = offsets + s * 2;
      final rangeOffset = _u16(ro);
      for (var c = start; c <= end && c != 0xFFFF; c++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (c + delta) & 0xFFFF;
        } else {
          final at = ro + rangeOffset + (c - start) * 2;
          glyph = _u16(at);
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) _cmap[c] = glyph;
      }
    }
  }

  /// Karakterin glifi; fontta yoksa 0 (".notdef").
  int glyphOf(int codePoint) => _cmap[codePoint] ?? 0;

  /// Fontta bu karakter var mı?
  bool covers(int codePoint) => _cmap.containsKey(codePoint);

  /// Glifin ilerleme genişliği (font birimi).
  int advanceOf(int glyph) {
    final hmtx = _table('hmtx');
    final i = glyph < _numHMetrics ? glyph : _numHMetrics - 1;
    return _u16(hmtx + i * 4);
  }

  (int, int) _glyphRange(int glyph) {
    final loca = _table('loca');
    if (glyph < 0 || glyph >= _numGlyphs) return (0, 0);
    if (_longLoca) {
      return (_u32(loca + glyph * 4), _u32(loca + glyph * 4 + 4));
    }
    return (_u16(loca + glyph * 2) * 2, _u16(loca + glyph * 2 + 2) * 2);
  }

  /// Glifin dış hattı (font birimi, y yukarı). Boş glifte (boşluk) boş.
  List<OutlineCommand> outlineOf(int glyph) =>
      _outlines[glyph] ??= List.unmodifiable(_readGlyph(glyph, 0));

  List<OutlineCommand> _readGlyph(int glyph, int depth) {
    if (depth > 8) return const [];
    final (start, end) = _glyphRange(glyph);
    if (end <= start) return const [];
    final g = _table('glyf') + start;
    final contours = _i16(g);
    return contours >= 0
        ? _simpleGlyph(g, contours)
        : _compositeGlyph(g, depth);
  }

  List<OutlineCommand> _simpleGlyph(int g, int contours) {
    if (contours == 0) return const [];
    final endPts = [for (var i = 0; i < contours; i++) _u16(g + 10 + i * 2)];
    final n = endPts.last + 1;
    var p = g + 10 + contours * 2;
    p += 2 + _u16(p); // talimatlar
    final flags = <int>[];
    while (flags.length < n) {
      final f = _data.getUint8(p++);
      flags.add(f);
      if (f & 8 != 0) {
        final repeat = _data.getUint8(p++);
        for (var r = 0; r < repeat; r++) {
          flags.add(f);
        }
      }
    }
    final xs = List<int>.filled(n, 0), ys = List<int>.filled(n, 0);
    var v = 0;
    for (var i = 0; i < n; i++) {
      final f = flags[i];
      if (f & 2 != 0) {
        final d = _data.getUint8(p++);
        v += f & 16 != 0 ? d : -d;
      } else if (f & 16 == 0) {
        v += _i16(p);
        p += 2;
      }
      xs[i] = v;
    }
    v = 0;
    for (var i = 0; i < n; i++) {
      final f = flags[i];
      if (f & 4 != 0) {
        final d = _data.getUint8(p++);
        v += f & 32 != 0 ? d : -d;
      } else if (f & 32 == 0) {
        v += _i16(p);
        p += 2;
      }
      ys[i] = v;
    }

    final out = <OutlineCommand>[];
    var first = 0;
    for (final last in endPts) {
      _contour(out, [
        for (var i = first; i <= last; i++)
          (x: xs[i].toDouble(), y: ys[i].toDouble(), on: flags[i] & 1 != 0),
      ]);
      first = last + 1;
    }
    return out;
  }

  /// Bir konturu komutlara çevirir. Ardışık iki eğri dışı nokta arasında
  /// örtük bir eğri üstü nokta (orta nokta) vardır.
  static void _contour(
    List<OutlineCommand> out,
    List<({double x, double y, bool on})> pts,
  ) {
    if (pts.isEmpty) return;
    // Eğri üstü bir başlangıç noktası bul (yoksa ilk iki noktanın ortası).
    var startIndex = pts.indexWhere((p) => p.on);
    final ({double x, double y}) start;
    if (startIndex == -1) {
      start = (
        x: (pts[0].x + pts[1 % pts.length].x) / 2,
        y: (pts[0].y + pts[1 % pts.length].y) / 2,
      );
      startIndex = 0;
    } else {
      start = (x: pts[startIndex].x, y: pts[startIndex].y);
    }
    out.add(MoveTo(start.x, start.y));
    ({double x, double y})? control;
    final n = pts.length;
    final allOff = !pts.any((p) => p.on);
    for (var k = 1; k <= n; k++) {
      final p = pts[(startIndex + k) % n];
      if (k == n && !allOff) {
        // Başa dönüş.
        if (control != null) {
          out.add(QuadTo(control.x, control.y, start.x, start.y));
        }
        break;
      }
      if (p.on) {
        if (control == null) {
          out.add(LineTo(p.x, p.y));
        } else {
          out.add(QuadTo(control.x, control.y, p.x, p.y));
          control = null;
        }
      } else {
        if (control != null) {
          final mx = (control.x + p.x) / 2, my = (control.y + p.y) / 2;
          out.add(QuadTo(control.x, control.y, mx, my));
        }
        control = (x: p.x, y: p.y);
      }
    }
    if (allOff && control != null) {
      out.add(QuadTo(control.x, control.y, start.x, start.y));
    }
    out.add(const ClosePath());
  }

  List<OutlineCommand> _compositeGlyph(int g, int depth) {
    final out = <OutlineCommand>[];
    var p = g + 10;
    while (true) {
      final flags = _u16(p);
      final glyph = _u16(p + 2);
      p += 4;
      double dx, dy;
      if (flags & 1 != 0) {
        dx = _i16(p).toDouble();
        dy = _i16(p + 2).toDouble();
        p += 4;
      } else {
        dx = _data.getInt8(p).toDouble();
        dy = _data.getInt8(p + 1).toDouble();
        p += 2;
      }
      // Bileşen noktalarını eşleme (ARGS_ARE_XY_VALUES yok) desteklenmez.
      if (flags & 2 == 0) dx = dy = 0;
      double a = 1, b = 0, c = 0, d = 1;
      double f2(int o) => _i16(o) / 16384;
      if (flags & 8 != 0) {
        a = d = f2(p);
        p += 2;
      } else if (flags & 0x40 != 0) {
        a = f2(p);
        d = f2(p + 2);
        p += 4;
      } else if (flags & 0x80 != 0) {
        a = f2(p);
        b = f2(p + 2);
        c = f2(p + 4);
        d = f2(p + 6);
        p += 8;
      }
      double tx(double x, double y) => a * x + c * y + dx;
      double ty(double x, double y) => b * x + d * y + dy;
      for (final cmd in _readGlyph(glyph, depth + 1)) {
        out.add(switch (cmd) {
          MoveTo(:final x, :final y) => MoveTo(tx(x, y), ty(x, y)),
          LineTo(:final x, :final y) => LineTo(tx(x, y), ty(x, y)),
          QuadTo(:final cx, :final cy, :final x, :final y) => QuadTo(
            tx(cx, cy),
            ty(cx, cy),
            tx(x, y),
            ty(x, y),
          ),
          ClosePath() => cmd,
        });
      }
      if (flags & 0x20 == 0) break; // MORE_COMPONENTS
    }
    return out;
  }
}
