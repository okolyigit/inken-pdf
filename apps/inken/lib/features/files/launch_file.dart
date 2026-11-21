import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_document.dart' show displayNameOf;
import 'recent_documents.dart';

/// Dışarıdan açılması istenen PDF: masaüstünde komut satırı (dosya
/// yöneticisinde "Birlikte aç", `inken belge.pdf`), Android'de başka bir
/// uygulamanın "Birlikte aç"ı (`ACTION_VIEW`, `content://` URI).
///
/// Uygulama bir dosyayla başlatıldıysa açılış ekranı onu [take] ile bir kez
/// alır. Android'de uygulama açıkken gelen dosyalar [arrivals]'ta duyurulur;
/// dinleyen ekran yine [take] ile alır.
class LaunchFile {
  /// Masaüstü (ve testler): [path] varsa başlangıç dosyası.
  LaunchFile(String? path, {Stream<void>? arrivals})
    : _pending = path == null
          ? null
          : RecentDocument(
              location: path,
              name: displayNameOf(path, fallback: path),
              openedAt: DateTime.now(),
            ),
      _channel = null,
      arrivals = arrivals ?? const Stream.empty();

  /// Android: dosyayı `inken/documents` kanalı verir.
  LaunchFile._android(this._channel, this.arrivals) : _pending = null;

  RecentDocument? _pending;
  final MethodChannel? _channel;

  /// Uygulama açıkken yeni bir dosya geldi (Android).
  final Stream<void> arrivals;

  /// Bekleyen dosyayı verir ve unutur (ikinci kez açılmasın); yoksa `null`.
  Future<RecentDocument?> take() async {
    final channel = _channel;
    if (channel == null) {
      final p = _pending;
      _pending = null;
      return p;
    }
    final r = await channel.invokeMapMethod<String, Object?>('takeIncoming');
    if (r == null) return null;
    return RecentDocument(
      location: r['uri']! as String,
      name: r['name']! as String,
      openedAt: DateTime.now(),
      writable: r['writable']! as bool,
    );
  }

  /// Platforma göre kurar: Android'de kanal, masaüstünde [args].
  static LaunchFile forPlatform(List<String> args) {
    if (!Platform.isAndroid) return fromArgs(args);
    const channel = MethodChannel('inken/documents');
    final arrivals = StreamController<void>.broadcast();
    channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingAvailable') arrivals.add(null);
    });
    return LaunchFile._android(channel, arrivals.stream);
  }

  /// Komut satırı argümanlarından ilk PDF: düz yol ya da `file://` URI.
  /// Seçenekler (`-` ile başlayan) atlanır; dosya yoksa `null`.
  static LaunchFile fromArgs(List<String> args) {
    for (final a in args) {
      if (a.startsWith('-')) continue;
      final path = a.startsWith('file://') ? Uri.parse(a).toFilePath() : a;
      final file = File(path);
      if (file.existsSync()) return LaunchFile(file.absolute.path);
    }
    return LaunchFile(null);
  }
}

/// `main` platformdan kurulanla değiştirir.
final launchFileProvider = Provider<LaunchFile>((ref) => LaunchFile(null));
