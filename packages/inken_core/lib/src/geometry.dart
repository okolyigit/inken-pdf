import 'dart:math' as math;

import 'model.dart';

/// (px,py) noktasının a–b doğru parçasına uzaklığı.
double pointSegmentDistance(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }
  final t = (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

double _cross(double ax, double ay, double bx, double by) => ax * by - ay * bx;

bool _segmentsIntersect(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double dx,
  double dy,
) {
  final d1 = _cross(bx - ax, by - ay, cx - ax, cy - ay);
  final d2 = _cross(bx - ax, by - ay, dx - ax, dy - ay);
  final d3 = _cross(dx - cx, dy - cy, ax - cx, ay - cy);
  final d4 = _cross(dx - cx, dy - cy, bx - cx, by - cy);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

/// a–b ile c–d doğru parçaları arasındaki en kısa uzaklık.
double segmentDistance(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
  double dx,
  double dy,
) {
  if (_segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy)) return 0;
  return [
    pointSegmentDistance(ax, ay, cx, cy, dx, dy),
    pointSegmentDistance(bx, by, cx, cy, dx, dy),
    pointSegmentDistance(cx, cy, ax, ay, bx, by),
    pointSegmentDistance(dx, dy, ax, ay, bx, by),
  ].reduce(math.min);
}

/// Öğenin, çizgi kalınlığı hariç sınır kutusu.
({double left, double top, double right, double bottom}) itemBounds(
  InkItem item,
) {
  switch (item) {
    case Stroke(:final points):
      var l = double.infinity, t = double.infinity;
      var r = -double.infinity, b = -double.infinity;
      for (final p in points) {
        l = math.min(l, p.x);
        r = math.max(r, p.x);
        t = math.min(t, p.y);
        b = math.max(b, p.y);
      }
      return (left: l, top: t, right: r, bottom: b);
    case Shape(:final x1, :final y1, :final x2, :final y2):
      return (
        left: math.min(x1, x2),
        top: math.min(y1, y2),
        right: math.max(x1, x2),
        bottom: math.max(y1, y2),
      );
    case TextItem(:final x, :final y, :final width, :final height) ||
        ImageItem(:final x, :final y, :final width, :final height):
      return (left: x, top: y, right: x + width, bottom: y + height);
  }
}

/// Öğenin dış hattını çoklu çizgi olarak verir: `[x0, y0, x1, y1, …]`.
/// Elips 32 parçayla yaklaşıklanır.
List<double> itemOutline(InkItem item) {
  switch (item) {
    case Stroke(:final points):
      return [
        for (final p in points) ...[p.x, p.y],
      ];
    case Shape(:final kind, :final x1, :final y1, :final x2, :final y2):
      switch (kind) {
        case ShapeKind.line || ShapeKind.arrow:
          return [x1, y1, x2, y2];
        case ShapeKind.rectangle || ShapeKind.coordinate:
          return [x1, y1, x2, y1, x2, y2, x1, y2, x1, y1];
        case ShapeKind.ellipse:
          final cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
          final rx = (x2 - x1).abs() / 2, ry = (y2 - y1).abs() / 2;
          return [
            for (var i = 0; i <= 32; i++) ...[
              cx + rx * math.cos(2 * math.pi * i / 32),
              cy + ry * math.sin(2 * math.pi * i / 32),
            ],
          ];
      }
    case TextItem(:final x, :final y, :final width, :final height) ||
        ImageItem(:final x, :final y, :final width, :final height):
      return [x, y, x + width, y, x + width, y + height, x, y + height, x, y];
  }
}

/// Üstüne yazılan zemin öğesi: görsel ve koordinat düzlemi. Kutunun içi
/// dokunma hedefidir; silgi dokunmaz.
bool isBackgroundItem(InkItem item) =>
    item is ImageItem || (item is Shape && item.kind == ShapeKind.coordinate);

double _strokeWidthOf(InkItem item) => switch (item) {
  Stroke(:final width) => width,
  Shape(:final width) => width,
  TextItem() || ImageItem() => 0,
};

/// Silginin a→b hareketi sırasında dokunduğu öğelerin kimlikleri.
///
/// [radius] silginin yarıçapıdır (sayfa uzayında). Şekillerde yalnızca
/// kenar çizgisi, metinde ve görselde kutunun tamamı hedef sayılır.
/// [images] `false` ise zemin öğeleri ([isBackgroundItem]: görsel,
/// koordinat düzlemi) atlanır: silgi onlara dokunmaz (üstüne yazılan
/// çizgiyi silerken zemin gitmesin).
Set<String> itemsHitBySegment(
  PageLayer page,
  double ax,
  double ay,
  double bx,
  double by,
  double radius, {
  bool images = true,
}) {
  final hits = <String>{};
  final el = math.min(ax, bx), er = math.max(ax, bx);
  final et = math.min(ay, by), eb = math.max(ay, by);
  for (final item in page.items) {
    if (!images && isBackgroundItem(item)) continue;
    final reach = radius + _strokeWidthOf(item) / 2;
    final box = itemBounds(item);
    if (er < box.left - reach ||
        el > box.right + reach ||
        eb < box.top - reach ||
        et > box.bottom + reach) {
      continue;
    }
    if (item is TextItem || isBackgroundItem(item)) {
      // Kutu ön filtresinden geçti; kutunun içi de hedef.
      final inside =
          ax >= box.left &&
          ax <= box.right &&
          ay >= box.top &&
          ay <= box.bottom;
      if (inside) {
        hits.add(item.id);
        continue;
      }
    }
    final o = itemOutline(item);
    if (o.length == 2) {
      if (pointSegmentDistance(o[0], o[1], ax, ay, bx, by) <= reach) {
        hits.add(item.id);
      }
      continue;
    }
    for (var i = 0; i + 3 < o.length; i += 2) {
      if (segmentDistance(ax, ay, bx, by, o[i], o[i + 1], o[i + 2], o[i + 3]) <=
          reach) {
        hits.add(item.id);
        break;
      }
    }
  }
  return hits;
}

/// Piksel silgisi: silginin a→b hareketinin, yarıçapı [radius] olan izine
/// giren kısımları çizgiden çıkarır.
///
/// Silgi çizgiye dokunmuyorsa `null`; dokunuyorsa kalan parçaların nokta
/// listeleri (hepsi silindiyse boş). Uzun aralıklar silgi yarıçapına göre
/// ara noktalarla sıklaştırılarak kesilir; parçalarda yalnızca özgün
/// noktalar ve kesim uçları kalır (dosya gereksiz büyümez).
List<List<InkPoint>>? eraseStrokePoints(
  Stroke stroke,
  double ax,
  double ay,
  double bx,
  double by,
  double radius,
) {
  final points = stroke.points;
  if (points.isEmpty) return null;
  final reach = radius + stroke.width / 2;
  final box = itemBounds(stroke);
  if (math.max(ax, bx) < box.left - reach ||
      math.min(ax, bx) > box.right + reach ||
      math.max(ay, by) < box.top - reach ||
      math.min(ay, by) > box.bottom + reach) {
    return null;
  }
  bool hit(InkPoint p) =>
      pointSegmentDistance(p.x, p.y, ax, ay, bx, by) <= reach;

  // Sıklaştır: ardışık noktalar arası en fazla [step].
  final step = math.max(radius / 2, 0.25);
  final dense = <({InkPoint p, bool original})>[
    (p: points.first, original: true),
  ];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    final d = math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
    final n = (d / step).ceil();
    for (var k = 1; k < n; k++) {
      final t = k / n;
      dense.add((
        p: InkPoint(
          a.x + (b.x - a.x) * t,
          a.y + (b.y - a.y) * t,
          a.p + (b.p - a.p) * t,
        ),
        original: false,
      ));
    }
    dense.add((p: b, original: true));
  }

  final erased = [for (final d in dense) hit(d.p)];
  if (!erased.contains(true)) return null;

  final pieces = <List<InkPoint>>[];
  var run = <({InkPoint p, bool original})>[];
  void flush() {
    if (run.length >= 2) {
      pieces.add([
        for (final (i, d) in run.indexed)
          if (d.original || i == 0 || i == run.length - 1) d.p,
      ]);
    }
    run = [];
  }

  for (var i = 0; i < dense.length; i++) {
    if (erased[i]) {
      flush();
    } else {
      run.add(dense[i]);
    }
  }
  flush();
  return pieces;
}

