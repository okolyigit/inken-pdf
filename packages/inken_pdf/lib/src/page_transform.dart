import 'package:inken_core/inken_core.dart';

/// Ekranda görünen sayfa uzayından (pt, orijin sol üst, y aşağı, sayfa
/// `/Rotate` ile döndürülmüş hâliyle) PDF kullanıcı uzayına dönüşüm.
///
/// [box] PDFium'un sayfayı çizdiği kutudur (CropBox, yoksa MediaBox);
/// [rotation] saat yönünde çeyrek tur sayısıdır (`/Rotate` / 90, 0..3).
PdfAffine pageToPdfTransform(PdfRect box, int rotation) {
  final x0 = box.left, y0 = box.bottom, x1 = box.right, y1 = box.top;
  return switch (rotation % 4) {
    // Sol üst köşe (x0, y1); aşağı inmek y'yi azaltır.
    0 => PdfAffine(1, 0, 0, -1, x0, y1),
    // Saat yönünde 90°: kullanıcı uzayının sol alt köşesi ekranda sol üstte.
    1 => PdfAffine(0, 1, 1, 0, x0, y0),
    2 => PdfAffine(-1, 0, 0, 1, x1, y0),
    // 270°: sağ üst köşe ekranda sol üstte.
    _ => PdfAffine(0, -1, -1, 0, x1, y1),
  };
}
