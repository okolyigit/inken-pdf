import 'dart:math' as math;

import 'coordinate_plane.dart';
import 'image_edit.dart';
import 'model.dart';
import 'stroke_builder.dart';
import 'text_font.dart';
import 'text_layout.dart';

/// Sayfa uzayından PDF kullanıcı uzayına afin dönüşüm:
/// `x' = a·x + c·y + e`, `y' = b·x + d·y + f` (PDF'in `[a b c d e f]` sırası).
///
/// Çekirdek dönüşümü yalnızca uygular; sayfa kutusu ve `/Rotate`'ten
/// hesaplanması `inken_pdf`'in işidir. Dönüşümün ölçeksiz (dönme / yansıma +
/// öteleme) olduğu varsayılır; çizgi kalınlıkları olduğu gibi yazılır.
class PdfAffine {
  const PdfAffine(this.a, this.b, this.c, this.d, this.e, this.f);

  /// Döndürülmemiş sayfa: y ekseni ters çevrilir, orijin sol alta taşınır.
  const PdfAffine.flipY(double pageHeight) : this(1, 0, 0, -1, 0, pageHeight);

  final double a, b, c, d, e, f;

  (double, double) apply(double x, double y) =>
      (a * x + c * y + e, b * x + d * y + f);

  @override
  bool operator ==(Object other) =>
      other is PdfAffine &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'PdfAffine($a, $b, $c, $d, $e, $f)';
}

/// Öğenin PDF'te hangi açıklama türüyle yazılacağı.
/// Metin Stamp olarak yazılır (görünümü harf şekilleri; font gömülmez).
/// Görsel de Stamp'tir; görünümünü yazıcı PDFium'un görsel nesnesiyle
/// üretir ([AnnotationAppearance.image]).
enum AnnotationKind { ink, square, circle, stamp, image }

/// PDF uzayında dikdörtgen (orijin sol alt, y yukarı).
typedef PdfRect = ({double left, double bottom, double right, double top});

/// Bir öğenin PDF açıklaması olarak yazılması için gereken her şey.
/// Tüm koordinatlar PDF kullanıcı uzayındadır.
class AnnotationAppearance {
  const AnnotationAppearance({
    required this.itemId,
    required this.kind,
    required this.rect,
    required this.color,
    required this.borderWidth,
    required this.inkList,
    required this.stream,
    this.contents,
    this.image,
  });

  /// Görselde: hangi görsel, birim kareyi (görsel uzayı, sol alt orijin)
  /// PDF uzayındaki yerine götüren matris ve yazmadan önce piksellere
  /// uygulanacak kırpma, döndürme ve opaklık ([transformImagePixels]).
  /// Akış ([stream]) boştur.
  final ({
    String imageId,
    PdfAffine matrix,
    CropRect crop,
    int turns,
    double opacity,
  })?
  image;

  /// `/Contents`: metin öğesinin yazısı (okuyucular ipucu / erişilebilirlik
  /// için gösterir); diğerlerinde `null`.
  final String? contents;

  final String itemId;
  final AnnotationKind kind;

  /// Açıklamanın `/Rect`'i: çizgi kalınlığı dahil sınır kutusu.
  final PdfRect rect;

  /// `0xAARRGGBB`. Alfa 255'ten küçükse akış `/GS gs` ile başlar;
  /// yazıcı alfayı `SetColor` ile verir, PDFium `/GS`'i bundan üretir.
  final int color;

  /// `/Border` kalınlığı (basınçlı kalemde taban kalınlık).
  final double borderWidth;

  /// Ink açıklamasının `/InkList`'i: her alt liste `[x0, y0, x1, y1, …]`.
  /// Square / Circle için boş.
  final List<List<double>> inkList;

  /// `/AP /N` içerik akışı.
  final String stream;

  bool get isTranslucent => (color >>> 24) < 255;
}

/// Öğenin PDF görünümünü üretir. Metin, [font]'un harf şekilleriyle
/// dolgu olarak yazılır; [font] verilmezse metin için `null` döner (yazıcı
/// öğeyi atlar ve sayar).
AnnotationAppearance? appearanceFor(
  InkItem item,
  PdfAffine toPdf, {
  TextFont? font,
}) => switch (item) {
  Stroke() => _strokeAppearance(item, toPdf),
  Shape() => _shapeAppearance(item, toPdf),
  TextItem() => font == null ? null : _textAppearance(item, toPdf, font),
  ImageItem() => _imageAppearance(item, toPdf),
};

