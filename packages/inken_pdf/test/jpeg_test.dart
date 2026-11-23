import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inken_pdf/inken_pdf.dart';

void main() {
  /// Sol yarı kırmızı, sağ yarı mavi BGRA.
  Uint8List bgra(int w, int h) {
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final red = x < w ~/ 2;
        px[i] = red ? 0x20 : 0xE0; // B
        px[i + 1] = 0x20; // G
        px[i + 2] = red ? 0xE0 : 0x20; // R
        px[i + 3] = 0xFF;
      }
    }
    return px;
  }

  test('JPEG: boyut korunur, renk kanalları doğru sırada', () {
    final jpeg = encodeJpegBgra(bgra(64, 32), 64, 32);
    expect(jpeg.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG başlığı');
    final decoded = img.decodeJpg(jpeg)!;
    expect((decoded.width, decoded.height), (64, 32));
    final left = decoded.getPixel(8, 16);
    final right = decoded.getPixel(56, 16);
    expect(left.r, greaterThan(180));
    expect(left.b, lessThan(80));
    expect(right.b, greaterThan(180));
    expect(right.r, lessThan(80));
  });

  test('kalite düşünce dosya küçülür', () {
    // Gürültülü görüntü: kalite farkı boyutta görünsün.
    final px = bgra(128, 128);
    for (var i = 0; i < px.length; i += 4) {
      px[i + 1] = (i * 2654435761) >> 24 & 0xFF;
    }
    final high = encodeJpegBgra(px, 128, 128, quality: 95);
    final low = encodeJpegBgra(px, 128, 128, quality: 30);
    expect(low.length, lessThan(high.length));
  });

  test('alt görünüm (offsetli tampon) doğru okunur', () {
    final whole = Uint8List(16 + 64 * 32 * 4)..setAll(16, bgra(64, 32));
    final view = Uint8List.sublistView(whole, 16);
    final decoded = img.decodeJpg(encodeJpegBgra(view, 64, 32))!;
    expect(decoded.getPixel(8, 16).r, greaterThan(180));
  });
}
