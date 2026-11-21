import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// Yapıştırılan / eklenen görselin uzun kenarının en büyük hâli (piksel):
/// dosya ve bellek makul kalsın.
const int maxImageSide = 2048;

/// Açık belgenin görselleri: kimlik → PNG baytları ve ekranda çizmek için
/// çözülmüş [ui.Image]. Belgeye aittir (oturumla birlikte yaşar).
///
/// Yalnızca eklenir, hiç silinmez: geri al / yinele bir görseli geri
/// getirdiğinde baytları hâlâ buradadır. Kaydederken yalnızca modelde
/// kullanılanlar dosyaya yazılır.
class InkImages extends ChangeNotifier {
  InkImages([Map<String, Uint8List> png = const {}]) : _png = {...png};

  final Map<String, Uint8List> _png;
  final Map<String, ui.Image> _decoded = {};
  final Map<String, Future<ui.Image?>> _decoding = {};
  bool _disposed = false;

  /// Her çözülen görselde artar: sayfa resimleri yeniden kaydedilsin.
  int get version => _version;
  int _version = 0;

  /// Bütün görseller (yedek için).
  Map<String, Uint8List> get all => Map.unmodifiable(_png);

  Uint8List? png(String id) => _png[id];

  /// Görseli ekler; [decoded] verilirse yeniden çözülmez.
  void add(String id, Uint8List png, [ui.Image? decoded]) {
    _png.putIfAbsent(id, () => png);
    if (decoded != null && !_decoded.containsKey(id)) {
      _decoded[id] = decoded;
      _version++;
      notifyListeners();
    }
  }

  /// Ekranda çizilecek görsel; henüz çözülmediyse `null` döner ve çözmeyi
  /// başlatır (bitince haber verir).
  ui.Image? image(String id) {
    final ready = _decoded[id];
    if (ready == null && _png.containsKey(id)) unawaited(decode(id));
    return ready;
  }

  /// Görseli çözer (bir kez); bulunamaz ya da çözülemezse `null`.
  Future<ui.Image?> decode(String id) {
    final ready = _decoded[id];
    if (ready != null) return SynchronousFuture(ready);
    return _decoding[id] ??= () async {
      final bytes = _png[id];
      ui.Image? image;
      if (bytes != null) {
        try {
          image = await decodeImage(bytes);
        } on Object catch (e) {
          debugPrint('Görsel çözülemedi ($id): $e');
        }
      }
      _decoding.remove(id);
      if (image == null) return null;
      if (_disposed) {
        image.dispose();
        return null;
      }
      _decoded[id] = image;
      _version++;
      notifyListeners();
      return image;
    }();
  }

  /// Yazıcı için: [ids] görsellerinin PNG'si ve çözülmüş pikselleri.
  /// Çözülemeyen görsel atlanır (yazıcı öğeyi atlanan olarak sayar).
  Future<Map<String, InkenImage>> forWriting(Set<String> ids) async {
    final out = <String, InkenImage>{};
    for (final id in ids) {
      final png = _png[id];
      final image = await decode(id);
      if (png == null || image == null) continue;
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) continue;
      out[id] = InkenImage(
        png: png,
        width: image.width,
        height: image.height,
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in _decoded.values) {
      image.dispose();
    }
    _decoded.clear();
    super.dispose();
  }
}

Future<ui.Image> decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Belgeye girecek hâle getirilmiş görsel.
typedef PreparedImage = ({String id, Uint8List png, ui.Image image});

/// Panodan ya da dosyadan gelen görseli (PNG, JPEG, BMP, GIF, WebP…)
/// belgeye hazırlar: uzun kenarı [maxSide]'ı aşıyorsa oranı korunarak
/// küçültülür, PNG'ye çevrilir. Görsel değilse ya da çözülemezse `null`.
Future<PreparedImage?> prepareImage(
  Uint8List raw, {
  int maxSide = maxImageSide,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(raw);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final w = descriptor.width, h = descriptor.height;
    if (w <= 0 || h <= 0) return null;
    final s = math.min(1.0, maxSide / math.max(w, h));
    final codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (w * s).round()),
      targetHeight: math.max(1, (h * s).round()),
    );
    final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      image.dispose();
      return null;
    }
    final png = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return (id: imageAssetId(png), png: png, image: image);
  } on Object catch (e) {
    debugPrint('Görsel hazırlanamadı: $e');
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
