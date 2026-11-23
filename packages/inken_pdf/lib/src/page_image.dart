import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:inken_core/inken_core.dart';
import 'package:pdfrx/pdfrx.dart';

import 'print_raster.dart' show toGrayscale;

/// Bir sayfanın (ya da bölgesinin) görüntüsü: PNG baytları ve boyutu.
typedef PageImage = ({Uint8List png, int width, int height});

/// PDF sayfalarından görüntü (PNG) üretir: bölge yakalama ve sayfaları
/// görsel olarak dışa aktarma. Sayfadaki açıklamalar görüntüye girer;
/// çizimleri gömülü kopya (`writeFlattenedPdf`) verilirse görüntü kaydedilen
/// ve yazdırılanla aynıdır.
class PdfPageImager {
  PdfPageImager._(this._doc);

  final PdfDocument _doc;

  /// [pdf]'i açar; bozuksa ya da parola yanlışsa pdfrx'in hatası fırlar.
  static Future<PdfPageImager> open(Uint8List pdf, {String? password}) async =>
      PdfPageImager._(
        await PdfDocument.openData(
          pdf,
          sourceName: 'image#${identityHashCode(pdf)}',
          passwordProvider: password == null ? null : () => password,
        ),
      );

  int get pageCount => _doc.pages.length;

  /// [index]'inci sayfanın boyutu (pt, döndürme dahil).
  ({double width, double height}) pageSize(int index) {
    final page = _doc.pages[index];
    return (width: page.width, height: page.height);
  }

  /// [index]'inci sayfanın (0'dan) [region] bölgesini (pt, sayfa uzayı)
  /// [scale] piksel / pt ölçeğiyle çizer. Zemin beyazdır; [grayscale]
  /// gri tonlamalı.
  Future<PageImage> render(
    int index,
    PageRegion region, {
    required double scale,
    bool grayscale = false,
  }) async {
    final page = _doc.pages[index];
    final x = (region.left * scale).round();
    final y = (region.top * scale).round();
    final w = math.max(1, (regionWidth(region) * scale).round());
    final h = math.max(1, (regionHeight(region) * scale).round());
    final image = await page.render(
      x: x,
      y: y,
      width: w,
      height: h,
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) throw StateError('Sayfa ${index + 1} çizilemedi');
    final Uint8List bgra;
    final int width, height;
    try {
      bgra = Uint8List.fromList(image.pixels);
      width = image.width;
      height = image.height;
    } finally {
      image.dispose();
    }
    if (grayscale) toGrayscale(bgra);
    return (
      png: await _encodePng(bgra, width, height),
      width: width,
      height: height,
    );
  }

  Future<void> dispose() => _doc.dispose();
}

Future<Uint8List> _encodePng(Uint8List bgra, int width, int height) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bgra);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG yazılamadı');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}
