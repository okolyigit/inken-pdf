// PDFium ile Inken dosyası yazma / okuma.
//
// Bütün fonksiyonlar senkron ve bayt-girdi → bayt-çıktıdır; uygulamada
// pdfrx'in PDFium worker isolate'inde (`PdfrxEntryFunctions.instance.compute`)
// çalıştırılır, testte doğrudan çağrılır. PDFium iş parçacığı güvenli değildir:
// bu dosyadaki kod başka bir isolate'ten çağrılmamalı.
// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:inken_core/inken_core.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import 'page_transform.dart';

/// Yalnızca testler için: `libpdfium.so` yolu. Uygulamada `null` kalır;
/// PDFium'u pdfrx zaten yüklemiştir.
@visibleForTesting
String? pdfiumModulePath;

PDFium? _pdfium;
PDFium get _p {
  final existing = _pdfium;
  if (existing != null) return existing;
  final p = getPdfium(modulePath: pdfiumModulePath);
  p.FPDF_InitLibrary(); // pdfrx başlattıysa PDFium tarafında etkisiz
  return _pdfium = p;
}

/// Yazıcıya verilen görsel. [png] dosyaya ek olarak gömülür (Inken onu
/// geri okur); [rgba] görünümü üretmek için çözülmüş piksellerdir
/// (satır satır, ön çarpımsız RGBA). Çözme uygulamanın işidir: worker
/// isolate'inde görsel çözücü yok.
@immutable
class InkenImage {
  const InkenImage({
    required this.png,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final Uint8List png;
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Kaydedilmiş Inken dosyası.
typedef InkenWriteResult = ({
  /// Yeni PDF baytları (tam kayıt).
  Uint8List pdf,

  /// Dosyaya gömülen `inken.json`. Sayfa sıraları kaydedilen dosyaya göre
  /// yeniden numaralanmıştır; uygulama modelini bununla günceller.
  String inkenJson,

  /// PDF'e yazılamayan öğe sayısı (metin fontu verilmediyse metinler).
  int skippedItems,
});

/// Açılan bir PDF'in Inken açısından içeriği.
typedef InkenReadResult = ({
  /// Görüntüleyiciye verilecek baytlar: `inken.json` varsa Inken
  /// açıklamaları silinmiş bellek kopyası (çizimleri katman çizer),
  /// yoksa dosyanın kendisi.
  Uint8List displayPdf,

  /// Gömülü `inken.json` metni; düz PDF'te `null`.
  String? inkenJson,
  int pageCount,

  /// Dosya şifreli ya da imzalı: üzerine yazılmamalı, yalnızca kopyaya.
  bool isProtected,

  /// Gömülü görseller (PNG), görsel kimliğine göre.
  Map<String, Uint8List> images,
});

/// [source] PDF'ine [document]'i yazar ve yeni dosyanın baytlarını döner.
///
/// [source], belgenin açıldığı dosyadır; `PageLayer.sourceIndex` onun sayfa
/// sırasını gösterir. Kaynaktaki eski `inken:` açıklamaları silinip yeniden
/// yazılır, başkalarının açıklamalarına dokunulmaz.
///
/// [font] metin fontunun (TrueType) baytlarıdır: metin harf şekilleriyle
/// yazılır, font dosyaya gömülmez. Verilmezse metinler atlanır.
///
/// [images] modeldeki görsellerin baytlarıdır. Kullanılan her görsel
/// `inken-image-<id>.png` eki olarak gömülür; kullanılmayan eski görsel
/// ekleri silinir. Dosyada zaten olan bir görsel verilmezse eki korunur
/// ama görünümü yazılamaz (atlanan öğe sayılır).
///
/// [password]: [source]'un açılış parolası. Şifreleme korunur: yazılan
/// dosya da aynı parolayı ister.
InkenWriteResult writeInkenPdf(
  (Uint8List, String) request, [
  Uint8List? font,
  Map<String, InkenImage> images = const {},
  String? password,
]) {
  final (source, json) = request;
  final d = _Doc.open(source, password);
  try {
    final (:pages, :skipped) = _writeAnnotations(
      d.doc,
      decodeInkenDocument(json),
      _parseFont(font),
      images,
    );
    final savedJson = encodeInkenDocument(pages);
    _setAttachment(d.doc, utf8.encode(savedJson));
    _syncImageAttachments(d.doc, referencedImageIds(pages), images);
    return (pdf: _save(d.doc), inkenJson: savedJson, skippedItems: skipped);
  } finally {
    d.close();
  }
}

/// Düzleştirilmiş dışa aktarma sonucu.
typedef InkenExportResult = ({
  Uint8List pdf,

  /// PDF'e yazılamayan öğe sayısı (metin fontu verilmediyse metinler).
  int skippedItems,
});

/// [source]'a [document]'in çizimlerini sayfa içeriğine gömülü olarak yazar:
/// açıklama kalmaz, `inken.json` eklenmez (varsa silinir). Öğrenciyle
/// paylaşmak ya da yazdırmak için; Inken'de yeniden düzenlenemez.
///
/// Sayfadaki **tüm** görünür açıklamalar (başkalarınınkiler dahil) içeriğe
/// gömülür: çıktı her okuyucuda ekrandakiyle aynı görünsün diye.
InkenExportResult writeFlattenedPdf(
  (Uint8List, String) request, [
  Uint8List? font,
  Map<String, InkenImage> images = const {},
  String? password,
]) {
  final (source, json) = request;
  final p = _p;
  final d = _Doc.open(source, password);
  try {
    final (:pages, :skipped) = _writeAnnotations(
      d.doc,
      decodeInkenDocument(json),
      _parseFont(font),
      images,
    );
    for (var i = 0; i < pages.pages.length; i++) {
      final page = p.FPDF_LoadPage(d.doc, i);
      if (page == nullptr) throw StateError('Sayfa $i açılamadı');
      try {
        if (p.FPDFPage_Flatten(page, FLAT_NORMALDISPLAY) == FLATTEN_FAIL) {
          throw StateError('Sayfa $i düzleştirilemedi');
        }
      } finally {
        p.FPDF_ClosePage(page);
      }
    }
    _deleteAttachment(d.doc);
    _syncImageAttachments(d.doc, const {}, const {});
    return (pdf: _save(d.doc), skippedItems: skipped);
  } finally {
    d.close();
  }
}

/// Eski `inken:` açıklamalarını silip [document]'inkileri yazar; eklenen
/// sayfaları dosyaya gerçek sayfa olarak ekler. Sayfa sıraları yeniden
/// numaralanmış modeli ve yazılamayan öğe sayısını döner.
({InkenDocument pages, int skipped}) _writeAnnotations(
  FPDF_DOCUMENT doc,
  InkenDocument document,
  TextFont? font,
  Map<String, InkenImage> images,
) {
  final p = _p;
  _removeInkenAnnotations(doc);
  final pages = _arrangePages(doc, document);
  var skipped = 0;
  for (final (i, layer) in pages.indexed) {
    if (layer.items.isEmpty) continue;
    final page = p.FPDF_LoadPage(doc, i);
    if (page == nullptr) throw StateError('Sayfa $i açılamadı');
    try {
      final toPdf = _pageTransform(page);
      for (final item in layer.items) {
        final ap = appearanceFor(item, toPdf, font: font);
        if (ap == null) {
          skipped++;
          continue;
        }
        if (ap.image case final g?) {
          final image = images[g.imageId];
          if (image == null) {
            skipped++;
            continue;
          }
          _addImageAnnotation(doc, page, ap, g.matrix, _prepared(image, g));
          continue;
        }
        _addAnnotation(page, ap);
      }
    } finally {
      p.FPDF_ClosePage(page);
    }
  }
  return (pages: document.copyWith(pages: pages), skipped: skipped);
}

/// Yazıcılar worker isolate'inde çalışır; font her istekte bayt olarak
/// gelir, aynı baytlar için bir kez okunur.
TextFont? _parseFont(Uint8List? bytes) {
  if (bytes == null) return null;
  final cached = _fontCache;
  if (cached != null && identical(cached.$1, bytes)) return cached.$2;
  final font = TextFont.parse(bytes);
  _fontCache = (bytes, font);
  return font;
}

(Uint8List, TextFont)? _fontCache;

/// [pdf]'i okur: gömülü `inken.json`'u çıkarır ve görüntüleme kopyasını
/// hazırlar. Parolalı dosyada [password] gerekir ([PdfPasswordRequired]);
/// görüntüleme kopyası da aynı parolayla şifreli kalır.
InkenReadResult readInkenPdf(Uint8List pdf, {String? password}) {
  final p = _p;
  final d = _Doc.open(pdf, password);
  try {
    final json = _readAttachment(d.doc);
    final pageCount = p.FPDF_GetPageCount(d.doc);
    final isProtected =
        p.FPDF_GetSecurityHandlerRevision(d.doc) != -1 ||
        p.FPDF_GetSignatureCount(d.doc) > 0;
    var display = pdf;
    // Modeli olmayan Inken açıklamaları gizlenmez: düzenlenemezler ama
    // kaybolmamalılar.
    if (json != null && _removeInkenAnnotations(d.doc) > 0) {
      display = _save(d.doc);
    }
    return (
      displayPdf: display,
      inkenJson: json,
      pageCount: pageCount,
      isProtected: isProtected,
      images: json == null ? const <String, Uint8List>{} : _readImages(d.doc),
    );
  } finally {
    d.close();
  }
}

/// Belge özellikleri penceresi için PDF bilgileri. Boş metin: dosyada yok.
typedef PdfInfo = ({
  String title,
  String author,
  String subject,
  String keywords,

  /// Belgeyi oluşturan uygulama (`/Creator`) ve PDF'e çeviren
  /// (`/Producer`).
  String creator,
  String producer,
  DateTime? created,
  DateTime? modified,

  /// "1.7" gibi; okunamazsa `null`.
  String? version,
  bool encrypted,
  bool signed,
});

/// [pdf]'in bilgi sözlüğünü ve sürümünü okur.
PdfInfo readPdfInfo(Uint8List pdf, {String? password}) {
  final p = _p;
  final d = _Doc.open(pdf, password);
  try {
    String meta(String tag) => using(
      (a) => _readWide(
        (b, n) => p.FPDF_GetMetaText(d.doc, _key(a, tag), b.cast(), n),
      ),
    ).trim();
    final version = using((a) {
      final v = a<Int>();
      if (p.FPDF_GetFileVersion(d.doc, v) == 0) return null;
      return '${v.value ~/ 10}.${v.value % 10}';
    });
    return (
      title: meta('Title'),
      author: meta('Author'),
      subject: meta('Subject'),
      keywords: meta('Keywords'),
      creator: meta('Creator'),
      producer: meta('Producer'),
      created: parsePdfDate(meta('CreationDate')),
      modified: parsePdfDate(meta('ModDate')),
      version: version,
      encrypted: p.FPDF_GetSecurityHandlerRevision(d.doc) != -1,
      signed: p.FPDF_GetSignatureCount(d.doc) > 0,
    );
  } finally {
    d.close();
  }
}

/// PDF tarih metni (`D:20231015123000+03'00'`; ay ve sonrası isteğe
/// bağlı) → yerel saat. Saat dilimi yoksa yerel kabul edilir; okunamazsa
/// `null`.
DateTime? parsePdfDate(String text) {
  final m = RegExp(
    r"^(?:D:)?(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?"
    r"(?:([Zz+\-])(?:(\d{2})'?(?:(\d{2})'?)?)?)?",
  ).firstMatch(text.trim());
  if (m == null) return null;
  int part(int i, int fallback) =>
      m.group(i) == null ? fallback : int.parse(m.group(i)!);
  final (y, mo, day) = (part(1, 0), part(2, 1), part(3, 1));
  final (h, mi, sec) = (part(4, 0), part(5, 0), part(6, 0));
  if (mo < 1 || mo > 12 || day < 1 || day > 31 || h > 23 || mi > 59) {
    return null;
  }
  final zone = m.group(7);
  if (zone == null) return DateTime(y, mo, day, h, mi, sec);
  final offset = Duration(hours: part(8, 0), minutes: part(9, 0));
  final utc = DateTime.utc(y, mo, day, h, mi, sec);
  return switch (zone) {
    '+' => utc.subtract(offset),
    '-' => utc.add(offset),
    _ => utc,
  }.toLocal();
}

/// Yazılmış bir Inken dosyasındaki açıklamaların özeti (testler ve
/// tanılama için).
typedef InkenAnnotationInfo = ({
  int page,
  int subtype,
  String name,
  bool hasAp,
});

List<InkenAnnotationInfo> listAnnotations(Uint8List pdf) {
  final p = _p;
  final d = _Doc.open(pdf);
  try {
    final out = <InkenAnnotationInfo>[];
    for (var i = 0; i < p.FPDF_GetPageCount(d.doc); i++) {
      final page = p.FPDF_LoadPage(d.doc, i);
      for (var k = 0; k < p.FPDFPage_GetAnnotCount(page); k++) {
        final annot = p.FPDFPage_GetAnnot(page, k);
        out.add((
          page: i,
          subtype: p.FPDFAnnot_GetSubtype(annot),
          name: _annotName(annot),
          hasAp:
              p.FPDFAnnot_GetAP(
                annot,
                FPDF_ANNOT_APPEARANCEMODE_NORMAL,
                nullptr,
                0,
              ) >
              2,
        ));
        p.FPDFPage_CloseAnnot(annot);
      }
      p.FPDF_ClosePage(page);
    }
    return out;
  } finally {
    d.close();
  }
}

// ------------------------------------------------------------- belge

/// Belge açılış parolası istiyor; [wrong] ise verilen parola yanlış.
class PdfPasswordRequired implements Exception {
  const PdfPasswordRequired({required this.wrong});
  final bool wrong;

  @override
  String toString() => wrong ? 'PDF parolası yanlış' : 'PDF parola istiyor';
}

class _Doc {
  _Doc._(this.doc, this._buf);

  /// PDFium belgeyi bellekten okurken arabelleğin yaşaması gerekir;
  /// [close] ikisini birlikte bırakır.
  ///
  /// [password]: açılış parolası (parolasız dosyada yok sayılır).
  /// Parola gerekiyorsa ya da yanlışsa [PdfPasswordRequired].
  factory _Doc.open(Uint8List data, [String? password]) {
    final buf = malloc<Uint8>(data.isEmpty ? 1 : data.length);
    buf.asTypedList(data.length).setAll(0, data);
    final pw = password == null ? nullptr : password.toNativeUtf8();
    final FPDF_DOCUMENT doc;
    try {
      doc = _p.FPDF_LoadMemDocument(buf.cast(), data.length, pw.cast());
    } finally {
      if (pw != nullptr) malloc.free(pw);
    }
    if (doc == nullptr) {
      final err = _p.FPDF_GetLastError();
      malloc.free(buf);
      if (err == FPDF_ERR_PASSWORD) {
        throw PdfPasswordRequired(wrong: password != null);
      }
      throw FormatException('PDF açılamadı (PDFium hata kodu $err)');
    }
    return _Doc._(doc, buf);
  }

  final FPDF_DOCUMENT doc;
  final Pointer<Uint8> _buf;

  void close() {
    _p.FPDF_CloseDocument(doc);
    malloc.free(_buf);
  }
}

final BytesBuilder _sink = BytesBuilder(copy: true);

int _writeBlock(Pointer<FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _sink.add(data.cast<Uint8>().asTypedList(size));
  return 1;
}

Uint8List _save(FPDF_DOCUMENT doc) {
  final fw = calloc<FPDF_FILEWRITE_>();
  try {
    fw.ref.version = 1;
    fw.ref.WriteBlock =
        Pointer.fromFunction<
          Int Function(Pointer<FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)
        >(_writeBlock, 0);
    _sink.clear();
    if (_p.FPDF_SaveAsCopy(doc, fw, FPDF_NO_INCREMENTAL) == 0) {
      _sink.clear();
      throw StateError('PDF kaydedilemedi (FPDF_SaveAsCopy)');
    }
    return _sink.takeBytes();
  } finally {
    calloc.free(fw);
  }
}

// ------------------------------------------------------------- metin

Pointer<UnsignedShort> _wide(Arena a, String s) =>
    s.toNativeUtf16(allocator: a).cast<UnsignedShort>();

Pointer<Char> _key(Arena a, String s) =>
    s.toNativeUtf8(allocator: a).cast<Char>();

/// PDFium'un "önce uzunluğu sor, sonra doldur" UTF-16 kalıbı.
String _readWide(int Function(Pointer<UnsignedShort> buf, int len) call) {
  final len = call(nullptr, 0);
  if (len <= 2) return '';
  final buf = calloc<Uint8>(len);
  try {
    call(buf.cast(), len);
    return String.fromCharCodes(buf.cast<Uint16>().asTypedList(len ~/ 2 - 1));
  } finally {
    calloc.free(buf);
  }
}

String _annotName(FPDF_ANNOTATION annot) => using(
  (a) => _readWide(
    (b, n) => _p.FPDFAnnot_GetStringValue(annot, _key(a, 'NM'), b, n),
  ),
);

// ------------------------------------------------------------- açıklamalar

/// `inken:` önekli açıklamaları siler; silinen sayıyı döner.
int _removeInkenAnnotations(FPDF_DOCUMENT doc) {
  final p = _p;
  var removed = 0;
  for (var i = 0; i < p.FPDF_GetPageCount(doc); i++) {
    final page = p.FPDF_LoadPage(doc, i);
    for (var k = p.FPDFPage_GetAnnotCount(page) - 1; k >= 0; k--) {
      final annot = p.FPDFPage_GetAnnot(page, k);
      final name = _annotName(annot);
      p.FPDFPage_CloseAnnot(annot);
      if (name.startsWith(inkenAnnotationPrefix) &&
          p.FPDFPage_RemoveAnnot(page, k) != 0) {
        removed++;
      }
    }
    p.FPDF_ClosePage(page);
  }
  return removed;
}

PdfAffine _pageTransform(FPDF_PAGE page) => using((a) {
  final box = a<FS_RECTF>();
  if (_p.FPDF_GetPageBoundingBox(page, box) == 0) {
    throw StateError('Sayfa kutusu okunamadı');
  }
  // FS_RECTF'te top > bottom (PDF uzayı).
  final r = box.ref;
  return pageToPdfTransform((
    left: r.left,
    bottom: r.bottom,
    right: r.right,
    top: r.top,
  ), _p.FPDFPage_GetRotation(page));
});

void _addAnnotation(FPDF_PAGE page, AnnotationAppearance ap) {
  final p = _p;
  final subtype = switch (ap.kind) {
    AnnotationKind.ink => FPDF_ANNOT_INK,
    AnnotationKind.square => FPDF_ANNOT_SQUARE,
    AnnotationKind.circle => FPDF_ANNOT_CIRCLE,
    AnnotationKind.stamp || AnnotationKind.image => FPDF_ANNOT_STAMP,
  };
  final annot = p.FPDFPage_CreateAnnot(page, subtype);
  if (annot == nullptr) throw StateError('Açıklama oluşturulamadı');
  try {
    using((a) {
      final rect = a<FS_RECTF>();
      rect.ref
        ..left = ap.rect.left
        ..bottom = ap.rect.bottom
        ..right = ap.rect.right
        ..top = ap.rect.top;
      _check(p.FPDFAnnot_SetRect(annot, rect), 'SetRect');
      _check(
        p.FPDFAnnot_SetStringValue(
          annot,
          _key(a, 'NM'),
          _wide(a, '$inkenAnnotationPrefix${ap.itemId}'),
        ),
        'NM',
      );
      p.FPDFAnnot_SetFlags(annot, FPDF_ANNOT_FLAG_PRINT);
      if (ap.contents case final text?) {
        _check(
          p.FPDFAnnot_SetStringValue(
            annot,
            _key(a, 'Contents'),
            _wide(a, text),
          ),
          'Contents',
        );
      }
      for (final list in ap.inkList) {
        final n = list.length ~/ 2;
        final pts = a<FS_POINTF>(n);
        for (var i = 0; i < n; i++) {
          pts[i]
            ..x = list[2 * i]
            ..y = list[2 * i + 1];
        }
        if (p.FPDFAnnot_AddInkStroke(annot, pts, n) < 0) {
          throw StateError('AddInkStroke başarısız');
        }
      }
      // Sıra önemli: görünüm akışı varken SetColor reddediliyor. Stamp'in
      // rengi yalnızca görünümündedir (/C ve /Border kullanılmaz).
      final c = ap.color;
      if (ap.kind != AnnotationKind.stamp) {
        _check(
          p.FPDFAnnot_SetColor(
            annot,
            FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
            (c >> 16) & 0xFF,
            (c >> 8) & 0xFF,
            c & 0xFF,
            (c >>> 24) & 0xFF,
          ),
          'SetColor',
        );
        _check(p.FPDFAnnot_SetBorder(annot, 0, 0, ap.borderWidth), 'SetBorder');
      }
      _check(
        p.FPDFAnnot_SetAP(
          annot,
          FPDF_ANNOT_APPEARANCEMODE_NORMAL,
          _wide(a, ap.stream),
        ),
        'SetAP',
      );
    });
  } finally {
    p.FPDFPage_CloseAnnot(annot);
  }
}

/// Görsel: Stamp açıklaması; görünüm akışını PDFium görsel nesnesinden
/// üretir (`FPDFAnnot_AppendObject`). Saydamlık yumuşak maske olarak
/// korunur.
/// Öğenin kırpma, döndürme ve opaklığı uygulanmış pikselleri; değişiklik
/// yoksa görselin kendisi.
InkenImage _prepared(
  InkenImage image,
  ({String imageId, PdfAffine matrix, CropRect crop, int turns, double opacity})
  g,
) {
  if (image.width <= 0 || image.height <= 0) return image;
  final t = transformImagePixels(
    image.rgba,
    image.width,
    image.height,
    crop: g.crop,
    turns: g.turns,
    opacity: g.opacity,
  );
  if (identical(t.rgba, image.rgba)) return image;
  return InkenImage(
    png: image.png,
    width: t.width,
    height: t.height,
    rgba: t.rgba,
  );
}

void _addImageAnnotation(
  FPDF_DOCUMENT doc,
  FPDF_PAGE page,
  AnnotationAppearance ap,
  PdfAffine m,
  InkenImage image,
) {
  final p = _p;
  final w = image.width, h = image.height;
  if (w <= 0 || h <= 0 || image.rgba.length < w * h * 4) {
    throw ArgumentError('Görsel pikselleri eksik (${ap.itemId})');
  }
  final annot = p.FPDFPage_CreateAnnot(page, FPDF_ANNOT_STAMP);
  if (annot == nullptr) throw StateError('Açıklama oluşturulamadı');
  try {
    using((a) {
      final rect = a<FS_RECTF>();
      rect.ref
        ..left = ap.rect.left
        ..bottom = ap.rect.bottom
        ..right = ap.rect.right
        ..top = ap.rect.top;
      _check(p.FPDFAnnot_SetRect(annot, rect), 'SetRect');
      _check(
        p.FPDFAnnot_SetStringValue(
          annot,
          _key(a, 'NM'),
          _wide(a, '$inkenAnnotationPrefix${ap.itemId}'),
        ),
        'NM',
      );
      p.FPDFAnnot_SetFlags(annot, FPDF_ANNOT_FLAG_PRINT);
      // RGBA → PDFium'un BGRA'sı.
      final n = w * h * 4;
      final buf = a<Uint8>(n);
      final px = buf.asTypedList(n);
      final src = image.rgba;
      for (var i = 0; i < n; i += 4) {
        px[i] = src[i + 2];
        px[i + 1] = src[i + 1];
        px[i + 2] = src[i];
        px[i + 3] = src[i + 3];
      }
      final obj = p.FPDFPageObj_NewImageObj(doc);
      if (obj == nullptr) throw StateError('Görsel nesnesi oluşturulamadı');
      final bmp = p.FPDFBitmap_CreateEx(
        w,
        h,
        FPDFBitmap_BGRA,
        buf.cast(),
        w * 4,
      );
      if (bmp == nullptr) {
        p.FPDFPageObj_Destroy(obj);
        throw StateError('Görsel belleği ayrılamadı');
      }
      try {
        if (p.FPDFImageObj_SetBitmap(nullptr, 0, obj, bmp) == 0 ||
            p.FPDFImageObj_SetMatrix(obj, m.a, m.b, m.c, m.d, m.e, m.f) == 0) {
          p.FPDFPageObj_Destroy(obj);
          throw StateError('PDFium: görsel yazılamadı');
        }
      } finally {
        p.FPDFBitmap_Destroy(bmp);
      }
      // Başarılıysa nesnenin sahibi açıklamadır.
      if (p.FPDFAnnot_AppendObject(annot, obj) == 0) {
        p.FPDFPageObj_Destroy(obj);
        throw StateError('PDFium: görsel açıklamaya eklenemedi');
      }
    });
  } finally {
    p.FPDFPage_CloseAnnot(annot);
  }
}

void _check(int ok, String what) {
  if (ok == 0) throw StateError('PDFium: $what başarısız');
}

// ------------------------------------------------------------- sayfalar

/// Dosyanın sayfalarını modelin düzenine getirir: modelde olmayan kaynak
/// sayfaları siler, taşınanları yerine koyar (`FPDF_MovePages`: içerik,
/// açıklamalar ve yer imleri sayfayla gider), eklenen sayfaları oluşturur.
/// Dönen katmanlarda `sourceIndex` kaydedilen dosyadaki sıradır.
///
/// Her kaynak sayfa en çok bir kez olmalıdır; dosyada olmayan ya da iki
/// kez geçen sayfa [StateError] verir.
///
/// Silinen sayfa açıklamalarıyla birlikte gider. Form alanı varsa AcroForm
/// listesindeki ilgili alan sahipsiz kalır; okuyucular bunu yok sayar.
List<PageLayer> _arrangePages(FPDF_DOCUMENT doc, InkenDocument document) {
  final p = _p;
  final sourceCount = p.FPDF_GetPageCount(doc);
  final wanted = <int>[];
  for (final layer in document.pages) {
    final src = layer.sourceIndex;
    if (src == null) continue;
    if (src < 0 || src >= sourceCount) {
      throw StateError('Sayfa $src dosyada yok ($sourceCount sayfa)');
    }
    if (wanted.contains(src)) {
      throw StateError('Sayfa $src modelde iki kez');
    }
    wanted.add(src);
  }
  for (var s = sourceCount - 1; s >= 0; s--) {
    if (!wanted.contains(s)) p.FPDFPage_Delete(doc, s);
  }
  // Silmeden sonra kalanlar artan sırada; modelin sırasına tek tek taşınır.
  final current = [...wanted]..sort();
  final index = malloc<Int>();
  try {
    for (var i = 0; i < wanted.length; i++) {
      final at = current.indexOf(wanted[i]);
      if (at == i) continue;
      index.value = at;
      _check(p.FPDF_MovePages(doc, index, 1, i), 'sayfa taşıma');
      current.insert(i, current.removeAt(at));
    }
  } finally {
    malloc.free(index);
  }
  final out = <PageLayer>[];
  for (final (i, layer) in document.pages.indexed) {
    if (layer.isInserted) {
      _insertTemplatePage(
        doc,
        i,
        layer.width,
        layer.height,
        layer.template ?? PageTemplate.blank,
        layer.color ?? PageColor.white,
      );
    } else if (layer.pendingTurns != 0) {
      _rotatePage(doc, i, layer.pendingTurns);
    }
    out.add(layer.copyWith(sourceIndex: i, rotation: null));
  }
  return out;
}

/// [index] sayfasının `/Rotate` değerine [turns] çeyrek tur (saat yönünde)
/// ekler. Açıklamalar sonra yazılır; dönüşümleri yeni değere göredir.
void _rotatePage(FPDF_DOCUMENT doc, int index, int turns) {
  final p = _p;
  final page = p.FPDF_LoadPage(doc, index);
  if (page == nullptr) throw StateError('Sayfa $index açılamadı');
  try {
    p.FPDFPage_SetRotation(page, (p.FPDFPage_GetRotation(page) + turns) % 4);
  } finally {
    p.FPDF_ClosePage(page);
  }
}

/// Görüntüleme kopyasını ([display]; açıldığı dosyanın Inken açıklamaları
/// gizlenmiş hali) modelin sayfa düzenine getirir: silinen sayfalar çıkar,
/// eklenenler şablonuyla girer. Çizim yazılmaz; çizimleri katman çizer.
/// Kayıttaki sayfalarla aynı kod (`_arrangePages`) kullanılır, ekranda
/// görünen sayfa kaydedilenle bire birdir.
Uint8List arrangeDisplayPdf((Uint8List, String) request, [String? password]) {
  final (display, json) = request;
  final d = _Doc.open(display, password);
  try {
    _arrangePages(d.doc, decodeInkenDocument(json));
    return _save(d.doc);
  } finally {
    d.close();
  }
}

const double _templateStep = 28.35; // 1 cm

/// A4 dikey (pt).
const ({double width, double height}) a4Portrait = (
  width: 595.28,
  height: 841.89,
);

/// Tek boş sayfalık yeni PDF ("Dosya → Yeni"). [size] pt cinsindendir.
/// Sayfa, eklenen boş sayfalarla aynı kodla (`_insertTemplatePage`) üretilir.
/// [pdf]'in yalnızca [pages] sayfalarını (0'dan, verilen sırayla; tekrar
/// olabilir) içeren yeni bir PDF. Yazdırırken seçilen aralık için
/// (Android'in yazdırma ekranı belgenin tamamını gösterir).
Uint8List extractPdfPages(Uint8List pdf, List<int> pages) {
  if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'boş');
  final p = _p;
  final src = _Doc.open(pdf);
  try {
    final count = p.FPDF_GetPageCount(src.doc);
    if (pages.any((i) => i < 0 || i >= count)) {
      throw RangeError('Sayfa sırası 0..${count - 1} dışında: $pages');
    }
    final dest = p.FPDF_CreateNewDocument();
    if (dest == nullptr) throw StateError('PDF oluşturulamadı');
    try {
      using((a) {
        final ids = a<Int>(pages.length);
        for (final (i, page) in pages.indexed) {
          ids[i] = page;
        }
        _check(
          p.FPDF_ImportPagesByIndex(dest, src.doc, ids, pages.length, 0),
          'ImportPagesByIndex',
        );
      });
      return _save(dest);
    } finally {
      p.FPDF_CloseDocument(dest);
    }
  } finally {
    src.close();
  }
}

Uint8List createBlankPdf(({double width, double height}) size) {
  if (size.width <= 0 || size.height <= 0) {
    throw ArgumentError.value(size, 'size', 'sayfa boyutu pozitif olmalı');
  }
  final p = _p;
  final doc = p.FPDF_CreateNewDocument();
  if (doc == nullptr) throw StateError('PDF oluşturulamadı');
  try {
    _insertTemplatePage(doc, 0, size.width, size.height, PageTemplate.blank);
    return _save(doc);
  } finally {
    p.FPDF_CloseDocument(doc);
  }
}

void _insertTemplatePage(
  FPDF_DOCUMENT doc,
  int index,
  double w,
  double h,
  PageTemplate template, [
  PageColor color = PageColor.white,
]) {
  final p = _p;
  final page = p.FPDFPage_New(doc, index, w, h);
  if (page == nullptr) throw StateError('Sayfa eklenemedi');
  // Koyu kâğıtta çizgiler koyu zemine göre: soluk ama seçilir.
  final dark = color == PageColor.black;
  try {
    if (color != PageColor.white) {
      final argb = pageColorArgb(color);
      final fill = p.FPDFPageObj_CreateNewRect(0, 0, w, h);
      p.FPDFPageObj_SetFillColor(
        fill,
        argb >> 16 & 0xFF,
        argb >> 8 & 0xFF,
        argb & 0xFF,
        255,
      );
      p.FPDFPath_SetDrawMode(fill, FPDF_FILLMODE_WINDING, 0);
      p.FPDFPage_InsertObject(page, fill);
    }
    // Not: PDFium sayfa nesnelerinde orijin sol alttır.
    //
    // [originX] / [originY]: bir çizginin geçeceği nokta (PDF uzayı).
    // Verilmezse çizgiler sol üst köşeden başlar; koordinat düzleminde
    // eksenlerden başlar ki eksenler bir kare çizgisine otursun.
    void lines({
      required bool vertical,
      required bool horizontal,
      double? originX,
      double? originY,
    }) {
      final path = p.FPDFPageObj_CreateNewPath(0, 0);
      if (vertical) {
        // originX'ten sola doğru, 0'ın üstündeki ilk çizgiye kadar.
        final ox = originX ?? 0;
        var x = ox - (ox / _templateStep).floor() * _templateStep;
        if (x < 1e-6) x += _templateStep;
        for (; x < w - 1e-6; x += _templateStep) {
          p.FPDFPath_MoveTo(path, x, 0);
          p.FPDFPath_LineTo(path, x, h);
        }
      }
      if (horizontal) {
        // originY yoksa üst kenardan aşağı ([h]'den başlayarak).
        final top = originY ?? h;
        var y = top + ((h - top) / _templateStep).floor() * _templateStep;
        if (y > h - 1e-6) y -= _templateStep;
        for (; y > 1e-6; y -= _templateStep) {
          p.FPDFPath_MoveTo(path, 0, y);
          p.FPDFPath_LineTo(path, w, y);
        }
      }
      if (dark) {
        p.FPDFPageObj_SetStrokeColor(path, 70, 82, 100, 255);
      } else {
        p.FPDFPageObj_SetStrokeColor(path, 200, 215, 235, 255);
      }
      p.FPDFPageObj_SetStrokeWidth(path, 0.5);
      p.FPDFPath_SetDrawMode(path, FPDF_FILLMODE_NONE, 1);
      p.FPDFPage_InsertObject(page, path);
    }

    switch (template) {
      case PageTemplate.blank:
        break;
      case PageTemplate.grid:
        lines(vertical: true, horizontal: true);
      case PageTemplate.lined:
        lines(vertical: false, horizontal: true);
      case PageTemplate.coordinate:
        lines(vertical: true, horizontal: true, originX: w / 2, originY: h / 2);
        final axes = p.FPDFPageObj_CreateNewPath(w / 2, 0);
        p.FPDFPath_LineTo(axes, w / 2, h);
        p.FPDFPath_MoveTo(axes, 0, h / 2);
        p.FPDFPath_LineTo(axes, w, h / 2);
        if (dark) {
          p.FPDFPageObj_SetStrokeColor(axes, 170, 180, 200, 255);
        } else {
          p.FPDFPageObj_SetStrokeColor(axes, 90, 100, 120, 255);
        }
        p.FPDFPageObj_SetStrokeWidth(axes, 1);
        p.FPDFPath_SetDrawMode(axes, FPDF_FILLMODE_NONE, 1);
        p.FPDFPage_InsertObject(page, axes);
      case PageTemplate.dotted:
        const r = 0.8;
        final dots = p.FPDFPageObj_CreateNewPath(0, 0);
        for (var x = _templateStep; x < w; x += _templateStep) {
          for (var y = h - _templateStep; y > 0; y -= _templateStep) {
            p.FPDFPath_MoveTo(dots, x - r, y - r);
            p.FPDFPath_LineTo(dots, x + r, y - r);
            p.FPDFPath_LineTo(dots, x + r, y + r);
            p.FPDFPath_LineTo(dots, x - r, y + r);
            p.FPDFPath_Close(dots);
          }
        }
        if (dark) {
          p.FPDFPageObj_SetFillColor(dots, 100, 112, 135, 255);
        } else {
          p.FPDFPageObj_SetFillColor(dots, 150, 165, 190, 255);
        }
        p.FPDFPath_SetDrawMode(dots, FPDF_FILLMODE_WINDING, 0);
        p.FPDFPage_InsertObject(page, dots);
    }
    if (p.FPDFPage_GenerateContent(page) == 0) {
      throw StateError('Sayfa içeriği üretilemedi');
    }
  } finally {
    p.FPDF_ClosePage(page);
  }
}

// ------------------------------------------------------------- ek dosya

FPDF_ATTACHMENT? _findAttachment(
  FPDF_DOCUMENT doc,
  void Function(int) onIndex,
) {
  final p = _p;
  FPDF_ATTACHMENT? found;
  for (var i = p.FPDFDoc_GetAttachmentCount(doc) - 1; i >= 0; i--) {
    final att = p.FPDFDoc_GetAttachment(doc, i);
    final name = _readWide((b, n) => p.FPDFAttachment_GetName(att, b, n));
    if (name == inkenAttachmentName) {
      found ??= att;
      onIndex(i);
    }
  }
  return found;
}

/// `inken.json` eklerini siler.
void _deleteAttachment(FPDF_DOCUMENT doc) {
  final old = <int>[];
  _findAttachment(doc, old.add);
  for (final i in old) {
    // Azalan sırada: silmek sonraki indeksleri kaydırmaz.
    _check(_p.FPDFDoc_DeleteAttachment(doc, i), 'DeleteAttachment');
  }
}

void _setAttachment(FPDF_DOCUMENT doc, List<int> bytes) {
  final p = _p;
  _deleteAttachment(doc);
  using((a) {
    final att = p.FPDFDoc_AddAttachment(doc, _wide(a, inkenAttachmentName));
    if (att == nullptr) throw StateError('inken.json eklenemedi');
    final buf = a<Uint8>(bytes.length);
    buf.asTypedList(bytes.length).setAll(0, bytes);
    _check(
      p.FPDFAttachment_SetFile(att, doc, buf.cast(), bytes.length),
      'Attachment_SetFile',
    );
  });
}

String? _readAttachment(FPDF_DOCUMENT doc) {
  final att = _findAttachment(doc, (_) {});
  if (att == null) return null;
  return using((a) {
    final outLen = a<UnsignedLong>();
    if (_p.FPDFAttachment_GetFile(att, nullptr, 0, outLen) == 0) return null;
    final len = outLen.value;
    final buf = a<Uint8>(len == 0 ? 1 : len);
    _p.FPDFAttachment_GetFile(att, buf.cast(), len, outLen);
    return utf8.decode(buf.asTypedList(len), allowMalformed: false);
  });
}

// ------------------------------------------------------------- görsel ekleri

/// Görsel eklerinin adları ve sıraları, azalan sırada (silmek sonrakilerin
/// sırasını kaydırmasın).
List<({int index, String imageId, FPDF_ATTACHMENT att})> _imageAttachments(
  FPDF_DOCUMENT doc,
) {
  final p = _p;
  return [
    for (var i = p.FPDFDoc_GetAttachmentCount(doc) - 1; i >= 0; i--)
      if (p.FPDFDoc_GetAttachment(doc, i) case final att when att != nullptr)
        if (imageIdOfAttachment(
              _readWide((b, n) => p.FPDFAttachment_GetName(att, b, n)),
            )
            case final id?)
          (index: i, imageId: id, att: att),
  ];
}

/// Görsel eklerini [used]'a göre düzenler: kullanılmayanlar ve [images]'ta
/// yenisi verilenler silinir, verilenler (kullanılıyorsa) yazılır. Aynı
/// kimlik iki kez bulunmaz.
void _syncImageAttachments(
  FPDF_DOCUMENT doc,
  Set<String> used,
  Map<String, InkenImage> images,
) {
  final p = _p;
  final kept = <String>{};
  for (final a in _imageAttachments(doc)) {
    final keep =
        used.contains(a.imageId) &&
        !images.containsKey(a.imageId) &&
        kept.add(a.imageId);
    if (!keep) {
      _check(p.FPDFDoc_DeleteAttachment(doc, a.index), 'DeleteAttachment');
    }
  }
  for (final id in used) {
    final image = images[id];
    if (image == null) continue;
    using((a) {
      final att = p.FPDFDoc_AddAttachment(
        doc,
        _wide(a, imageAttachmentName(id)),
      );
      if (att == nullptr) throw StateError('Görsel eki eklenemedi');
      final bytes = image.png;
      final buf = a<Uint8>(bytes.isEmpty ? 1 : bytes.length);
      buf.asTypedList(bytes.length).setAll(0, bytes);
      _check(
        p.FPDFAttachment_SetFile(att, doc, buf.cast(), bytes.length),
        'Attachment_SetFile',
      );
    });
  }
}

Map<String, Uint8List> _readImages(FPDF_DOCUMENT doc) {
  final out = <String, Uint8List>{};
  for (final a in _imageAttachments(doc)) {
    final bytes = _readFile(a.att);
    if (bytes != null) out.putIfAbsent(a.imageId, () => bytes);
  }
  return out;
}

Uint8List? _readFile(FPDF_ATTACHMENT att) => using((a) {
  final outLen = a<UnsignedLong>();
  if (_p.FPDFAttachment_GetFile(att, nullptr, 0, outLen) == 0) return null;
  final len = outLen.value;
  final buf = a<Uint8>(len == 0 ? 1 : len);
  _p.FPDFAttachment_GetFile(att, buf.cast(), len, outLen);
  return Uint8List.fromList(buf.asTypedList(len));
});
