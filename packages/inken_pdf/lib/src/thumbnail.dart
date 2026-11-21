import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

/// Belgenin ilk sayfasının küçük resmi (PNG); çizilemezse `null`.
///
/// Sayfadaki açıklamalar (Inken çizimleri dahil) resme girer. [width]
/// piksel cinsindendir; yükseklik sayfanın oranından gelir.
Future<Uint8List?> renderThumbnail(Uint8List pdf, {double width = 240}) async {
  final PdfDocument doc;
  try {
    doc = await PdfDocument.openData(
      pdf,
      sourceName: 'thumbnail#${identityHashCode(pdf)}',
    );
  } on Object {
    return null; // parolalı ya da bozuk
  }
  try {
    if (doc.pages.isEmpty) return null;
    final page = doc.pages.first;
    final height = width * page.height / page.width;
    final image = await page.renderForDisplay(
      fullWidth: width,
      fullHeight: height,
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) return null;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } on Object {
    return null;
  } finally {
    await doc.dispose();
  }
}