AnnotationAppearance _imageAppearance(ImageItem g, PdfAffine t) {
  // Görselin birim karesi: (0,0) sol alt, (1,1) sağ üst. Sayfa uzayında
  // (u,v) → (x + u·w, y + (1−v)·h), ardından sayfa → PDF.
  final (e, f) = t.apply(g.x, g.y + g.height);
  final matrix = PdfAffine(
    t.a * g.width,
    t.b * g.width,
    -t.c * g.height,
    -t.d * g.height,
    e,
    f,
  );
  final corners = [
    t.apply(g.x, g.y),
    t.apply(g.x + g.width, g.y),
    t.apply(g.x, g.y + g.height),
    t.apply(g.x + g.width, g.y + g.height),
  ];
  return AnnotationAppearance(
    itemId: g.id,
    kind: AnnotationKind.image,
    rect: (
      left: corners.map((c) => c.$1).reduce(math.min),
      bottom: corners.map((c) => c.$2).reduce(math.min),
      right: corners.map((c) => c.$1).reduce(math.max),
      top: corners.map((c) => c.$2).reduce(math.max),
    ),
    color: 0xFF000000,
    borderWidth: 0,
    inkList: const [],
    stream: '',
    image: (
      imageId: g.imageId,
      matrix: matrix,
      crop: cropOf(g),
      turns: g.rotation,
      opacity: g.opacity,
    ),
  );
}

// ------------------------------------------------------------- sayı biçimi

/// PDF sayısı: en fazla 3 ondalık, sondaki sıfırlar atılır (`-0` yazılmaz).
/// 1/1000 pt, `inken.json`'daki yuvarlamayla aynı hassasiyet.
String pdfNum(double v) {
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s == '-0' ? '0' : s;
}

String _color(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  return '${pdfNum(r / 255)} ${pdfNum(g / 255)} ${pdfNum(b / 255)}';
}

/// Akış yazıcısı: noktaları dönüştürerek PDF yol işleçleri üretir.
class _Stream {
  _Stream(this.t);
  final PdfAffine t;
  final StringBuffer sb = StringBuffer();
  double _l = double.infinity, _b = double.infinity;
  double _r = -double.infinity, _t = -double.infinity;

  void op(String s) {
    sb
      ..write(s)
      ..write('\n');
  }

  /// Noktayı dönüştürür ve sınır kutusuna katar ([pad] yarıçapında).
  String pt(double x, double y, [double pad = 0]) {
    final (px, py) = t.apply(x, y);
    _l = math.min(_l, px - pad);
    _r = math.max(_r, px + pad);
    _b = math.min(_b, py - pad);
    _t = math.max(_t, py + pad);
    return '${pdfNum(px)} ${pdfNum(py)}';
  }

  void moveTo(double x, double y, [double pad = 0]) => op('${pt(x, y, pad)} m');
  void lineTo(double x, double y, [double pad = 0]) => op('${pt(x, y, pad)} l');

  /// Kuadratik eğri (screen'deki `quadraticBezierTo`), PDF'te kübik olarak.
  void quadTo(
    double fx,
    double fy,
    double cx,
    double cy,
    double x,
    double y, [
    double pad = 0,
  ]) {
    final c1x = fx + 2 / 3 * (cx - fx), c1y = fy + 2 / 3 * (cy - fy);
    final c2x = x + 2 / 3 * (cx - x), c2y = y + 2 / 3 * (cy - y);
    op('${pt(c1x, c1y, pad)} ${pt(c2x, c2y, pad)} ${pt(x, y, pad)} c');
  }

  /// Dört kübik eğriyle elips (merkez, yarıçaplar sayfa uzayında).
  void ellipse(double cx, double cy, double rx, double ry, [double pad = 0]) {
    const k = 0.5522847498;
    moveTo(cx + rx, cy, pad);
    void c(double x1, double y1, double x2, double y2, double x3, double y3) =>
        op('${pt(x1, y1, pad)} ${pt(x2, y2, pad)} ${pt(x3, y3, pad)} c');
    c(cx + rx, cy + k * ry, cx + k * rx, cy + ry, cx, cy + ry);
    c(cx - k * rx, cy + ry, cx - rx, cy + k * ry, cx - rx, cy);
    c(cx - rx, cy - k * ry, cx - k * rx, cy - ry, cx, cy - ry);
    c(cx + k * rx, cy - ry, cx + rx, cy - k * ry, cx + rx, cy);
    op('h');
  }

