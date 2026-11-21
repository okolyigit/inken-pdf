import 'dart:math' as math;

import 'model.dart';

/// Sayfa düzeni yardımcıları: araya sayfa ekleme / silme / döndürme ve
/// görüntüleme kopyasının yeniden üretilmesi gerekip gerekmediği.

/// Sayfanın yönü.
enum PageOrientation { portrait, landscape }

/// [page]'in ekrandaki yönü; kare sayfa dikey sayılır.
PageOrientation orientationOf(PageLayer page) => page.width > page.height
    ? PageOrientation.landscape
    : PageOrientation.portrait;

/// [after] numaralı sayfanın arkasına eklenecek boş [template] sayfası;
/// boyutu o sayfanınkiyle aynıdır (A4 dikeyde A4 dikey). [orientation]
/// verilirse kenarlar o yöne çevrilir (A4 dikeyden sonra yatay A4).
/// [color]: kâğıt rengi (beyaz ise alan boş kalır).
PageLayer newPageLike(
  InkenDocument doc,
  int after,
  PageTemplate template, {
  PageOrientation? orientation,
  PageColor color = PageColor.white,
}) {
  final like = doc.pages[after.clamp(0, doc.pages.length - 1)];
  final long = math.max(like.width, like.height);
  final short = math.min(like.width, like.height);
  final (width, height) = switch (orientation) {
    null => (like.width, like.height),
    PageOrientation.portrait => (short, long),
    PageOrientation.landscape => (long, short),
  };
  return PageLayer(
    template: template,
    color: color == PageColor.white ? null : color,
    width: width,
    height: height,
  );
}

/// [turns] çeyrek tur saat yönünde döndürülen [width] × [height] sayfada
/// (x, y) noktasının yeni yeri. Orijin sol üst, y aşağı.
(double, double) _rotatePoint(
  double x,
  double y,
  int turns,
  double width,
  double height,
) => switch (turns % 4) {
  1 => (height - y, x),
  2 => (width - x, height - y),
  3 => (y, width - x),
  _ => (x, y),
};

/// Öğeyi, [width] × [height] sayfa [turns] çeyrek tur saat yönünde
/// dönünce gelecek yere taşır. Çizgi, şekil ve serbest çizim sayfayla
/// birlikte döner; metin ve görsel dik kalır, yalnızca ortaları döner
/// (modelde açıları yok). Kimlik aynı kalır.
InkItem rotateItem(InkItem item, int turns, double width, double height) {
  final t = turns % 4;
  if (t == 0) return item;
  (double, double) r(double x, double y) =>
      _rotatePoint(x, y, t, width, height);
  switch (item) {
    case Stroke(:final points):
      return item.copyWith(
        points: [
          for (final p in points)
            if (r(p.x, p.y) case (final x, final y)) InkPoint(x, y, p.p),
        ],
      );
    case Shape(:final x1, :final y1, :final x2, :final y2):
      final (ax, ay) = r(x1, y1);
      final (bx, by) = r(x2, y2);
      return item.copyWith(x1: ax, y1: ay, x2: bx, y2: by);
    case TextItem(:final x, :final y, :final width, :final height):
      final (cx, cy) = r(x + width / 2, y + height / 2);
      return item.copyWith(x: cx - width / 2, y: cy - height / 2);
    case ImageItem(:final x, :final y, :final width, :final height):
      final (cx, cy) = r(x + width / 2, y + height / 2);
      return item.copyWith(x: cx - width / 2, y: cy - height / 2);
  }
}

/// Sayfayı [turns] çeyrek tur saat yönünde (negatif: ters yönde) döndürür:
/// boyut (tek turda) yer değiştirir, çizimler sayfayla döner. Dosyadan
/// gelen sayfada döndürme [PageLayer.rotation]'a eklenir (kayıtta
/// `/Rotate`'e yazılır); araya eklenen sayfanın yalnızca boyutu döner,
/// zemini yeni yöne göre çizilir.
PageLayer rotatePage(PageLayer page, int turns) {
  final t = turns % 4;
  if (t == 0) return page;
  final odd = t.isOdd;
  final pending = page.isInserted ? 0 : (page.pendingTurns + t) % 4;
  return page.copyWith(
    width: odd ? page.height : page.width,
    height: odd ? page.width : page.height,
    rotation: pending == 0 ? null : pending,
    items: [
      for (final item in page.items)
        rotateItem(item, t, page.width, page.height),
    ],
  );
}

/// Sayfaların düzenini (çizimler hariç) özetleyen anahtar: iki model aynı
/// anahtarı veriyorsa görüntüleme kopyası aynıdır.
String pageLayoutKey(InkenDocument doc) => [
  for (final p in doc.pages)
    p.sourceIndex != null
        ? '${p.sourceIndex}r${p.pendingTurns}'
        : '${p.template?.name}:${p.color?.name}:${p.width}x${p.height}',
].join(',');

/// Model, [sourceCount] sayfalık dosyanın sayfalarını hiç değiştirmeden mi
/// gösteriyor (ekleme / silme / döndürme yok)? Öyleyse dosyanın kendisi
/// gösterilir.
bool isSourceLayout(InkenDocument doc, int sourceCount) {
  if (doc.pages.length != sourceCount) return false;
  for (final (i, p) in doc.pages.indexed) {
    if (p.sourceIndex != i || p.pendingTurns != 0) return false;
  }
  return true;
}

/// Görüntüleme kopyasını yeniden üretmek için modelin yalnızca sayfa düzeni
/// (çizimler boşaltılmış).
InkenDocument pageLayoutOnly(InkenDocument doc) => doc.copyWith(
  pages: [for (final p in doc.pages) p.copyWith(items: const [])],
);

/// Bilinen kâğıt boyutları (pt, dikey): belge özelliklerinde ad olarak
/// gösterilir.
const Map<String, (double, double)> paperSizes = {
  'A3': (841.89, 1190.55),
  'A4': (595.28, 841.89),
  'A5': (419.53, 595.28),
  'B5': (498.9, 708.66),
  'Letter': (612, 792),
  'Legal': (612, 1008),
};

/// [width] × [height] (pt) bilinen bir kâğıt boyutuysa adı (yönü
/// fark etmez, ±2 pt hoşgörü); değilse `null`.
String? paperSizeName(double width, double height) {
  final (short, long) = width < height ? (width, height) : (height, width);
  for (final MapEntry(key: name, value: (w, h)) in paperSizes.entries) {
    if ((short - w).abs() <= 2 && (long - h).abs() <= 2) return name;
  }
  return null;
}

/// pt → mm, en yakın tam sayıya.
int ptToMm(double pt) => (pt * 25.4 / 72).round();
