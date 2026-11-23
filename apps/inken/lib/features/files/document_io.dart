import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Belgenin yeri: masaüstünde dosya yolu, Android'de `content://` URI
/// (SAF). Uygulamanın geri kalanı yalnızca bu dizgiyi taşır; okuma / yazma
/// [DocumentIo] üzerinden yapılır.
bool isContentUri(String location) => location.startsWith('content://');

/// Seçilen ya da oluşturulan belge.
typedef DocTarget = ({String location, String name});

/// Açılmak üzere seçilen belge.
typedef PickedDocument = ({
  String location,
  String name,
  Uint8List bytes,

  /// Aynı yere geri yazılabilir mi (Android'de sağlayıcı yazma iznini
  /// vermeyebilir).
  bool writable,
});

/// Kaydedilecek dosyanın türü: uzantı ve MIME türü.
enum SaveFormat {
  pdf('pdf', 'application/pdf'),
  png('png', 'image/png'),
  jpeg('jpg', 'image/jpeg'),
  zip('zip', 'application/zip');

  const SaveFormat(this.extension, this.mime);

  final String extension;
  final String mime;

  /// [path] bu türün uzantısıyla bitmiyorsa uzantıyı ekler.
  String withExtension(String path) {
    final lower = path.toLowerCase();
    final ok =
        lower.endsWith('.$extension') ||
        (this == SaveFormat.jpeg && lower.endsWith('.jpeg'));
    return ok ? path : '$path.$extension';
  }
}

/// Boyut ve değiştirilme zamanı (bilinmiyorsa 1970).
typedef DocStat = ({int size, DateTime modified});

/// Dosya seçme, okuma ve yazma; platforma göre dosya sistemi ya da SAF.
abstract class DocumentIo {
  /// PDF seçtirir ve okur; vazgeçilirse `null`.
  Future<PickedDocument?> pickOpen({required String typeLabel});

  /// Kayıt yeri seçtirir; vazgeçilirse `null`. Masaüstünde [near]'ın
  /// klasöründe açılır. Android'de seçilen ad doluysa sistem yeni ad verir
  /// (üzerine yazılmaz). [format]: dosya türü (uzantı ve süzgeç).
  Future<DocTarget?> pickSave({
    required String suggestedName,
    required String typeLabel,
    String? near,
    SaveFormat format = SaveFormat.pdf,
  });

  Future<Uint8List> read(String location);

  /// Masaüstünde geçici dosya → `rename`; SAF'ta yerinde yazma.
  Future<void> write(String location, Uint8List bytes);

  /// Belge yoksa ya da erişilemiyorsa `null`.
  Future<DocStat?> stat(String location);

  /// Görsel dosyası (PNG, JPEG…) seçtirir ve okur; vazgeçilirse `null`.
  Future<Uint8List?> pickImage({required String typeLabel}) async => null;

  /// [location]'ın yanına (aynı klasöre) sormadan dosya yazılabilir mi?
  /// SAF'ta klasör izni olmadığından hayır.
  bool canWriteBeside(String location) => !isContentUri(location);
}

/// Gerçek platform: dosya sistemi ve (Android) `inken/documents` kanalı.
class PlatformDocumentIo extends DocumentIo {
  PlatformDocumentIo({bool? android})
    : _android = android ?? Platform.isAndroid;

  final bool _android;
  static const _channel = MethodChannel('inken/documents');

  XTypeGroup _pdf(String label) => XTypeGroup(
    label: label,
    extensions: const ['pdf'],
    mimeTypes: const ['application/pdf'],
  );

  @override
  Future<PickedDocument?> pickOpen({required String typeLabel}) async {
    if (_android) {
      final r = await _channel.invokeMapMethod<String, Object?>('open');
      if (r == null) return null;
      final copy = File(r['path']! as String);
      try {
        return (
          location: r['uri']! as String,
          name: r['name']! as String,
          bytes: await copy.readAsBytes(),
          writable: r['writable']! as bool,
        );
      } finally {
        await copy.delete();
      }
    }
    final file = await openFile(acceptedTypeGroups: [_pdf(typeLabel)]);
    if (file == null) return null;
    return (
      location: file.path,
      name: file.name,
      bytes: await file.readAsBytes(),
      writable: true,
    );
  }