// ---- seçim

/// Öğeyi (dx, dy) kadar kaydırılmış haliyle verir; kimlik aynı kalır.
InkItem translateItem(InkItem item, double dx, double dy) => switch (item) {
  Stroke(:final points) => item.copyWith(
    points: [for (final p in points) InkPoint(p.x + dx, p.y + dy, p.p)],
  ),
  Shape(:final x1, :final y1, :final x2, :final y2) => item.copyWith(
    x1: x1 + dx,
    y1: y1 + dy,
    x2: x2 + dx,
    y2: y2 + dy,
  ),
  TextItem(:final x, :final y) => item.copyWith(x: x + dx, y: y + dy),
  ImageItem(:final x, :final y) => item.copyWith(x: x + dx, y: y + dy),
};

/// (x, y) noktasındaki en üstteki öğenin kimliği; yoksa `null`.
/// [tolerance] dokunma payıdır (sayfa uzayında); çizgi kalınlığına eklenir.
String? itemAt(PageLayer page, double x, double y, double tolerance) {
  final hits = itemsHitBySegment(page, x, y, x, y, tolerance);
  if (hits.isEmpty) return null;
  for (final item in page.items.reversed) {
    if (hits.contains(item.id)) return item.id;
  }
  return null;
}

/// Sınır kutusu tamamen [left, top, right, bottom] dikdörtgeninin içinde
/// kalan öğelerin kimlikleri (çizgi kalınlığı hesaba katılmaz). Köşelerin
/// sırası önemli değildir.
Set<String> itemsInRect(
  PageLayer page,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final l = math.min(x1, x2), r = math.max(x1, x2);
  final t = math.min(y1, y2), b = math.max(y1, y2);
  return {
    for (final item in page.items)
      if (_contains(l, t, r, b, itemBounds(item))) item.id,
  };
}

