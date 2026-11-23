import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:inken_core/inken_core.dart';
import 'package:pdfrx/pdfrx.dart';

import 'print_raster.dart' show toGrayscale;

/// Görüntünün dosya biçimi.
enum ImageEncoding {
  /// Kayıpsız; metin ve çizim keskin. Varsayılan.
  png,

  /// Kayıplı, çok daha küçük (taranmış ve fotoğraflı sayfalar); saydamlık
  /// yok (zemin zaten beyaz).
  jpeg,
}

/// JPEG'in varsayılan kalitesi (1–100): metin okunur, dosya küçük.
const int defaultJpegQuality = 85;

/// Bir sayfanın (ya da bölgesinin) görüntüsü: dosya baytları (PNG ya da
/// JPEG) ve piksel boyutu.
typedef PageImage = ({Uint8List bytes, int width, int height});

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
  /// gri tonlamalı. [encoding]: PNG ya da JPEG ([quality] 1–100; JPEG
  /// ayrı isolate'te kodlanır, arayüz takılmasın).
  Future<PageImage> render(
    int index,
    PageRegion region, {
    required double scale,
    bool grayscale = false,
    ImageEncoding encoding = ImageEncoding.png,
    int quality = defaultJpegQuality,
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
    final bytes = switch (encoding) {
      ImageEncoding.png => await _encodePng(bgra, width, height),
      ImageEncoding.jpeg => await Isolate.run(
        () => encodeJpegBgra(bgra, width, height, quality: quality),
      ),
    };
    return (bytes: bytes, width: width, height: height);
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

/// BGRA8888 pikselleri ([width] × [height], üstten aşağı) JPEG'e çevirir.
/// Saydamlık atılır (sayfa zemini beyazdır).
Uint8List encodeJpegBgra(
  Uint8List bgra,
  int width,
  int height, {
  int quality = defaultJpegQuality,
}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bgra.buffer,
    bytesOffset: bgra.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(image, quality: quality.clamp(1, 100));
}
