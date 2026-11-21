import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';

/// Sayfaya yazılan metnin fontu (DejaVu Sans): ekranda ve PDF'te aynı harf
/// şekilleri. Baytlar kaydederken yazıcıya verilir (font dosyaya gömülmez).
class InkenTextFont {
  InkenTextFont(this.bytes) : font = TextFont.parse(bytes);

  final Uint8List bytes;
  final TextFont font;

  /// Flutter'daki aile adı (yazma kutusu bu fontla gösterilir).
  static const family = 'DejaVuSans';
  static const asset = 'assets/fonts/DejaVuSans.ttf';

  static Future<InkenTextFont> load([AssetBundle? bundle]) async {
    final data = await (bundle ?? rootBundle).load(asset);
    return InkenTextFont(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Satır yüksekliğinin font büyüklüğüne oranı (yazma kutusunun satırları
  /// çizilen metinle aynı aralıkta olsun).
  double get lineHeightFactor =>
      (font.ascender - font.descender + font.lineGap) / font.unitsPerEm;
}

/// `main` açılışta yükler; yüklenmemişse metin ekranda Flutter'ın kendi
/// çizimiyle gösterilir, kaydederken atlanır.
final textFontProvider = Provider<InkenTextFont?>((ref) => null);
