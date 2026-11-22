import 'dart:math';

import 'package:crypto/crypto.dart';

/// `inken.json` format sürümü. Şema değişirse artırılır ve
/// `serialization.dart` içine bir dönüştürücü eklenir.
const int currentFormatVersion = 4;

/// PDF açıklamalarının `/NM` alanındaki önek: `inken:<id>`.
const String inkenAnnotationPrefix = 'inken:';

/// PDF'e gömülen düzenlenebilir katmanın dosya adı.
const String inkenAttachmentName = 'inken.json';

/// Görsel eklerinin adı: `inken-image-<imageId>.png`.
const String imageAttachmentPrefix = 'inken-image-';
const String imageAttachmentSuffix = '.png';

String imageAttachmentName(String imageId) =>
    '$imageAttachmentPrefix$imageId$imageAttachmentSuffix';

/// Ek adından görsel kimliği; görsel eki değilse `null`.
String? imageIdOfAttachment(String name) =>
    name.startsWith(imageAttachmentPrefix) &&
        name.endsWith(imageAttachmentSuffix) &&
        name.length >
            imageAttachmentPrefix.length + imageAttachmentSuffix.length
    ? name.substring(
        imageAttachmentPrefix.length,
        name.length - imageAttachmentSuffix.length,
      )
    : null;

final Random _random = Random.secure();

/// Öğeler için benzersiz kimlik (128 bit, onaltılık).
String newItemId() {
  final sb = StringBuffer();
  for (var i = 0; i < 16; i++) {
    sb.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Görselin kimliği: PNG baytlarının SHA-256 özetinin ilk 16 onaltılık
/// hanesi. İçerikten türediği için aynı görsel iki kez yapıştırılırsa
/// dosyada bir kez saklanır.
String imageAssetId(List<int> png) =>
    sha256.convert(png).toString().substring(0, 16);
