// Yazdırma yardımcıları: seçilen sayfaları ayırma (gerçek PDFium) ve gri
// tonlama.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'pdfium_test_helper.dart';

void main() {
  setUpPdfium();

  test('seçilen sayfalar verilen sırayla, tekrar edebilir', () {
    final src = fixture('two_pages.pdf');
    final sizes = pageSizes(src);
    expect(sizes, hasLength(2));
    final out = extractPdfPages(src, [1, 0, 1]);
    final outSizes = pageSizes(out);
    expect(outSizes, hasLength(3));
    expect(outSizes[0], sizes[1]);
    expect(outSizes[1], sizes[0]);
  });

  test('sınır dışı sayfa ya da boş liste hata verir', () {
    final src = fixture('two_pages.pdf');
    expect(() => extractPdfPages(src, [2]), throwsRangeError);
    expect(() => extractPdfPages(src, []), throwsArgumentError);
  });

  test('gri tonlama: parlaklık korunur, alfa değişmez', () {
    final px = Uint8List.fromList([
      0, 0, 255, 255, // kırmızı (BGRA)
      255, 255, 255, 128, // beyaz, yarı saydam
    ]);
    toGrayscale(px);
    expect(px.sublist(0, 3), [76, 76, 76]);
    expect(px[3], 255);
    expect(px.sublist(4, 7), [255, 255, 255]);
    expect(px[7], 128);
  });
}
