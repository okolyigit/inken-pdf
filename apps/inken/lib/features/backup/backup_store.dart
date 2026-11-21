import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:path_provider/path_provider.dart';

import '../files/document_io.dart';
import '../files/open_document.dart';

/// Otomatik yedeklerin klasörü: dosya başına bir JSON (yalnızca model).
/// Görseller `images/<kimlik>.png` olarak ayrı durur; kimlik içerikten
/// türediği için yedekler arasında paylaşılır, bir kez yazılır.
///
/// Yedek, dosyanın yoluna göre adlandırılır; aynı dosyanın yeni yedeği
/// eskisinin üzerine yazılır.
class BackupStore {
  BackupStore({Future<Directory> Function()? locate})
    : _locate = locate ?? _defaultDirectory;

  /// Belirli bir klasörde (testler).
  BackupStore.at(Directory directory) : _locate = (() async => directory);

  final Future<Directory> Function() _locate;
  Directory? _directory;

  /// Bu çalıştırmada kullanıcıya sorulmuş yedekler (aynı soru yinelenmesin).
  final Set<String> offered = {};

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/backups');

  Future<Directory> _dir() async =>
      _directory ??= await (await _locate()).create(recursive: true);

  Future<File> _fileFor(String sourcePath) async =>
      File('${(await _dir()).path}/${backupKey(sourcePath)}.json');

  Future<Directory> _imageDir() async =>
      Directory('${(await _dir()).path}/images').create(recursive: true);

  /// Yedeği yazar. [images], modelde kullanılan görsellerin baytlarıdır;
  /// klasörde olmayanlar yazılır (önce görseller: yedek yarım kalırsa
  /// görselsiz model kalmasın).
  Future<void> write(
    InkenBackup backup, {
    Map<String, Uint8List> images = const {},
  }) async {
    final used = referencedImageIds(backup.document);
    if (used.isNotEmpty) {
      final dir = await _imageDir();
      for (final id in used) {
        final bytes = images[id];
        final file = File('${dir.path}/$id.png');
        if (bytes == null || file.existsSync()) continue;
        await writeFileAtomically(file.path, bytes);
      }
    }
    final file = await _fileFor(backup.sourcePath);
    await writeFileAtomically(file.path, utf8.encode(backup.encode()));
  }

  /// Yedeğin görselleri; bulunamayan atlanır (o öğe yer tutucu olarak
  /// görünür, kaydederken atlanır).
  Future<Map<String, Uint8List>> imagesFor(InkenBackup backup) async {
    final used = referencedImageIds(backup.document);
    if (used.isEmpty) return const {};
    final dir = await _imageDir();
    final out = <String, Uint8List>{};
    for (final id in used) {
      final file = File('${dir.path}/$id.png');
      if (file.existsSync()) out[id] = await file.readAsBytes();
    }
    return out;
  }

  Future<void> delete(String sourcePath) async {
    final file = await _fileFor(sourcePath);
    if (file.existsSync()) await file.delete();
  }

  /// Okunabilen yedekler, en yenisi önce. Okunamayanlar kurtarılamayacağı
  /// için silinir.
  Future<List<InkenBackup>> list() async {
    final out = <InkenBackup>[];
    await for (final entity in (await _dir()).list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        out.add(InkenBackup.decode(await entity.readAsString()));
      } on FormatException {
        await entity.delete();
      }
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    await _pruneImages(out);
    return out;
  }

  /// Hiçbir yedeğin kullanmadığı görselleri siler.
  Future<void> _pruneImages(List<InkenBackup> backups) async {
    final dir = Directory('${(await _dir()).path}/images');
    if (!dir.existsSync()) return;
    final used = {for (final b in backups) ...referencedImageIds(b.document)};
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || !name.endsWith('.png')) continue;
      if (used.contains(name.substring(0, name.length - 4))) continue;
      try {
        await entity.delete();
      } on FileSystemException catch (e) {
        debugPrint('Yedek görseli silinemedi: $e');
      }
    }
  }
}

/// Dosya yolundan yedek dosyası adı (FNV-1a 64 bit, onaltılık).
String backupKey(String sourcePath) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(sourcePath)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

final backupStoreProvider = Provider<BackupStore>((ref) => BackupStore());

/// Otomatik yedek aralığı (testlerde kısaltılır).
final backupIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);