  PdfRect rect() {
    if (_l > _r) return (left: 0, bottom: 0, right: 0, top: 0);
    // 1 pt pay: kenar yumuşatması kırpılmasın.
    return (left: _l - 1, bottom: _b - 1, right: _r + 1, top: _t + 1);
  }

  String header(int color) {
    final s = StringBuffer('q\n');
    if ((color >>> 24) < 255) s.write('/GS gs\n');
    s.write('${_color(color)} RG\n${_color(color)} rg\n1 J\n1 j\n');
    return s.toString();
  }
}

// ------------------------------------------------------------- çizgi

AnnotationAppearance _strokeAppearance(Stroke s, PdfAffine t) {
  final st = _Stream(t);
  final pts = s.points;
  final isPen = s.tool == InkTool.pen;
  double widthAt(double p) => isPen ? penWidthAt(s.width, p) : s.width;

  if (pts.length == 1) {
    // Tek nokta: dolu daire (sıfır uzunluklu yol + yuvarlak uç her
    // okuyucuda güvenilir değil).
    final r = widthAt(pts[0].p) / 2;
    st.ellipse(pts[0].x, pts[0].y, r, r);
    st.op('f');
  } else if (pts.length > 1) {
    final constant = !isPen || pts.every((p) => p.p == pts[0].p);
    if (constant) {
      // Tek yol: yarı saydam çizgi kendi üstüne binince koyulaşmaz.
      // Ekrandaki çizimle aynı eğri: ara noktalar kontrol, orta noktalar uç.
      final w = widthAt(pts[0].p);
      final pad = w / 2;
      st.op('${pdfNum(w)} w');
      st.moveTo(pts[0].x, pts[0].y, pad);
      var fx = pts[0].x, fy = pts[0].y;
      for (var i = 1; i < pts.length - 1; i++) {
        final mx = (pts[i].x + pts[i + 1].x) / 2;
        final my = (pts[i].y + pts[i + 1].y) / 2;
        st.quadTo(fx, fy, pts[i].x, pts[i].y, mx, my, pad);
        fx = mx;
        fy = my;
      }
      st.lineTo(pts.last.x, pts.last.y, pad);
      st.op('S');
    } else {
      // Değişken kalınlık: ekrandaki gibi her parça kendi kalınlığıyla,
      // yuvarlak uçlu ayrı yol. Birleşim yerleri uçlarla örtüşür.
      var fx = pts[0].x, fy = pts[0].y;
      for (var i = 1; i < pts.length; i++) {
        final last = i == pts.length - 1;
        final tx = last ? pts[i].x : (pts[i].x + pts[i + 1].x) / 2;
        final ty = last ? pts[i].y : (pts[i].y + pts[i + 1].y) / 2;
        final w = widthAt((pts[i - 1].p + pts[i].p) / 2);
        st.op('${pdfNum(w)} w');
        st.moveTo(fx, fy, w / 2);
        if (last) {
          st.lineTo(tx, ty, w / 2);
        } else {
          st.quadTo(fx, fy, pts[i].x, pts[i].y, tx, ty, w / 2);
        }
        st.op('S');
        fx = tx;
        fy = ty;
      }
    }
  }

  final ink = <double>[];
  for (final p in pts) {
    final (x, y) = t.apply(p.x, p.y);
    ink
      ..add(x)
      ..add(y);
  }
  return AnnotationAppearance(
    itemId: s.id,
    kind: AnnotationKind.ink,
    rect: st.rect(),
    color: s.color,
    borderWidth: s.width,
    inkList: [if (ink.isNotEmpty) ink],
    stream: '${st.header(s.color)}${st.sb}Q',
  );
}

// ------------------------------------------------------------- şekil

/// Ok başının kanat uzunluğu; ekrandaki çizimle aynı formül.
double arrowHeadLength(double width) => math.max(width * 4, 8.0);

