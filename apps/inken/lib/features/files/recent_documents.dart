import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:path_provider/path_provider.dart';

import '../backup/backup_store.dart' show backupKey;
import 'document_io.dart';

/// Son açılan bir belge.
@immutable
class RecentDocument {
  const RecentDocument({
    required this.location,
    required this.name,
    required this.openedAt,
    this.writable = true,
    this.pageCount,
  });

  /// Masaüstünde dosya yolu, Android'de `content://` URI (izni kalıcı).
  final String location;
  final String name;
  final DateTime openedAt;
  final bool writable;
  final int? pageCount;

  Map<String, Object?> toJson() => {
    'location': location,
    'name': name,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'writable': writable,
    'pageCount': ?pageCount,
  };

  static RecentDocument? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final location = json['location'], name = json['name'];
    final at = DateTime.tryParse('${json['openedAt']}');
    if (location is! String || name is! String || at == null) return null;
    return RecentDocument(
      location: location,
      name: name,
      openedAt: at,
      writable: json['writable'] != false,
      pageCount: json['pageCount'] is int ? json['pageCount']! as int : null,
    );
  }
}

/// Son belgelerin listesi (`recent.json`) ve ilk sayfalarının küçük
/// resimleri (`thumbs/<anahtar>.png`), uygulama destek klasöründe.
class RecentStore {
  RecentStore._(this._dir, this.initial);

  /// Dosyasız (testler ve varsayılan).
  RecentStore.memory([List<RecentDocument>? initial])
    : _dir = null,
      initial = initial ?? const [];

  static Future<RecentStore> load({Directory? directory}) async {
    final dir = directory ?? await getApplicationSupportDirectory();
    final file = File('${dir.path}/recent.json');
    var list = <RecentDocument>[];
    try {
      if (file.existsSync()) {
        final json = jsonDecode(await file.readAsString());
        if (json is List) {
          list = [for (final e in json) ?RecentDocument.fromJson(e)];
        }
      }
    } on Object catch (e) {
      debugPrint('Son belgeler okunamadı: $e');
    }
    return RecentStore._(dir, list);
  }

  final Directory? _dir;

  /// Açılışta okunan liste.
  final List<RecentDocument> initial;

  Future<void> _writing = Future.value();

  /// Küçük resmin dosyası; dosyasız depoda `null`.
  File? thumbnailFile(String location) {
    final dir = _dir;
    if (dir == null) return null;
    return File('${dir.path}/thumbs/${backupKey(location)}.png');
  }

  void _queue(Future<void> Function() job) {
    _writing = _writing.then((_) async {
      try {
        await job();
      } on Object catch (e) {
        debugPrint('Son belgeler yazılamadı: $e');
      }
    });
  }

  void save(List<RecentDocument> list) {
    final dir = _dir;
    if (dir == null) return;
    final text = const JsonEncoder.withIndent('  ')
        .convert([for (final r in list) r.toJson()]);
    _queue(() async {
      await dir.create(recursive: true);
      await writeFileAtomically('${dir.path}/recent.json', utf8.encode(text));
    });
  }

  void saveThumbnail(String location, Uint8List png) {
    final file = thumbnailFile(location);
    if (file == null) return;
    _queue(() async {
      await file.parent.create(recursive: true);
      await writeFileAtomically(file.path, png);
    });
  }

  void deleteThumbnail(String location) {
    final file = thumbnailFile(location);
    if (file == null) return;
    _queue(() async {
      if (file.existsSync()) await file.delete();
    });
  }

  /// Bekleyen yazmalar bitene kadar bekler (testler).
  Future<void> flush() => _writing;
}

/// `main` açılışta okunan depoyla değiştirir.
final recentStoreProvider = Provider<RecentStore>(
  (ref) => RecentStore.memory(),
);

/// Küçük resim üretici (testlerde değiştirilir: pdfrx gerektirir).
final thumbnailerProvider = Provider<Future<Uint8List?> Function(Uint8List)>(
  (ref) => renderThumbnail,
);

/// Son belgeler, en yenisi önce; en fazla [limit] tane.
class RecentDocumentsNotifier extends Notifier<List<RecentDocument>> {
  static const limit = 12;

  /// Küçük resmi yenilenen belgeler için sayaç (görüntü önbelleğini aşmak).
  final Map<String, int> thumbnailVersions = {};

  RecentStore get _store => ref.read(recentStoreProvider);

  @override
  List<RecentDocument> build() => _store.initial;

  /// Belgeyi listenin başına koyar ve küçük resmini [bytes]'tan (dosyanın
  /// kendisi; çizimler dahil) yeniler.
  Future<void> remember({
    required String location,
    required String name,
    required Uint8List bytes,
    bool writable = true,
    int? pageCount,
  }) async {
    final all = [
      RecentDocument(
        location: location,
        name: name,
        openedAt: DateTime.now(),
        writable: writable,
        pageCount: pageCount,
      ),
      for (final r in state)
        if (r.location != location) r,
    ];
    state = all.take(limit).toList();
    for (final r in all.skip(limit)) {
      _store.deleteThumbnail(r.location);
    }
    _store.save(state);
    final png = await ref.read(thumbnailerProvider)(bytes);
    if (png == null) return;
    _store.saveThumbnail(location, png);
    await _store.flush();
    // Aynı yoldaki eski resim önbellekte kalmasın.
    final file = _store.thumbnailFile(location);
    if (file != null) await FileImage(file).evict();
    thumbnailVersions[location] = (thumbnailVersions[location] ?? 0) + 1;
    // Kart yeni resmi göstersin.
    if (ref.mounted) state = [...state];
  }

  void remove(String location) {
    state = [
      for (final r in state)
        if (r.location != location) r,
    ];
    _store.save(state);
    _store.deleteThumbnail(location);
  }
}

final recentDocumentsProvider =
    NotifierProvider<RecentDocumentsNotifier, List<RecentDocument>>(
      RecentDocumentsNotifier.new,
    );
