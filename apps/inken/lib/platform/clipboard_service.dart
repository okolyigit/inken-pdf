import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panodaki görseli okur. Flutter'ın `Clipboard`'ı yalnızca metin
/// okuduğundan `inken/clipboard` kanalı: Linux'ta GTK panosu (PNG'ye
/// çevrilir), Windows'ta "PNG" biçimi ya da CF_DIB (BMP), Android'de
/// panodaki `content://` görseli.
abstract class ClipboardService {
  /// Görselin baytları (PNG, BMP, JPEG…); panoda görsel yoksa `null`.
  Future<Uint8List?> readImage();
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
}

final clipboardServiceProvider = Provider<ClipboardService>(
  (ref) => PlatformClipboardService(),
);
