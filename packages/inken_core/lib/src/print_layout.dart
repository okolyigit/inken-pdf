import 'dart:math' as math;

/// Yazdırmada kâğıt boyutu; ölçüler mm, dikey.
enum PaperSize {
  a4(210, 297),
  a3(297, 420),
  a5(148, 210),
  letter(215.9, 279.4),
  legal(215.9, 355.6);

  const PaperSize(this.widthMm, this.heightMm);
  final double widthMm;
  final double heightMm;

  /// Nokta (1/72 inç) cinsinden.
  double get widthPt => widthMm / 25.4 * 72;
  double get heightPt => heightMm / 25.4 * 72;
}

/// Kâğıdın yönü. [auto]: kâğıt dikey, yatay sayfalar kâğıda sığsın diye
/// döndürülür.
enum PrintOrientation { auto, portrait, landscape }

/// Çift taraflı yazdırma.
enum PrintDuplex { off, longEdge, shortEdge }

/// "1-3, 5" gibi bir aralığı 0'dan sayfa sıralarına çevirir (sırası ve
/// tekrarı korunur: "3-1" geriye doğru). Boş ya da geçersizse veya bir
/// sayfa [pageCount]'u aşıyorsa `null`.
List<int>? parsePageRanges(String text, int pageCount) {
  final parts = text
      .split(RegExp(r'[,;]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty || pageCount < 1) return null;
  final pages = <int>[];
  for (final part in parts) {
    final m = RegExp(r'^(\d+)\s*(?:[-–]\s*(\d+))?$').firstMatch(part);
    if (m == null) return null;
    final from = int.parse(m.group(1)!);
    final to = m.group(2) == null ? from : int.parse(m.group(2)!);
    if (from < 1 || to < 1 || from > pageCount || to > pageCount) return null;
    final step = to >= from ? 1 : -1;
    for (var p = from; ; p += step) {
      pages.add(p - 1);
      if (p == to) break;
    }
  }
  return pages;
}

/// Yazıcıya gidecek sayfa sırası: [reverse] sırayı çevirir; [copies]
/// kopya, [collate] ile takım takım (1 2 3 1 2 3), değilse sayfa sayfa
/// (1 1 2 2 3 3).
List<int> printSequence(
  List<int> pages, {
  int copies = 1,
  bool collate = true,
  bool reverse = false,
}) {
  final order = reverse ? pages.reversed.toList() : pages;
  final n = math.max(1, copies);
  if (n == 1) return List.of(order);
  return collate
      ? [for (var c = 0; c < n; c++) ...order]
      : [
          for (final p in order)
            for (var c = 0; c < n; c++) p,
        ];
}

/// Kâğıdın, [orientation]'a göre yönlendirilmiş boyutu (aynı birimde).
({double width, double height}) orientedPaper(
  double width,
  double height,
  PrintOrientation orientation,
) {
  final landscape = orientation == PrintOrientation.landscape;
  final w = math.min(width, height), h = math.max(width, height);
  return landscape ? (width: h, height: w) : (width: w, height: h);
}

/// Bir sayfanın kâğıttaki yeri: dikdörtgen (kâğıdın sol üstünden, kâğıt
/// birimiyle) ve sayfa çeyrek tur döndürülerek mi basılacağı.
typedef PagePlacement = ({
  double x,
  double y,
  double width,
  double height,
  bool rotate,
});

/// [pageWidth] × [pageHeight] pt sayfayı yönlendirilmiş [paperWidth] ×
/// [paperHeight] kâğıda yerleştirir; [unitsPerPt] kâğıt biriminin bir
/// noktadaki karşılığı (ör. 300 dpi: 300 / 72).
///
/// [fit]: yazdırılabilir alana ([area], kâğıt biriminde; yoksa kâğıdın
/// tamamı) oranı korunarak sığdırılır, ortalanır. Değilse gerçek boyut:
/// kâğıdın ortasında, taşan kısım kesilir.
///
/// [orientation] otomatikse ve sayfa ile kâğıdın yönü farklıysa sayfa
/// döndürülür; elle seçilen yönde döndürülmez.
PagePlacement placeOnPaper({
  required double pageWidth,
  required double pageHeight,
  required double paperWidth,
  required double paperHeight,
  required double unitsPerPt,
  required bool fit,
  PrintOrientation orientation = PrintOrientation.auto,
  ({double x, double y, double width, double height})? area,
}) {
  final rotate =
      orientation == PrintOrientation.auto &&
      pageWidth != pageHeight &&
      paperWidth != paperHeight &&
      (pageWidth > pageHeight) != (paperWidth > paperHeight);
  final w = rotate ? pageHeight : pageWidth;
  final h = rotate ? pageWidth : pageHeight;
  final box = area ?? (x: 0.0, y: 0.0, width: paperWidth, height: paperHeight);
  if (fit) {
    final s = math.min(box.width / w, box.height / h);
    final pw = w * s, ph = h * s;
    return (
      x: box.x + (box.width - pw) / 2,
      y: box.y + (box.height - ph) / 2,
      width: pw,
      height: ph,
      rotate: rotate,
    );
  }
  final pw = w * unitsPerPt, ph = h * unitsPerPt;
  return (
    x: (paperWidth - pw) / 2,
    y: (paperHeight - ph) / 2,
    width: pw,
    height: ph,
    rotate: rotate,
  );
}
