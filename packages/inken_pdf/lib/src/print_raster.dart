import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

/// Sayfanın yazdırılabilir alana ([boxWidth] × [boxHeight] piksel)
/// sığdırılmış çizim boyutu. Sayfa ile kâğıdın yönü farklıysa (yatay sayfa,
/// dikey kâğıt) sayfa saat yönünde çeyrek tur döndürülür ([rotate]); oran
/// korunur, en az bir kenar alanı doldurur.
({int width, int height, bool rotate}) fitPageToBox(
  double pageWidth,
  double pageHeight,
  int boxWidth,
  int boxHeight,
) {
  if (pageWidth <= 0 || pageHeight <= 0 || boxWidth <= 0 || boxHeight <= 0) {
    throw ArgumentError('Boyutlar pozitif olmalı');
  }
  final rotate =
      pageWidth != pageHeight &&
      boxWidth != boxHeight &&
      (pageWidth > pageHeight) != (boxWidth > boxHeight);
  final w = rotate ? pageHeight : pageWidth;
  final h = rotate ? pageWidth : pageHeight;
  final scale = math.min(boxWidth / w, boxHeight / h);
  return (
    width: math.max(1, math.min(boxWidth, (w * scale).round())),
    height: math.max(1, math.min(boxHeight, (h * scale).round())),
    rotate: rotate,
  );
}

/// BGRA pikselleri yerinde gri tonlamaya çevirir (algılanan parlaklık:
/// 0.299 R + 0.587 G + 0.114 B); alfa değişmez.
void toGrayscale(Uint8List bgra) {
  for (var i = 0; i + 3 < bgra.length; i += 4) {
    final y = (bgra[i] * 29 + bgra[i + 1] * 150 + bgra[i + 2] * 77) >> 8;
    bgra[i] = y;
    bgra[i + 1] = y;
    bgra[i + 2] = y;
  }
}

/// Yazdırılacak bir sayfanın görüntüsü: BGRA8888, üstten aşağı satırlar
/// (Windows DIB'in beklediği biçim).
typedef PrintRaster = ({Uint8List bgra, int width, int height});

/// Yazdırma için PDF sayfalarını görüntüye çevirir. Açıklamalar (Inken
/// çizimleri) görüntüye girer.
class PdfPrintRasterizer {
  PdfPrintRasterizer._(this._doc);

  final PdfDocument _doc;

  /// [pdf]'i açar; parolalı ya da bozuksa pdfrx'in hatası fırlar.
  static Future<PdfPrintRasterizer> open(Uint8List pdf) async =>
      PdfPrintRasterizer._(
        await PdfDocument.openData(
          pdf,
          sourceName: 'print#${identityHashCode(pdf)}',
        ),
      );

  int get pageCount => _doc.pages.length;

  /// [index]'inci sayfayı (0'dan) [boxWidth] × [boxHeight] piksellik alana
  /// sığdırarak çizer ([fitPageToBox]).
  Future<PrintRaster> render(int index, int boxWidth, int boxHeight) async {
    final page = _doc.pages[index];
    final fit = fitPageToBox(page.width, page.height, boxWidth, boxHeight);
    final image = await page.render(
      fullWidth: fit.width.toDouble(),
      fullHeight: fit.height.toDouble(),
      backgroundColor: 0xFFFFFFFF,
      rotationOverride: fit.rotate ? page.rotation.rotateCW90 : null,
    );
    if (image == null) throw StateError('Sayfa ${index + 1} çizilemedi');
    try {
      return (
        bgra: Uint8List.fromList(image.pixels),
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  }

  /// [index]'inci sayfanın boyutu (pt, döndürme dahil).
  ({double width, double height}) pageSize(int index) {
    final page = _doc.pages[index];
    return (width: page.width, height: page.height);
  }

  /// [index]'inci sayfayı tam [width] × [height] piksele çizer; [rotate]
  /// ise saat yönünde çeyrek tur döndürülmüş olarak ([width] × [height]
  /// döndürülmüş boyuttur). [grayscale]: gri tonlamalı.
  Future<PrintRaster> renderSized(
    int index,
    int width,
    int height, {
    bool rotate = false,
    bool grayscale = false,
  }) async {
    final page = _doc.pages[index];
    final image = await page.render(
      fullWidth: math.max(1, width).toDouble(),
      fullHeight: math.max(1, height).toDouble(),
      backgroundColor: 0xFFFFFFFF,
      rotationOverride: rotate ? page.rotation.rotateCW90 : null,
    );
    if (image == null) throw StateError('Sayfa ${index + 1} çizilemedi');
    try {
      final bgra = Uint8List.fromList(image.pixels);
      if (grayscale) toGrayscale(bgra);
      return (bgra: bgra, width: image.width, height: image.height);
    } finally {
      image.dispose();
    }
  }

  Future<void> dispose() => _doc.dispose();
}
