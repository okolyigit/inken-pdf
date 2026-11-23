import 'dart:convert';

import 'model.dart';
import 'serialization.dart';

/// Otomatik yedek: kaydedilmemiş çizimler ve ait oldukları dosya.
///
/// Yalnızca model saklanır; PDF diskte zaten durur. Kurtarırken dosyanın
/// yedekten sonra değişip değişmediği [sourceLength] ve [sourceModified] ile
/// anlaşılır. Bu, `inken.json`'dan ayrı, uygulamanın kendi iç formatıdır.
class InkenBackup {
  const InkenBackup({
    required this.sourcePath,
    this.sourceName,
    required this.sourceLength,
    required this.sourceModified,
    required this.savedAt,
    required this.document,
    this.sourcePageCount,
  });

  /// Çizimlerin ait olduğu dosya: yol ya da (Android) `content://` URI.
  final String sourcePath;

  /// Dosyanın kullanıcıya gösterilen adı (URI'den çıkarılamaz).
  final String? sourceName;

  /// Yedek alınırken dosyanın boyutu (bayt).
  final int sourceLength;

  /// Yedek alınırken dosyanın değiştirilme zamanı.
  final DateTime sourceModified;

  /// Yedeğin alındığı an.
  final DateTime savedAt;

  /// Kaydedilmemiş hali dahil tüm model.
  final InkenDocument document;

  /// Yedek alınırken dosyanın sayfa sayısı. Sayfa silme gelmeden önceki
  /// yedeklerde yoktur (`null`).
  final int? sourcePageCount;

  /// Model [pageCount] sayfalık dosyaya uygulanabilir mi? Sayfa sayısı
  /// biliniyorsa silinmiş sayfalara izin verilir, bilinmiyorsa (eski yedek)
  /// kaynak sayfalar eksiksiz olmalıdır.
  bool fitsFile(int pageCount) {
    final known = sourcePageCount;
    if (known == null) return fitsSourcePages(document, pageCount);
    return known == pageCount &&
        fitsSourcePages(document, pageCount, allowRemoved: true);
  }

  static const int version = 1;

  String encode() => jsonEncode({
    'backupVersion': version,
    'sourcePath': sourcePath,
    'sourceName': ?sourceName,
    'sourceLength': sourceLength,
    'sourceModified': sourceModified.toUtc().toIso8601String(),
    'savedAt': savedAt.toUtc().toIso8601String(),
    'sourcePageCount': ?sourcePageCount,
    // Model, inken.json ile aynı biçimde (sürüm dönüştürücüleri geçerli).
    'document': encodeInkenDocument(document),
  });

  /// Geçersiz ya da bilinmeyen sürümde [FormatException] fırlatır.
  static InkenBackup decode(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      if (json['backupVersion'] != version) {
        throw FormatException(
          'Yedek sürümü desteklenmiyor: '
          '${json['backupVersion']}',
        );
      }
      return InkenBackup(
        sourcePath: json['sourcePath'] as String,
        sourceName: json['sourceName'] as String?,
        sourceLength: json['sourceLength'] as int,
        sourceModified: DateTime.parse(json['sourceModified'] as String),
        savedAt: DateTime.parse(json['savedAt'] as String),
        document: decodeInkenDocument(json['document'] as String),
        sourcePageCount: json['sourcePageCount'] as int?,
      );
    } on TypeError catch (e) {
      throw FormatException('Yedek okunamıyor: $e');
    } on UnsupportedFormatVersion catch (e) {
      throw FormatException('Yedek okunamıyor: $e');
    }
  }

  /// Dosya yedekten sonra değişmemiş mi?
  bool matchesSource({required int length, required DateTime modified}) =>
      length == sourceLength &&
      modified.millisecondsSinceEpoch == sourceModified.millisecondsSinceEpoch;
}

/// [document]'in sayfaları [pageCount] sayfalık bir dosyaya uyuyor mu?
///
/// Dosyadan gelen sayfalar (`sourceIndex` dolu) sırayla 0…[pageCount]-1
/// olmalı; araya eklenen sayfalar sayılmaz. [allowRemoved] ise (kaydedilmemiş
/// düzenleme, yedek) sayfa eksik olabilir (silinmiş) ve sıra değişmiş
/// olabilir (taşınmış), ama her dosya sayfası en çok bir kez ve dosyada
/// olmalıdır. Uymayan modeli o dosyaya uygulamak çizimleri yanlış
/// sayfalara taşırdı.
bool fitsSourcePages(
  InkenDocument document,
  int pageCount, {
  bool allowRemoved = false,
}) {
  if (allowRemoved) {
    final seen = <int>{};
    for (final page in document.pages) {
      final index = page.sourceIndex;
      if (index == null) continue;
      if (index < 0 || index >= pageCount || !seen.add(index)) return false;
    }
    return true;
  }
  var next = 0;
  for (final page in document.pages) {
    final index = page.sourceIndex;
    if (index == null) continue;
    if (index != next) return false;
    next = index + 1;
  }
  return next == pageCount;
}