bool _contains(
  double l,
  double t,
  double r,
  double b,
  ({double left, double top, double right, double bottom}) box,
) => box.left >= l && box.right <= r && box.top >= t && box.bottom <= b;

/// [ids] öğelerinin ortak sınır kutusu (çizgi kalınlığının yarısı dahil);
/// sayfada hiçbiri yoksa `null`.
({double left, double top, double right, double bottom})? selectionBounds(
  PageLayer page,
  Set<String> ids,
) {
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final item in page.items) {
    if (!ids.contains(item.id)) continue;
    final box = itemBounds(item);
    final half = _strokeWidthOf(item) / 2;
    l = math.min(l, box.left - half);
    t = math.min(t, box.top - half);
    r = math.max(r, box.right + half);
    b = math.max(b, box.bottom + half);
  }
  if (l == double.infinity) return null;
  return (left: l, top: t, right: r, bottom: b);
}

/// Öğeyi (ox, oy) noktası sabit kalacak biçimde [s] katı ölçekler; çizgi
/// kalınlığı ve yazı boyutu da ölçeklenir (görünüm birebir büyür). Basınç
/// ve kimlik değişmez.
///
/// [scaleY] verilirse orantısız ölçek: yatayda [s], dikeyde [scaleY] (kenar
/// tutamakları). Konumlar eksen eksen ölçeklenir; görsel esner; çizgi
/// kalınlığı ve yazı boyutu iki ölçeğin geometrik ortalamasıyla büyür
/// (yazı esnetilmez, kutusu yeni boyuta göre yeniden ölçülmelidir).
InkItem scaleItem(
  InkItem item,
  double s,
  double ox,
  double oy, [
  double? scaleY,
]) {
  final kx = s, ky = scaleY ?? s;
  final k = scaleY == null ? s : math.sqrt(kx * ky);
  double sx(double x) => ox + (x - ox) * kx;
  double sy(double y) => oy + (y - oy) * ky;
  return switch (item) {
    Stroke(:final points, :final width) => item.copyWith(
      width: width * k,
      points: [for (final p in points) InkPoint(sx(p.x), sy(p.y), p.p)],
    ),
    Shape(:final x1, :final y1, :final x2, :final y2, :final width) =>
      item.copyWith(
        width: width * k,
        x1: sx(x1),
        y1: sy(y1),
        x2: sx(x2),
        y2: sy(y2),
      ),
    TextItem(
      :final x,
      :final y,
      :final width,
      :final height,
      :final fontSize,
    ) =>
      item.copyWith(
        x: sx(x),
        y: sy(y),
        width: width * k,
        height: height * k,
        fontSize: fontSize * k,
      ),
    ImageItem(:final x, :final y, :final width, :final height) => item.copyWith(
      x: sx(x),
      y: sy(y),
      width: width * kx,
      height: height * ky,
    ),
  };
}

// ---- görsel

/// Görselin doğal boyutu: 1 piksel = 0,75 pt (96 dpi ekran → 72 dpi PDF).
const double imagePointsPerPixel = 0.75;

