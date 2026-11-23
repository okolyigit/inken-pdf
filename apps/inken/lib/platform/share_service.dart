import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Paylaşmanın sonucu.
enum ShareOutcome {
  /// Kullanıcı bir hedef seçti (Android'de bilinirse).
  shared,

  /// Paylaşma penceresi açıldı; sonucu sistem bildirmiyor (Windows,
  /// Android'in bazı sürümleri).
  started,

  /// Dosya e-posta uygulamasında yeni iletiye eklendi (Linux).
  mailed,

  /// E-posta uygulaması yok; dosya, dosya yöneticisinde seçili açıldı
  /// (Linux).
  shown,

  /// Kullanıcı paylaşma penceresini kapattı.
  dismissed,
}

/// Bu sistemde dosya paylaşılamıyor (Windows 10 1809'dan eski).
class ShareUnsupported implements Exception {
  const ShareUnsupported();
}

/// Bir dosyayı sistemin paylaşma yoluna verir: Android'de paylaşma
/// sayfası, Windows'ta paylaşma penceresi (`share_plus`). Linux'ta ortak
/// bir paylaşma penceresi yoktur: dosya varsayılan e-posta uygulamasında
/// yeni iletiye eklenir (`xdg-email`); o da yoksa dosya yöneticisinde
/// gösterilir.
abstract class ShareService {
  bool get supported;

  /// [path]'teki PDF'i paylaşır. [name] başlık / konu olarak kullanılır.
  /// Dosya, paylaşan uygulama okuyana kadar yerinde kalmalıdır.
  Future<ShareOutcome> sharePdf(String path, {required String name});

  /// [paths]'teki dosyaları ([mime] türünde: görsel, zip) paylaşır.
  /// [name] başlık / konu olarak kullanılır.
  Future<ShareOutcome> shareFiles(
    List<String> paths, {
    required String name,
    required String mime,
  });

  /// [text]'i sistemin paylaşma sayfasıyla paylaşır. Yalnızca Android'de
  /// vardır; başka yerde `false` döner (çağıran metni panoya kopyalar).
  Future<bool> shareText(String text, {required String subject});
}

class PlatformShareService implements ShareService {
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<ShareOutcome> sharePdf(String path, {required String name}) =>
      shareFiles([path], name: name, mime: 'application/pdf');

  @override
  Future<ShareOutcome> shareFiles(
    List<String> paths, {
    required String name,
    required String mime,
  }) async {
    if (paths.isEmpty) throw ArgumentError.value(paths, 'paths', 'boş');
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return _linux(paths, name);
    }
    final ShareResult result;
    try {
      result = await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final path in paths)
              XFile(
                path,
                mimeType: mime,
                name: paths.length == 1
                    ? name
                    : File(path).uri.pathSegments.last,
              ),
          ],
          title: name,
          subject: name,
        ),
      );
    } on UnimplementedError {
      throw const ShareUnsupported();
    }
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.started,
    };
  }

  @override
  Future<bool> shareText(String text, {required String subject}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    return true;
  }

  static Future<ShareOutcome> _linux(List<String> paths, String name) async {
    if (await _run('xdg-email', [
      '--subject',
      name,
      for (final p in paths) ...['--attach', p],
    ])) {
      return ShareOutcome.mailed;
    }
    // Dosya yöneticisinde seçili göster (freedesktop FileManager1);
    // desteklemeyen yöneticide klasörü aç.
    final path = paths.first;
    final uri = Uri.file(path).toString();
    if (await _run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.freedesktop.FileManager1',
      '--object-path',
      '/org/freedesktop/FileManager1',
      '--method',
      'org.freedesktop.FileManager1.ShowItems',
      "['$uri']",
      '',
    ])) {
      return ShareOutcome.shown;
    }
    if (await _run('xdg-open', [File(path).parent.path])) {
      return ShareOutcome.shown;
    }
    throw const ShareUnsupported();
  }

  static Future<bool> _run(String command, List<String> args) async {
    try {
      final r = await Process.run(command, args);
      return r.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => PlatformShareService(),
);
