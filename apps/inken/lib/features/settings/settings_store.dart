import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../files/document_io.dart';

/// Kullanıcı ayarları (tema, araç kutusu yönü…): uygulama destek klasöründe
/// `settings.json`. Açılışta bir kez okunur ([load]); her değişiklik
/// arka planda dosyaya yazılır (geçici dosya → `rename`).
///
/// Okunamayan ya da bozuk dosya yok sayılır: ayarlar varsayılana döner,
/// uygulama açılmaya devam eder.
class SettingsStore {
  SettingsStore._(this._file, this._values);

  /// Dosyasız (testler ve varsayılan): yalnızca bellekte.
  SettingsStore.memory([Map<String, Object?>? values])
    : _file = null,
      _values = {...?values};

  static Future<SettingsStore> load({Directory? directory}) async {
    final dir = directory ?? await getApplicationSupportDirectory();
    final file = File('${dir.path}/settings.json');
    var values = <String, Object?>{};
    try {
      if (file.existsSync()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map<String, Object?>) values = json;
      }
    } on Object catch (e) {
      debugPrint('Ayarlar okunamadı: $e');
    }
    return SettingsStore._(file, values);
  }

  final File? _file;
  final Map<String, Object?> _values;
  Future<void> _writing = Future.value();

  /// [key]'in değeri; yoksa ya da türü uymuyorsa `null`.
  T? get<T>(String key) {
    final v = _values[key];
    return v is T ? v : null;
  }

  /// Bir enum değeri, adıyla saklanmış; yoksa [fallback].
  T getEnum<T extends Enum>(String key, List<T> values, T fallback) {
    final name = get<String>(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  void put(String key, Object? value) {
    if (_values[key] == value) return;
    _values[key] = value;
    final file = _file;
    if (file == null) return;
    final text = const JsonEncoder.withIndent('  ').convert(_values);
    // Yazmalar sırayla; biri hata verirse sonrakiler yine denenir.
    _writing = _writing.then((_) async {
      try {
        await file.parent.create(recursive: true);
        await writeFileAtomically(file.path, utf8.encode(text));
      } on Object catch (e) {
        debugPrint('Ayarlar yazılamadı: $e');
      }
    });
  }

  /// Bekleyen yazma bitene kadar bekler (testler).
  Future<void> flush() => _writing;
}

/// `main` açılışta okunan depoyla değiştirir.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore.memory(),
);
