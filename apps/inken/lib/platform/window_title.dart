import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _windowChannel = MethodChannel('inken/window');

/// Masaüstünde pencere başlığı ("ders.pdf – Inken PDF"). Linux / Windows
/// gömücüsündeki `inken/window` kanalıyla; başka platformda bir şey yapmaz.
abstract final class WindowTitle {
  static String? _last;

  static void set(String title) {
    if (title == _last) return;
    _last = title;
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      return;
    }
    _windowChannel.invokeMethod<void>('setTitle', title).catchError((Object e) {
      // Test ortamında ya da eski yerelde kanal yok: başlık önemli değil.
      debugPrint('Pencere başlığı ayarlanamadı: $e');
    });
  }
}

/// Uygulamayı tam ekrana alır / çıkarır: masaüstünde pencere, Android'de
/// sistem çubukları gizlenir.
abstract final class AppFullscreen {
  static Future<void> set(bool on) async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.linux || TargetPlatform.windows:
        try {
          await _windowChannel.invokeMethod<void>('setFullscreen', on);
        } on Object catch (e) {
          debugPrint('Tam ekran ayarlanamadı: $e');
        }
      case TargetPlatform.android || TargetPlatform.iOS:
        await SystemChrome.setEnabledSystemUIMode(
          on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      default:
        break;
    }
  }
}
