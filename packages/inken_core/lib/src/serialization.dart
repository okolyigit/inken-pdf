import 'dart:convert';

import 'inken_core_base.dart';
import 'model.dart';

/// Dosya, bu uygulamanın bildiğinden daha yeni bir formatla yazılmış.
class UnsupportedFormatVersion implements Exception {
  const UnsupportedFormatVersion(this.found);
  final int found;

  @override
  String toString() =>
      'inken.json sürümü $found; bu uygulama en fazla '
      '$currentFormatVersion sürümünü açabilir.';
}

typedef _Migration = Map<String, dynamic> Function(Map<String, dynamic> json);

/// Sürüm N → N+1 dönüştürücüleri. Format değişince buraya eklenir.
const Map<int, _Migration> _migrations = {
  1: _v1ToV2,
  2: _v2ToV3,
  3: _v3ToV4,
};

/// 2: görsel öğesi (`image`) eklendi. Eski veride değişecek bir şey yok;
/// sürüm, görselli dosyayı eski uygulamanın açıp görselleri sessizce
/// silmemesi için arttı.
Map<String, dynamic> _v1ToV2(Map<String, dynamic> json) => json;

/// 3: koordinat düzlemi şekli (`kind: coordinate`) eklendi. Eski veride
/// değişecek bir şey yok; sürüm, eski uygulama böyle bir dosyayı "bozuk"
/// yerine "daha yeni sürümle yazılmış" diye geri çevirsin diye arttı.
Map<String, dynamic> _v2ToV3(Map<String, dynamic> json) => json;

/// 4: görselde opaklık, döndürme ve kırpma (`opacity`, `rotation`,
/// `cropLeft`…`cropBottom`). Eksik alanlar varsayılanı alır (opak,
/// döndürülmemiş, kırpılmamış); eski veride değişecek bir şey yok. Sürüm,
/// eski uygulama kırpılmış görseli kırpılmamış göstermesin diye arttı.
Map<String, dynamic> _v3ToV4(Map<String, dynamic> json) => json;

String encodeInkenDocument(InkenDocument document) =>
    jsonEncode(document.toJson());

/// `inken.json` metnini okur; eski sürümleri güncel şemaya dönüştürür.
///
/// Geçersiz içerikte [FormatException], daha yeni sürümde
/// [UnsupportedFormatVersion] fırlatır.
InkenDocument decodeInkenDocument(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('inken.json bir nesne olmalı');
  }
  var json = decoded;
  final Object? version = json['formatVersion'];
  if (version is! int || version < 1) {
    throw const FormatException('formatVersion eksik veya geçersiz');
  }
  if (version > currentFormatVersion) {
    throw UnsupportedFormatVersion(version);
  }
  for (var v = version; v < currentFormatVersion; v++) {
    final migrate = _migrations[v];
    if (migrate == null) {
      throw FormatException('Sürüm $v için dönüştürücü yok');
    }
    json = migrate(json)..['formatVersion'] = v + 1;
  }
  try {
    return InkenDocument.fromJson(json);
  } on TypeError catch (e) {
    throw FormatException('inken.json şemaya uymuyor: $e');
  } on ArgumentError catch (e) {
    throw FormatException('inken.json şemaya uymuyor: $e');
  }
}