AnnotationAppearance _shapeAppearance(Shape s, PdfAffine t) {
  final st = _Stream(t);
  final pad = s.width / 2;
  st.op('${pdfNum(s.width)} w');
  final inkList = <List<double>>[];
  List<double> seg(double ax, double ay, double bx, double by) {
    final (pax, pay) = t.apply(ax, ay);
    final (pbx, pby) = t.apply(bx, by);
    return [pax, pay, pbx, pby];
  }

  final AnnotationKind kind;
  switch (s.kind) {
    case ShapeKind.line:
      kind = AnnotationKind.ink;
      st.moveTo(s.x1, s.y1, pad);
      st.lineTo(s.x2, s.y2, pad);
      inkList.add(seg(s.x1, s.y1, s.x2, s.y2));
    case ShapeKind.arrow:
      kind = AnnotationKind.ink;
      st.moveTo(s.x1, s.y1, pad);
      st.lineTo(s.x2, s.y2, pad);
      inkList.add(seg(s.x1, s.y1, s.x2, s.y2));
      final angle = math.atan2(s.y2 - s.y1, s.x2 - s.x1);
      final head = arrowHeadLength(s.width);
      for (final d in [math.pi * 5 / 6, -math.pi * 5 / 6]) {
        final hx = s.x2 + math.cos(angle + d) * head;
        final hy = s.y2 + math.sin(angle + d) * head;
        st.moveTo(s.x2, s.y2, pad);
        st.lineTo(hx, hy, pad);
        inkList.add(seg(s.x2, s.y2, hx, hy));
      }
    case ShapeKind.rectangle:
      kind = AnnotationKind.square;
      // `re` yerine kapalı yol: döndürülmüş sayfada da doğru.
      st.moveTo(s.x1, s.y1, pad);
      st.lineTo(s.x2, s.y1, pad);
      st.lineTo(s.x2, s.y2, pad);
      st.lineTo(s.x1, s.y2, pad);
      st.op('h');
    case ShapeKind.coordinate:
      // Kareler açık tonda ve ince, eksenler şeklin renginde. Ink:
      // görünümü yeniden üreten okuyucu yalnızca eksenleri çizer.
      kind = AnnotationKind.ink;
      final lines = coordinatePlaneLines(s);
      if (lines.grid.isNotEmpty) {
        st.op('${pdfNum(coordinateGridWidth(s.width))} w');
        st.op('${_color(coordinateGridColor(s.color))} RG');
        for (final g in lines.grid) {
          st.moveTo(g.x1, g.y1, pad);
          st.lineTo(g.x2, g.y2, pad);
        }
        st.op('S');
        st.op('${pdfNum(s.width)} w');
        st.op('${_color(s.color)} RG');
      }
      for (final a in lines.axes) {
        st.moveTo(a.x1, a.y1, pad);
        st.lineTo(a.x2, a.y2, pad);
        inkList.add(seg(a.x1, a.y1, a.x2, a.y2));
      }
    case ShapeKind.ellipse:
      kind = AnnotationKind.circle;
      st.ellipse(
        (s.x1 + s.x2) / 2,
        (s.y1 + s.y2) / 2,
        (s.x2 - s.x1).abs() / 2,
        (s.y2 - s.y1).abs() / 2,
        pad,
      );
  }
  st.op('S');
  return AnnotationAppearance(
    itemId: s.id,
    kind: kind,
    rect: st.rect(),
    color: s.color,
    borderWidth: s.width,
    inkList: inkList,
    stream: '${st.header(s.color)}${st.sb}Q',
  );
}

// ------------------------------------------------------------- metin

AnnotationAppearance _textAppearance(TextItem t, PdfAffine tr, TextFont font) {
  final st = _Stream(tr);
  final layout = layoutText(font, t.text, t.fontSize);
  var fx = 0.0, fy = 0.0, sx = 0.0, sy = 0.0;
  var any = false;
  for (final c in textOutline(font, layout, t.x, t.y)) {
    switch (c) {
      case MoveTo(:final x, :final y):
        st.moveTo(x, y);
        fx = sx = x;
        fy = sy = y;
        any = true;
      case LineTo(:final x, :final y):
        st.lineTo(x, y);
        fx = x;
        fy = y;
      case QuadTo(:final cx, :final cy, :final x, :final y):
        st.quadTo(fx, fy, cx, cy, x, y);
        fx = x;
        fy = y;
      case ClosePath():
        st.op('h');
        fx = sx;
        fy = sy;
    }
  }
  if (any) st.op('f');
  // Boş görünümlü (yalnızca boşluk) metinde bile kutu doğru yerde olsun.
  st.pt(t.x, t.y);
  st.pt(t.x + layout.width, t.y + layout.height);
  return AnnotationAppearance(
    itemId: t.id,
    kind: AnnotationKind.stamp,
    rect: st.rect(),
    color: t.color,
    borderWidth: 0,
    inkList: const [],
    stream: '${st.header(t.color)}${st.sb}Q',
    contents: t.text,
  );
}
