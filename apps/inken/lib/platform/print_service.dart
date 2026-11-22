import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// Yazdırmanın sonucu.
enum PrintOutcome {
  /// Yazıcıya gönderildi (Linux: CUPS işi kabul etti; Windows: yazdırma
  /// kuyruğu belgeyi aldı).
  printed,

  /// Kullanıcı vazgeçti.
  cancelled,

  /// Sistemin yazdırma ekranı açıldı; gerisi sistemde (Android).
  started,
}

/// Yazıcı PDF kabul etmiyor (Linux; çok eski yazıcı sürücüleri).
class PrinterUnsupported implements Exception {
  const PrinterUnsupported();
}

/// Kurulu bir yazıcı.
@immutable
class PrinterInfo {
  const PrinterInfo({required this.name, this.isDefault = false, this.status});

  final String name;
  final bool isDefault;

  /// Sistemin bildirdiği durum ("Hazır", "Kâğıt yok"…); yoksa `null`.
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is PrinterInfo &&
      other.name == name &&
      other.isDefault == isDefault &&
      other.status == status;

  @override
  int get hashCode => Object.hash(name, isDefault, status);
}

/// Inken'in yazdırma penceresinde seçilenler.
@immutable
class PrintRequest {
  const PrintRequest({
    required this.pages,
    this.pageCount,
    this.printer,
    this.copies = 1,
    this.collate = true,
    this.reverse = false,
    this.fit = true,
    this.grayscale = false,
    this.duplex = PrintDuplex.off,
    this.paper = PaperSize.a4,
    this.orientation = PrintOrientation.auto,
  });

  /// Basılacak sayfalar, 0'dan, sırasıyla (kopya ve ters sıra hariç).
  final List<int> pages;

  /// Belgenin toplam sayfa sayısı (bütün sayfalar mı seçildi, anlaşılsın).
  final int? pageCount;

  /// Yazıcının adı; Android'de `null` (sistem seçtirir).
  final String? printer;
  final int copies;
  final bool collate;
  final bool reverse;

  /// Kâğıda sığdır; değilse gerçek boyut.
  final bool fit;
  final bool grayscale;
  final PrintDuplex duplex;
  final PaperSize paper;
  final PrintOrientation orientation;

  /// Yazıcıya gidecek sayfa sırası (kopyalar ve ters sıra dahil).
  List<int> get sequence =>
      printSequence(pages, copies: copies, collate: collate, reverse: reverse);
}

/// Sistemin yazdırma yolu. Windows ve Linux'ta yazıcı ve ayarlar Inken'in
/// penceresinde seçilir, sistemin penceresi açılmaz: Windows'ta sayfalar
/// PDFium ile görüntüye çevrilip GDI ile, Linux'ta PDF doğrudan CUPS'a
/// gönderilir. Android'de sistemin yazdırma ekranı açılır (zorunlu).
/// `printing` paketi kullanılmaz: kendi PDFium kopyasını getirir.
abstract class PrintService {
  /// Bu platformda yazdırılabilir mi?
  bool get supported;

  /// Yazıcı, kopya ve diğer ayarlar Inken'de mi seçilir (Windows, Linux)?
  /// Değilse (Android) sistemin ekranında.
  bool get choosesPrinter;

  /// Yazıcının kendi ayar penceresi açılabilir mi (Windows)?
  bool get hasPrinterProperties;

  /// Kurulu yazıcılar.
  Future<List<PrinterInfo>> printers();

  /// Yazıcının kendi ayar penceresi (kalite, kâğıt türü); seçilenler bu
  /// oturumda o yazıcının sonraki işlerinde kullanılır.
  Future<void> printerProperties(String printer);

  /// [path]'teki PDF'i [request] ile yazdırır.
  Future<PrintOutcome> printPdf(
    String path, {
    required String title,
    required PrintRequest request,
  });
}

class PlatformPrintService implements PrintService {
  static const _channel = MethodChannel('inken/print');

  static bool get _windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  bool get choosesPrinter => supported && !_android;

  @override
  bool get hasPrinterProperties => _windows;

  /// Windows'ta sayfa görüntülerinin en yüksek çözünürlüğü: metin keskin,
  /// sayfa başına bellek makul (A4 ≈ 35 MB).
  static const maxWindowsDpi = 300;

  @override
  Future<List<PrinterInfo>> printers() async {
    if (!choosesPrinter) return const [];
    final list = await _channel.invokeListMethod<Object?>('printers') ?? [];
    return [
      for (final p in list.whereType<Map<Object?, Object?>>())
        if (p['name'] case final String name)
          PrinterInfo(
            name: name,
            isDefault: p['default'] == true,
            status: switch (p['status']) {
              final String s when s.isNotEmpty => s,
              _ => null,
            },
          ),
    ];
  }

