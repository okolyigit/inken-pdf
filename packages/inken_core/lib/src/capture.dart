import 'dart:math' as math;

import 'model.dart';

/// Bölge yakalama (ekran görüntüsü): seçilen dikdörtgen, görüntünün piksel
/// boyutu, tek sayfalık kopya ve yakalananın yeni sayfadaki yeri.

/// Sayfa uzayında dikdörtgen (pt; orijin sol üst, y aşağı).
typedef PageRegion = ({double left, double top, double right, double bottom});

/// Bundan küçük sürükleme (pt, iki kenarda da) bölge sayılmaz: dokunuştur
/// (sayfanın tamamı yakalanır).
const double minCaptureSize = 6;

/// Yakalamanın varsayılan çözünürlüğü (nokta / inç): yazdırmaya ve
/// büyütmeye yetecek kadar keskin, paylaşmak için makul boyutta.
const double captureDpi = 200;

/// Görüntünün uzun kenarı en çok bu kadar piksel (bellek ve dosya boyutu).
const int maxCapturePixels = 4096;

const double _ptPerInch = 72;

/// Sürüklemenin iki ucundan (x1, y1) – (x2, y2) sayfanın içine kırpılmış
/// dikdörtgen. Kırpıldıktan sonra iki kenardan biri [minSize]'tan küçükse
/// `null` (dokunuş ya da sayfa dışı).
PageRegion? captureRegion(
  double x1,
  double y1,
  double x2,
  double y2, {
  required double pageWidth,
  required double pageHeight,
  double minSize = minCaptureSize,
}) {
  final l = math.max(0.0, math.min(x1, x2));
  final t = math.max(0.0, math.min(y1, y2));
  final r = math.min(pageWidth, math.max(x1, x2));
  final b = math.min(pageHeight, math.max(y1, y2));
  if (r - l < minSize || b - t < minSize) return null;
  return (left: l, top: t, right: r, bottom: b);
}

/// [page]'in tamamı.
PageRegion wholePage(PageLayer page) =>
    (left: 0, top: 0, right: page.width, bottom: page.height);

/// Bölgenin genişliği ve yüksekliği (pt).
double regionWidth(PageRegion r) => r.right - r.left;
double regionHeight(PageRegion r) => r.bottom - r.top;

/// [region]'ın [dpi] çözünürlükte piksel boyutu ve ölçeği (piksel / pt).
/// Uzun kenar [maxPixels]'i aşarsa ölçek küçültülür; kenarlar en az 1 px.
({int width, int height, double scale}) captureSize(
  PageRegion region, {
  double dpi = captureDpi,
  int maxPixels = maxCapturePixels,
}) {
  final w = regionWidth(region), h = regionHeight(region);
  if (w <= 0 || h <= 0 || dpi <= 0 || maxPixels <= 0) {
    throw ArgumentError('Bölge ve çözünürlük pozitif olmalı');
  }
  var scale = dpi / _ptPerInch;
  final long = math.max(w, h) * scale;
  if (long > maxPixels) scale *= maxPixels / long;
  return (
    width: math.max(1, (w * scale).round()),
    height: math.max(1, (h * scale).round()),
    scale: scale,
  );
}

/// Belgenin yalnızca [indexes] sayfalarından (verilen sırayla) oluşan
/// kopyası: düzleştirip çizerken yalnızca gereken sayfalar yazılır. Sayfa
/// tekrarlanamaz (dosyadaki bir sayfa modelde bir kez bulunur).
InkenDocument pageSubset(InkenDocument doc, Iterable<int> indexes) {
  final seen = <int>{};
  final pages = <PageLayer>[];
  for (final i in indexes) {
    if (i < 0 || i >= doc.pages.length) {
      throw RangeError.index(i, doc.pages, 'indexes');
    }
    if (!seen.add(i)) throw ArgumentError.value(i, 'indexes', 'iki kez');
    pages.add(doc.pages[i]);
  }
  if (pages.isEmpty) throw ArgumentError.value(indexes, 'indexes', 'boş');
  return doc.copyWith(pages: pages);
}

/// Yakalanan bölgenin yeni sayfadaki yeri: üstte ortalı, kenarlardan
/// [margin] içeride. Bölge kaynaktaki boyutunda kalır (kitaptaki soru aynı
/// büyüklükte); genişliğe sığmazsa ya da sayfa yüksekliğinin
/// [maxHeightFraction]'ını aşarsa orantılı küçültülür, altta çözüme yer
/// kalsın.
({double x, double y, double width, double height}) placeCapture({
  required double regionWidth,
  required double regionHeight,
  required double pageWidth,
  required double pageHeight,
  double margin = 36,
  double maxHeightFraction = 0.6,
}) {
  if (regionWidth <= 0 || regionHeight <= 0) {
    throw ArgumentError('Bölge boş');
  }
  final m = math.min(margin, math.min(pageWidth, pageHeight) / 4);
  final maxW = math.max(1.0, pageWidth - 2 * m);
  final maxH = math.max(1.0, pageHeight * maxHeightFraction);
  final s = math.min(1.0, math.min(maxW / regionWidth, maxH / regionHeight));
  final w = regionWidth * s, h = regionHeight * s;
  return (x: (pageWidth - w) / 2, y: m, width: w, height: h);
}
