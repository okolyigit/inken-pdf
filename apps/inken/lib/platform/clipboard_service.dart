import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panodaki görseli okur ve panoya görsel koyar. Flutter'ın `Clipboard`'ı
/// yalnızca metinle çalıştığından `inken/clipboard` kanalı: Linux'ta GTK
/// panosu (PNG'ye çevrilir), Windows'ta "PNG" biçimi ya da CF_DIB (BMP),
/// Android'de panodaki `content://` görseli.
abstract class ClipboardService {
  /// Görselin baytları (PNG, BMP, JPEG…); panoda görsel yoksa `null`.
  Future<Uint8List?> readImage();

  /// [png]'yi panoya koyar; bu platformda yapılamıyorsa `false`.
  Future<bool> writeImage(Uint8List png);
}

class PlatformClipboardService implements ClipboardService {
  static const _channel = MethodChannel('inken/clipboard');

  @override
  Future<Uint8List?> readImage() async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('readImage');
      return bytes == null || bytes.isEmpty ? null : bytes;
    } on MissingPluginException {
      return null; // bu platformda kanal yok
    }
  }

  @override
  Future<bool> writeImage(Uint8List png) async {
    final args = <String, Object?>{'png': png};
    // Windows'ta CF_DIB de konur (PNG biçimini tanımayan uygulamalar için);
    // DIB'i PNG'den çözmek yerinde WIC gerektirirdi, pikseller burada çıkar.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final (:bgra, :width, :height) = await _decodeBgra(png);
      args.addAll({'bgra': bgra, 'width': width, 'height': height});
    }
    try {
      return await _channel.invokeMethod<bool>('writeImage', args) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<({Uint8List bgra, int width, int height})> _decodeBgra(
    Uint8List png,
  ) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) throw StateError('Görsel çözülemedi');
      final px = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final bgra = Uint8List(px.length);
      for (var i = 0; i + 3 < px.length; i += 4) {
        bgra[i] = px[i + 2];
        bgra[i + 1] = px[i + 1];
        bgra[i + 2] = px[i];
        bgra[i + 3] = px[i + 3];
      }
      return (bgra: bgra, width: image.width, height: image.height);
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
}

final clipboardServiceProvider = Provider<ClipboardService>(
  (ref) => PlatformClipboardService(),
);
