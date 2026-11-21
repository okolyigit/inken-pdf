import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yazdırmanın sonucu.
enum PrintOutcome {
  /// Yazıcıya gönderildi (Linux: CUPS işi kabul etti).
  printed,

  /// Kullanıcı yazdırma penceresinden vazgeçti.
  cancelled,

  /// Sistemin yazdırma servisi açıldı; gerisi sistemde (Android).
  started,

  /// Dosya varsayılan PDF uygulamasının "yazdır" komutuna verildi (Windows).
  handedOff,
}

/// Yazıcı PDF kabul etmiyor (Linux; çok eski yazıcı sürücüleri).
class PrinterUnsupported implements Exception {
  const PrinterUnsupported();
}

/// Çizimleri gömülü PDF'i ([path]) sistemin yazdırma yoluna verir:
/// Linux'ta GTK yazdırma penceresi → CUPS, Android'de PrintManager,
/// Windows'ta varsayılan PDF uygulaması. `printing` paketi kullanılmaz:
/// kendi PDFium kopyasını getirir, pdfrx'inkiyle aynı süreçte çakışır.
abstract class PrintService {
  /// Bu platformda yazdırılabilir mi?
  bool get supported;

  Future<PrintOutcome> printPdf(String path, {required String title});
}

class PlatformPrintService implements PrintService {
  static const _channel = MethodChannel('inken/print');

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<PrintOutcome> printPdf(String path, {required String title}) async {
    try {
      final r = await _channel.invokeMethod<String>('print', {
        'path': path,
        'title': title,
      });
      return PrintOutcome.values.byName(r ?? 'cancelled');
    } on PlatformException catch (e) {
      if (e.code == 'printer_unsupported') throw const PrinterUnsupported();
      rethrow;
    }
  }
}

final printServiceProvider = Provider<PrintService>(
  (ref) => PlatformPrintService(),
);
