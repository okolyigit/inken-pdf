import 'model.dart';
import 'print_layout.dart' show parsePageRanges;

/// Dışa aktarma penceresinin seçimleri ve sayfa seçimi. Flutter'dan
/// bağımsız; pencere ve yazıcı bu kurallara göre çalışır.

/// Ne üretilir.
enum ExportFormat {
  /// Çizimler sayfa içeriğine gömülü PDF: her okuyucuda aynı, öğrenciye.
  flattened,

  /// Inken'de düzenlenmeye devam eden PDF (kaydetmedeki gibi).
  editable,

  /// Her sayfa bir görsel; birden çok sayfa tek ZIP.
  images,
}

/// Hangi sayfalar.
enum ExportPageSet {
  all,
  current,

  /// Üzerinde çizim (herhangi bir öğe) olan sayfalar.
  drawn,
  range,
}

/// Görsel dışa aktarmanın çözünürlükleri (dpi): ekran, paylaşma, baskı.
const List<int> exportDpis = [96, 150, 300];

/// Varsayılan görsel çözünürlüğü.
const int defaultExportDpi = 150;

/// Görselin uzun kenarı en çok bu kadar piksel (300 dpi'de A3'e yeter).
const int maxExportPixels = 6000;

/// Dışa aktarılacak sayfalar (0'dan, belgedeki sırayla, tekrarsız).
/// Geçersiz aralıkta `null`; boş liste "uyan sayfa yok" demektir.
///
/// [skipBlankInserted]: araya eklenip üzerine bir şey konmamış sayfalar
/// atlanır (dosyadan gelen boş sayfalar kalır).
List<int>? selectExportPages(
  InkenDocument doc,
  ExportPageSet set, {
  int current = 0,
  String range = '',
  bool skipBlankInserted = false,
}) {
  final count = doc.pages.length;
  if (count == 0) return const [];
  final List<int> picked;
  switch (set) {
    case ExportPageSet.all:
      picked = [for (var i = 0; i < count; i++) i];
    case ExportPageSet.current:
      picked = [current.clamp(0, count - 1)];
    case ExportPageSet.drawn:
      picked = [
        for (var i = 0; i < count; i++)
          if (doc.pages[i].items.isNotEmpty) i,
      ];
    case ExportPageSet.range:
      final parsed = parsePageRanges(range, count);
      if (parsed == null) return null;
      final seen = <int>{};
      picked = [
        for (final p in parsed)
          if (seen.add(p)) p,
      ];
  }
  if (!skipBlankInserted) return picked;
  return [
    for (final i in picked)
      if (!(doc.pages[i].isInserted && doc.pages[i].items.isEmpty)) i,
  ];
}

// ---- cevap anahtarı / öğrenci kopyası

/// Öğenin rengi, saydamlığı atılmış (`0xRRGGBB`); renksiz öğede (görsel)
/// `null`. Metnin ve fosforlunun saydamlığı renk sayılmaz: yarı saydam
/// kırmızı da "kırmızı"dır.
int? itemRgb(InkItem item) => switch (item) {
  Stroke(:final color) ||
  Shape(:final color) ||
  TextItem(:final color) => color & 0xFFFFFF,
  ImageItem() => null,
};

/// [pages] sayfalarındaki öğelerin renkleri (`0xRRGGBB`), ilk görülme
/// sırasıyla, tekrarsız.
List<int> usedColors(InkenDocument doc, Iterable<int> pages) {
  final seen = <int>{};
  return [
    for (final p in pages)
      for (final item in doc.pages[p].items)
        if (itemRgb(item) case final rgb? when seen.add(rgb)) rgb,
  ];
}

/// [pages] sayfalarında görsel var mı?
bool hasImages(InkenDocument doc, Iterable<int> pages) =>
    pages.any((p) => doc.pages[p].items.any((i) => i is ImageItem));

/// [colors] renklerindeki (`0xRRGGBB`) öğeleri ve [images] ise görselleri
/// çıkarılmış kopya: öğrenci kopyası (cevaplar kırmızıysa kırmızı gizlenir).
/// Sayfalar ve sıraları değişmez; hiçbir şey gizlenmiyorsa aynı belge.
InkenDocument hideItems(
  InkenDocument doc, {
  Set<int> colors = const {},
  bool images = false,
}) {
  if (colors.isEmpty && !images) return doc;
  bool hidden(InkItem item) => switch (itemRgb(item)) {
    null => images,
    final rgb => colors.contains(rgb),
  };
  return doc.copyWith(
    pages: [
      for (final page in doc.pages)
        page.items.any(hidden)
            ? page.copyWith(
                items: [
                  for (final i in page.items)
                    if (!hidden(i)) i,
                ],
              )
            : page,
    ],
  );
}