  @override
  Future<void> printerProperties(String printer) async {
    if (!hasPrinterProperties) return;
    await _channel.invokeMethod<bool>('properties', {'printer': printer});
  }

  @override
  Future<PrintOutcome> printPdf(
    String path, {
    required String title,
    required PrintRequest request,
  }) async {
    if (request.pages.isEmpty) return PrintOutcome.cancelled;
    if (_windows) return _printWindows(path, title, request);
    if (_android) return _printAndroid(path, title, request);
    // Linux: seçilen sayfalar (sırası ve ters sıra dahil) ayrı PDF'e alınır;
    // kopya ve diğer ayarlar CUPS'a.
    final file = await _selectedPages(path, request);
    try {
      final r = await _channel.invokeMethod<String>('print', {
        'path': file,
        'title': title,
        ..._settings(request),
        'copies': request.copies,
        'collate': request.collate,
        'fit': request.fit,
      });
      return PrintOutcome.values.byName(r ?? 'cancelled');
    } on PlatformException catch (e) {
      if (e.code == 'printer_unsupported') throw const PrinterUnsupported();
      rethrow;
    }
  }

  static Map<String, Object?> _settings(PrintRequest r) => {
    'printer': r.printer,
    'color': !r.grayscale,
    'duplex': r.duplex.name,
    'paper': r.paper.name,
    'paperWidthMm': r.paper.widthMm,
    'paperHeightMm': r.paper.heightMm,
    'orientation': r.orientation.name,
  };

  /// Android: seçilen sayfalar ayrı bir PDF'e alınır, sistemin yazdırma
  /// ekranı onu gösterir; kopya ve yazıcı orada seçilir.
  Future<PrintOutcome> _printAndroid(
    String path,
    String title,
    PrintRequest request,
  ) async {
    final r = await _channel.invokeMethod<String>('print', {
      'path': await _selectedPages(path, request),
      'title': title,
    });
    return PrintOutcome.values.byName(r ?? 'cancelled');
  }

  /// Seçilen sayfaları istenen sırayla (ters sıra dahil) içeren PDF'in
  /// yolu; bütün sayfalar sırasıyla seçiliyse dosyanın kendisi.
  static Future<String> _selectedPages(String path, PrintRequest r) async {
    final pages = r.reverse ? r.pages.reversed.toList() : r.pages;
    final source = File(path);
    final bytes = await source.readAsBytes();
    var whole = true;
    for (final (i, p) in pages.indexed) {
      if (p != i) whole = false;
    }
    if (whole && pages.length == r.pageCount) return path;
    final out = File(
      '${source.parent.path}/secilen-${source.uri.pathSegments.last}',
    );
    await out.writeAsBytes(await extractPages(bytes, pages));
    return out.path;
  }

  Future<PrintOutcome> _printWindows(
    String path,
    String title,
    PrintRequest request,
  ) async {
    final pdf = await PdfPrintRasterizer.open(await File(path).readAsBytes());
    try {
      final job = await _channel.invokeMapMethod<String, Object?>('begin', {
        'title': title,
        ..._settings(request),
      });
      if (job == null) return PrintOutcome.cancelled;
      int at(String key) => (job[key] as int?) ?? 0;
      final dpi = math.max(1, at('dpi'));
      final area = (
        x: at('offsetX').toDouble(),
        y: at('offsetY').toDouble(),
        width: at('width').toDouble(),
        height: at('height').toDouble(),
      );
      final paperW = math.max(at('physicalWidth'), at('width')).toDouble();
      final paperH = math.max(at('physicalHeight'), at('height')).toDouble();
      // Görüntü en çok 300 dpi; yazıcıda hedef boyuta büyütülür.
      final down = math.min(1.0, maxWindowsDpi / dpi);
      try {
        for (final index in request.sequence) {
          if (index < 0 || index >= pdf.pageCount) continue;
          final size = pdf.pageSize(index);
          final place = placeOnPaper(
            pageWidth: size.width,
            pageHeight: size.height,
            paperWidth: paperW,
            paperHeight: paperH,
            unitsPerPt: dpi / 72,
            fit: request.fit,
            orientation: request.orientation,
            area: area,
          );
          final page = await pdf.renderSized(
            index,
            math.max(1, (place.width * down).round()),
            math.max(1, (place.height * down).round()),
            rotate: place.rotate,
            grayscale: request.grayscale,
          );
          await _channel.invokeMethod<void>('page', {
            'bgra': page.bgra,
            'width': page.width,
            'height': page.height,
            // Yazdırılabilir alanın sol üstüne göre, aygıt pikseli.
            'x': (place.x - area.x).round(),
            'y': (place.y - area.y).round(),
            'destWidth': place.width.round(),
            'destHeight': place.height.round(),
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
