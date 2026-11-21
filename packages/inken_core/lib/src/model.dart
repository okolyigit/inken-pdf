import 'package:freezed_annotation/freezed_annotation.dart';

import 'inken_core_base.dart';

part 'model.freezed.dart';
part 'model.g.dart';

/// Bir çizgi noktası: sayfa uzayında konum ve 0..1 arası basınç.
/// Basınç bilgisi olmayan girdilerde (fare, basınçsız dokunma) [p] 0.5'tir.
@immutable
class InkPoint {
  const InkPoint(this.x, this.y, [this.p = 0.5]);
  final double x;
  final double y;
  final double p;

  @override
  bool operator ==(Object other) =>
      other is InkPoint && other.x == x && other.y == y && other.p == p;

  @override
  int get hashCode => Object.hash(x, y, p);

  @override
  String toString() => 'InkPoint($x, $y, $p)';
}

/// Noktaları JSON'da düz sayı listesi olarak saklar: `[x0, y0, p0, x1, …]`.
/// Nesne listesine göre dosyayı belirgin biçimde küçültür.
class InkPointsConverter
    implements JsonConverter<List<InkPoint>, List<dynamic>> {
  const InkPointsConverter();

  @override
  List<InkPoint> fromJson(List<dynamic> json) {
    if (json.length % 3 != 0) {
      throw const FormatException('Nokta listesi 3\'ün katı olmalı');
    }
    return [
      for (var i = 0; i < json.length; i += 3)
        InkPoint(
          (json[i] as num).toDouble(),
          (json[i + 1] as num).toDouble(),
          (json[i + 2] as num).toDouble(),
        ),
    ];
  }

  @override
  List<dynamic> toJson(List<InkPoint> points) => [
    for (final pt in points) ...[_round(pt.x), _round(pt.y), _round(pt.p)],
  ];

  /// 1/1000 pt hassasiyet: gözle ayırt edilemez, dosyayı küçültür.
  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}

enum InkTool { pen, highlighter }

enum ShapeKind {
  line,
  arrow,
  rectangle,
  ellipse,

  /// Koordinat düzlemi: kutunun ortasından geçen eksenler ve 1 cm'lik
  /// kareler (bkz. `coordinatePlaneLines`).
  coordinate,
}

/// Araya eklenen sayfaların zemini.
enum PageTemplate { blank, grid, dotted, lined, coordinate }

/// Araya eklenen sayfanın kâğıt rengi (beyaz, siyah, saman kâğıdı).
enum PageColor { white, black, straw }

/// [PageColor]'ın PDF'e yazılan rengi (`0xAARRGGBB`).
int pageColorArgb(PageColor color) => switch (color) {
  PageColor.white => 0xFFFFFFFF,
  PageColor.black => 0xFF141414,
  PageColor.straw => 0xFFEEDFB0,
};

/// Sayfaya çizilen tek bir öğe. Renk `0xAARRGGBB` biçiminde tam sayıdır.
@Freezed(unionKey: 'type')
sealed class InkItem with _$InkItem {
  /// Serbest el çizgisi (kalem veya fosforlu).
  const factory InkItem.stroke({
    required String id,
    required InkTool tool,
    required int color,
    required double width,
    @InkPointsConverter() required List<InkPoint> points,
  }) = Stroke;

  /// İki köşesiyle tanımlı şekil. Çizgi ve okta (x1,y1) başlangıç,
  /// (x2,y2) bitiştir; dikdörtgen, elips ve koordinat düzleminde
  /// karşılıklı iki köşe.
  const factory InkItem.shape({
    required String id,
    required ShapeKind kind,
    required int color,
    required double width,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) = Shape;

  /// Metin kutusu; (x,y) kutunun sol üst köşesi.
  const factory InkItem.text({
    required String id,
    required String text,
    required int color,
    required double fontSize,
    required double x,
    required double y,
    required double width,
    required double height,
  }) = TextItem;

  /// Görsel; (x,y) sol üst köşe. Baytları modelde değil, PDF'e gömülü
  /// `inken-image-<imageId>.png` ekindedir ([imageAttachmentName]).
  /// Aynı görsel birden çok öğede kullanılabilir.
  const factory InkItem.image({
    required String id,
    required String imageId,
    required double x,
    required double y,
    required double width,
    required double height,
  }) = ImageItem;

  factory InkItem.fromJson(Map<String, dynamic> json) =>
      _$InkItemFromJson(json);
}

/// Bir sayfanın çizim katmanı.
///
/// [sourceIndex] orijinal PDF'teki sayfa sırasıdır; Inken'in eklediği
/// sayfalarda `null` olur ve [template] doludur; [color] eklenen sayfanın
/// kâğıt rengidir (`null` beyaz).
///
/// [width] / [height] sayfanın ekranda görünen boyutudur (döndürme dahil).
///
/// [rotation]: dosyadaki sayfaya henüz yazılmamış döndürme, saat yönünde
/// çeyrek tur (1..3; `null` döndürme yok). Yalnızca dosyadan gelen
/// sayfalarda olur; kayıtta sayfanın `/Rotate` değerine eklenir ve
/// sıfırlanır. Kaydedilen `inken.json`'da bu alan hiç bulunmaz (yalnızca
/// kaydedilmemiş modelde ve yedekte).
@freezed
abstract class PageLayer with _$PageLayer {
  const factory PageLayer({
    int? sourceIndex,
    PageTemplate? template,
    PageColor? color,
    required double width,
    required double height,
    int? rotation,
    @Default(<InkItem>[]) List<InkItem> items,
  }) = _PageLayer;

  const PageLayer._();

  factory PageLayer.fromJson(Map<String, dynamic> json) =>
      _$PageLayerFromJson(json);

  bool get isInserted => sourceIndex == null;

  /// Yazılmamış döndürme, 0..3 çeyrek tur.
  int get pendingTurns => (rotation ?? 0) % 4;
}

/// `inken.json` içeriği: belgenin tüm düzenlenebilir katmanı.
@freezed
abstract class InkenDocument with _$InkenDocument {
  const factory InkenDocument({
    @Default(currentFormatVersion) int formatVersion,
    @Default(<PageLayer>[]) List<PageLayer> pages,
  }) = _InkenDocument;

  const InkenDocument._();

  factory InkenDocument.fromJson(Map<String, dynamic> json) =>
      _$InkenDocumentFromJson(json);

  /// Çizimi olmayan düz bir PDF için boş katmanlar.
  factory InkenDocument.forPdf(List<({double width, double height})> sizes) =>
      InkenDocument(
        pages: [
          for (final (i, s) in sizes.indexed)
            PageLayer(sourceIndex: i, width: s.width, height: s.height),
        ],
      );

  bool get isEmpty => pages.every(
    (p) => p.items.isEmpty && !p.isInserted && p.pendingTurns == 0,
  );
}
