import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// Yazdırmanın sonucu.
enum PrintOutcome {
  /// Yazıcıya gönderildi (Linux: CUPS işi kabul etti; Windows: yazdırma
  /// kuyruğu belgeyi aldı).
  printed,

  /// Kullanıcı yazdırma penceresinden vazgeçti.
  cancelled,

  /// Sistemin yazdırma servisi açıldı; gerisi sistemde (Android).
  started,
}

/// Yazıcı PDF kabul etmiyor (Linux; çok eski yazıcı sürücüleri).
class PrinterUnsupported implements Exception {
  const PrinterUnsupported();
}

/// Çizimleri gömülü PDF'i ([path]) sistemin yazdırma yoluna verir:
/// Linux'ta GTK yazdırma penceresi → CUPS, Android'de PrintManager.
/// Windows'ta yerleşik PDF yazdırma yok (Edge gibi varsayılan uygulamalar
/// "yazdır" komutunu tanımaz): sistemin yazdırma penceresi açılır, sayfalar
/// PDFium ile görüntüye çevrilip GDI ile yazıcıya gönderilir. `printing`
/// paketi kullanılmaz: kendi PDFium kopyasını getirir, pdfrx'inkiyle aynı
/// süreçte çakışır.
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

  /// Windows'ta sayfa görüntülerinin en yüksek çözünürlüğü: metin keskin,
  /// sayfa başına bellek makul (A4 ≈ 35 MB).
  static const maxWindowsDpi = 300;

  @override
  Future<PrintOutcome> printPdf(String path, {required String title}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _printWindows(path, title);
    }
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

  Future<PrintOutcome> _printWindows(String path, String title) async {
    final pdf = await PdfPrintRasterizer.open(await File(path).readAsBytes());
    try {
      final job = await _channel.invokeMapMethod<String, Object?>('begin', {
        'title': title,
        'pageCount': pdf.pageCount,
      });
      if (job == null) return PrintOutcome.cancelled;
      final pages = (job['pages']! as List).cast<int>();
      final dpi = job['dpi']! as int;
      final scale = math.min(1.0, maxWindowsDpi / math.max(1, dpi));
      final width = math.max(1, ((job['width']! as int) * scale).round());
      final height = math.max(1, ((job['height']! as int) * scale).round());
      try {
        for (final index in pages) {
          final page = await pdf.render(index, width, height);
          await _channel.invokeMethod<void>('page', {
            'bgra': page.bgra,
            'width': page.width,
            'height': page.height,
          });
        }
        await _channel.invokeMethod<void>('end');
      } on Object {
        await _channel.invokeMethod<void>('abort');
        rethrow;
      }
      return PrintOutcome.printed;
    } finally {
      await pdf.dispose();
    }
  }
}

final printServiceProvider = Provider<PrintService>(
  (ref) => PlatformPrintService(),
);