  /// Görsel yalnızca okunur (geri yazılmaz): her platformda dosya seçici
  /// yeter, SAF kanalı gerekmez.
  @override
  Future<Uint8List?> pickImage({required String typeLabel}) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: typeLabel,
          extensions: imageFileExtensions,
          mimeTypes: const [
            'image/png',
            'image/jpeg',
            'image/gif',
            'image/webp',
            'image/bmp',
          ],
          uniformTypeIdentifiers: const ['public.image'],
        ),
      ],
    );
    return file?.readAsBytes();
  }

  @override
  Future<DocTarget?> pickSave({
    required String suggestedName,
    required String typeLabel,
    String? near,
    SaveFormat format = SaveFormat.pdf,
  }) async {
    if (_android) {
      final r = await _channel.invokeMapMethod<String, Object?>('create', {
        'name': suggestedName,
        'mime': format.mime,
      });
      if (r == null) return null;
      return (location: r['uri']! as String, name: r['name']! as String);
    }
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      initialDirectory: near == null || isContentUri(near)
          ? null
          : File(near).parent.path,
      acceptedTypeGroups: [
        XTypeGroup(
          label: typeLabel,
          extensions: [format.extension, if (format == SaveFormat.jpeg) 'jpeg'],
          mimeTypes: [format.mime],
        ),
      ],
    );
    if (location == null) return null;
    final path = format.withExtension(location.path);
    return (location: path, name: File(path).uri.pathSegments.last);
  }

  @override
  Future<Uint8List> read(String location) async {
    if (!isContentUri(location)) return File(location).readAsBytes();
    final path = await _channel.invokeMethod<String>('read', {'uri': location});
    final copy = File(path!);
    try {
      return await copy.readAsBytes();
    } finally {
      await copy.delete();
    }
  }

  @override
  Future<void> write(String location, Uint8List bytes) async {
    if (!isContentUri(location)) return writeFileAtomically(location, bytes);
    // Bayt dizisi kanaldan geçmez: önce önbelleğe, Kotlin oradan kopyalar.
    final tmp = File(
      '${Directory.systemTemp.path}/inken-write-'
      '${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await _channel.invokeMethod<void>('write', {
        'uri': location,
        'path': tmp.path,
      });
    } finally {
      if (tmp.existsSync()) await tmp.delete();
    }
  }

  @override
  Future<DocStat?> stat(String location) async {
    if (!isContentUri(location)) {
      final s = await File(location).stat();
      if (s.type == FileSystemEntityType.notFound) return null;
      return (size: s.size, modified: s.modified);
    }
    final r = await _channel.invokeMapMethod<String, Object?>('stat', {
      'uri': location,
    });
    if (r == null) return null;
    return (
      size: r['size']! as int,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (r['modified'] as int?) ?? 0,
      ),
    );
  }
}

/// Baytları önce aynı klasörde geçici dosyaya yazar, sonra `rename` ile
/// yerine koyar: yarım kalan kayıt hedef dosyayı bozmaz.
Future<void> writeFileAtomically(String path, Uint8List bytes) async {
  final tmp = File('$path.inken-tmp');
  try {
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(path);
  } on Object {
    if (tmp.existsSync()) await tmp.delete();
    rethrow;
  }
}

final documentIoProvider = Provider<DocumentIo>((ref) => PlatformDocumentIo());

/// Eklenebilen görsel dosyalarının uzantıları.
const imageFileExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

/// [path] eklenebilen bir görsel dosyası mı (uzantıya göre)?
bool isImageFile(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      imageFileExtensions.contains(path.substring(dot + 1).toLowerCase());
}