/// Yapıştırılan görselin yeri: [visible] (sayfanın ekranda görünen kısmı,
/// sayfa uzayında) ortasına; görünen alanın [fraction]'ına sığacak kadar
/// küçültülür, küçükse doğal boyutunda kalır. Sayfanın dışına taşmaz.
({double x, double y, double width, double height}) placeImage({
  required double pageWidth,
  required double pageHeight,
  required ({double left, double top, double right, double bottom}) visible,
  required int pixelWidth,
  required int pixelHeight,
  double fraction = 0.8,
}) {
  // Görünen kısım sayfayla kesiştirilir (kenar boşlukları sayılmaz).
  var l = math.max(0.0, visible.left), t = math.max(0.0, visible.top);
  var r = math.min(pageWidth, visible.right);
  var b = math.min(pageHeight, visible.bottom);
  if (r <= l || b <= t) {
    (l, t, r, b) = (0, 0, pageWidth, pageHeight);
  }
  final natW = math.max(1, pixelWidth) * imagePointsPerPixel;
  final natH = math.max(1, pixelHeight) * imagePointsPerPixel;
  final s = math.min(
    1.0,
    math.min(fraction * (r - l) / natW, fraction * (b - t) / natH),
  );
  final w = natW * s, h = natH * s;
  final x = ((l + r) / 2 - w / 2)
      .clamp(0.0, math.max(0.0, pageWidth - w))
      .toDouble();
  final y = ((t + b) / 2 - h / 2)
      .clamp(0.0, math.max(0.0, pageHeight - h))
      .toDouble();
  return (x: x, y: y, width: w, height: h);
}

/// Belgede kullanılan görsel kimlikleri.
Set<String> referencedImageIds(InkenDocument document) => {
  for (final page in document.pages)
    for (final item in page.items)
      if (item is ImageItem) item.imageId,
};

// ---- şekil çizimi

/// Çizgi ve okun kendiliğinden yatay / dikey / 45°'ye oturduğu açı payı.
const double shapeSnapDegrees = 4;

/// Şekil çizerken bitiş noktasını düzeltir; (x1, y1) başlangıçtır.
///
/// [constrain] (Shift) açıksa: dikdörtgen kare, elips daire olur; çizgi ve
/// ok 15°'nin katlarına oturur. Kapalıyken yalnızca çizgi ve ok, 45°'nin
/// katlarına [shapeSnapDegrees] kadar yakınsa oraya oturur (klavyesiz
/// tahtada düz çizgi).
({double x, double y}) constrainShapeEnd(
  ShapeKind kind,
  double x1,
  double y1,
  double x2,
  double y2, {
  bool constrain = false,
}) {
  final dx = x2 - x1, dy = y2 - y1;
  switch (kind) {
    case ShapeKind.rectangle || ShapeKind.ellipse || ShapeKind.coordinate:
      if (!constrain) return (x: x2, y: y2);
      final side = math.max(dx.abs(), dy.abs());
      return (x: x1 + (dx < 0 ? -side : side), y: y1 + (dy < 0 ? -side : side));
    case ShapeKind.line || ShapeKind.arrow:
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) return (x: x2, y: y2);
      final angle = math.atan2(dy, dx);
      final step = (constrain ? 15 : 45) * math.pi / 180;
      final snapped = (angle / step).roundToDouble() * step;
      if (!constrain &&
          (angle - snapped).abs() > shapeSnapDegrees * math.pi / 180) {
        return (x: x2, y: y2);
      }
      // Yatay / dikeyde tam sıfır çıksın (kayan nokta artığı kalmasın).
      final c = math.cos(snapped), s = math.sin(snapped);
      return (
        x: x1 + len * (c.abs() < 1e-12 ? 0 : c),
        y: y1 + len * (s.abs() < 1e-12 ? 0 : s),
      );
  }
}

// ---- renk

/// Öğenin rengini [rgb] yapar (saydamlık korunur: fosforlu yarı saydam
/// kalır). Görselin rengi yoktur; olduğu gibi döner.
InkItem recolorItem(InkItem item, int rgb) {
  int keepAlpha(int old) => (old & 0xFF000000) | (rgb & 0x00FFFFFF);
  return switch (item) {
    Stroke(:final color) => item.copyWith(color: keepAlpha(color)),
    Shape(:final color) => item.copyWith(color: keepAlpha(color)),
    TextItem(:final color) => item.copyWith(color: keepAlpha(color)),
    ImageItem() => item,
  };
}

/// Rengi olan öğe mi (görsel değil)?
bool hasColor(InkItem item) => item is! ImageItem;
