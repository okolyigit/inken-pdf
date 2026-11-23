import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'document_io.dart';
import '../ink/text_font_provider.dart';
import 'recent_documents.dart';

export 'document_io.dart' show DocTarget, isContentUri, writeFileAtomically;

/// Açık olan PDF.
class OpenDocument {
  OpenDocument({
    required this.name,
    required this.bytes,
    Uint8List? displayBytes,
    this.path,
    this.writable = true,
    this.model,
    this.isProtected = false,
    this.recovered,
    this.images = const {},
    this.password,
    this.isGuide = false,
    String? sourceName,
  }) : displayBytes = displayBytes ?? bytes,
       sourceName = sourceName ?? '$name#${identityHashCode(bytes)}';

  final String name;

  /// Dosyanın kendisi; kaydederken kaynak olarak kullanılır.
  final Uint8List bytes;

  /// Görüntüleyiciye verilen kopya: Inken açıklamaları gizlenmiş.
  final Uint8List displayBytes;

  /// Belgenin yeri: masaüstünde dosya yolu, Android'de `content://` URI.
  /// Bilinmiyorsa `null` (yalnızca "Farklı kaydet" ile kaydedilebilir).
  final String? path;

  /// [path]'e geri yazılabilir mi? (Android'de sağlayıcı izin vermeyebilir.)
  final bool writable;

  /// Dosyaya gömülü çizim modeli; düz PDF'te `null`.
  final InkenDocument? model;

  /// Şifreli ya da imzalı: çizimler yalnızca kopyaya kaydedilir.
  final bool isProtected;

  /// Otomatik yedekten geri yüklenen, kaydedilmemiş model. Doluysa açılışta
  /// [model]'in yerine geçer (tek geri alma adımı olarak).
  final InkenDocument? recovered;

  /// Belgenin görselleri (kimlik → PNG): dosyaya gömülü olanlar ve
  /// kurtarılan yedeğinkiler.
  final Map<String, Uint8List> images;

  /// Açılış parolası (parolalı dosyada). Bellekte kalır, diske yazılmaz;
  /// kaydedilen kopya da aynı parolayı ister.
  final String? password;

  /// Uygulamayla gelen "Başlarken" kılavuzu: yeri yoktur (ilk kayıt
  /// "Farklı kaydet"), kapatırken kaydedilmemiş değişiklik sorulmaz
  /// (Dene alanlarındaki karalamalar). Kaydedilince sıradan belge olur.
  final bool isGuide;

  /// Görüntüleyici önbelleği ve sayfa anahtarı için kimlik. Kayıttan sonra
  /// değişmez; böylece kaydetmek görüntüleyiciyi yeniden yüklemez.
  final String sourceName;

  /// Inken dosyası mı (daha önce Inken ile kaydedilmiş)?
  bool get isInkenFile => model != null;

  /// Kendi üstüne kaydedilir mi? Yalnızca yazılabilir, korumasız Inken
  /// dosyası; düz ya da korumalı PDF'in orijinaline dokunulmaz.
  bool get savesInPlace => isInkenFile && !isProtected && writable;
}

/// Kayıt yeri sorulmadan bulunamıyor (Android'de düz PDF'in ilk kaydı:
/// yanına dosya yazma izni yok). Arayüz "Farklı kaydet"e yönlendirir.
class NeedsSaveLocation implements Exception {
  const NeedsSaveLocation();
}

/// Dosya açılamadı; neden arayüzde çevrilerek gösterilir.
enum OpenFailure {
  /// `inken.json` bu uygulamadan daha yeni bir formatla yazılmış.
  newerFormat,

  /// `inken.json` okunamıyor.
  corruptData,

  /// Dosyanın sayfaları başka bir programla değiştirilmiş.
  pageMismatch,
}

class OpenDocumentException implements Exception {
  const OpenDocumentException(this.failure, [this.detail]);
  final OpenFailure failure;
  final Object? detail;

  @override
  String toString() => 'OpenDocumentException($failure, $detail)';
}

/// Okunan baytlardan [OpenDocument] kurar; `inken.json`'u doğrular.
///
/// Gömülü model okunamıyorsa dosya açılmaz: düz PDF gibi açıp kaydetmek
/// eski çizimleri sessizce silerdi.
OpenDocument documentFromRead({
  required String name,
  required Uint8List bytes,
  required InkenReadResult read,
  String? path,
  bool writable = true,
  String? password,
  bool isGuide = false,
}) {
  InkenDocument? model;
  final json = read.inkenJson;
  if (json != null) {
    try {
      model = decodeInkenDocument(json);
    } on UnsupportedFormatVersion catch (e) {
      throw OpenDocumentException(OpenFailure.newerFormat, e);
    } on FormatException catch (e) {
      throw OpenDocumentException(OpenFailure.corruptData, e);
    }
    if (model.pages.length != read.pageCount) {
      throw OpenDocumentException(
        OpenFailure.pageMismatch,
        '${model.pages.length} != ${read.pageCount}',
      );
    }
  }
  return OpenDocument(
    name: name,
    bytes: bytes,
    displayBytes: read.displayPdf,
    path: path,
    writable: writable,
    model: model,
    isProtected: read.isProtected,
    isGuide: isGuide,
    images: read.images,
    password: password,
  );
}

/// Kaydın gideceği yol; sorulmadan bulunamıyorsa `null`.
///
/// Inken dosyası kendi üstüne kaydedilir; düz ya da korumalı PDF'te
/// orijinale dokunulmaz, yanına `<ad>_inken.pdf` yazılır. O ad doluysa
/// `<ad>_inken (2).pdf`, `(3)`… denenir: hiçbir dosyanın üzerine sessizce
/// yazılmaz. Yanına yazılamıyorsa (SAF) `null`.
String? saveTargetFor(
  OpenDocument doc, {
  bool Function(String path) exists = _exists,
}) {
  final path = doc.path;
  if (path == null) return null;
  if (doc.savesInPlace) return path;
  if (isContentUri(path)) return null;
  final sep = Platform.pathSeparator;
  final slash = path.lastIndexOf(sep);
  final dir = slash < 0 ? '' : path.substring(0, slash + 1);
  var base = slash < 0 ? path : path.substring(slash + 1);
  if (base.toLowerCase().endsWith('.pdf')) {
    base = base.substring(0, base.length - 4);
  }
  var candidate = '$dir${base}_inken.pdf';
  for (var n = 2; exists(candidate); n++) {
    candidate = '$dir${base}_inken ($n).pdf';
  }
  return candidate;
}

bool _exists(String path) => File(path).existsSync();

/// İki yol aynı dosyayı mı gösteriyor? (Windows'ta büyük / küçük harf
/// duyarsız.)
bool samePath(String a, String? b) {
  if (b == null) return false;
  if (isContentUri(a) || isContentUri(b)) return a == b;
  var x = File(a).absolute.path;
  var y = File(b).absolute.path;
  if (Platform.isWindows) {
    x = x.toLowerCase();
    y = y.toLowerCase();
  }
  return x == y;
}

/// "Farklı kaydet"te açık dosyanın kendisi seçilebilir mi? Yalnızca zaten
/// Inken dosyasıysa ve korumalı değilse (normal kayıt gibi); düz ya da
/// korumalı PDF'in orijinalinin üzerine yazılmaz.
bool canSaveAsOver(OpenDocument doc, String target) =>
    !samePath(target, doc.path) || doc.savesInPlace;

/// Konumdan gösterilecek ad: dosya yolunda son parça; URI'de [fallback]
/// (SAF URI'si adı içermeyebilir).
String displayNameOf(String location, {required String fallback}) {
  if (isContentUri(location)) return fallback;
  final sep = Platform.pathSeparator;
  return location.substring(location.lastIndexOf(sep) + 1);
}

/// Yedeğin ait olduğu dosyanın adı.
///
/// Adı kaydedilmemiş eski yedeklerde ad konumdan çıkarılır. URI çözümlemesi
/// yalnızca içerik URI'sinde yapılır: düz yolda `%` ya da ASCII dışı harf
/// (İ, ü…) `Uri.decodeComponent`'i patlatır.
String backupDisplayName(InkenBackup backup) {
  final name = backup.sourceName;
  if (name != null) return name;
  final path = backup.sourcePath;
  if (!isContentUri(path)) return displayNameOf(path, fallback: path);
  String decoded;
  try {
    decoded = Uri.decodeComponent(path);
  } on ArgumentError {
    decoded = path;
  }
  return decoded.split('/').last;
}

/// [name]'den güvenli bir dosya adı: yol ve dosya sistemine yasak
/// karakterler `_` olur, sonu `.<extension>` (varsayılan `.pdf`; adın
/// sonundaki `.pdf` ya da aynı uzantı bir kez sayılır).
String safeFileName(String name, {String extension = 'pdf'}) {
  var base = withoutPdfExtension(name);
  final ext = '.$extension';
  if (base.toLowerCase().endsWith(ext)) {
    base = base.substring(0, base.length - ext.length);
  }
  base = base.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return '${base.isEmpty ? 'Inken' : base}$ext';
}

/// Dosya adından `.pdf` uzantısını atar.
String withoutPdfExtension(String name) => name.toLowerCase().endsWith('.pdf')
    ? name.substring(0, name.length - 4)
    : name;

/// Kaydetme sonucu.
typedef SaveOutcome = ({
  String path,
  String name,
  InkenDocument model,
  int skippedItems,
});

/// Parolalı PDF için parola sorar; vazgeçilirse `null`. [wrong]: önceki
/// deneme yanlıştı.
typedef PasswordPrompt = Future<String?> Function(
  String name, {
  required bool wrong,
});

class OpenDocumentNotifier extends Notifier<OpenDocument?> {
  @override
  OpenDocument? build() => null;

  /// Arayüzün parola penceresi (uygulamanın kökü verir). Yoksa parolalı
  /// dosya [PdfPasswordRequired] ile açılamaz.
  PasswordPrompt? passwordPrompt;

  /// Dosyayı okur; parola gerekiyorsa [passwordPrompt] ile sorar, yanlışsa
  /// yeniden sorar. Kullanıcı vazgeçerse `null`.
  Future<({InkenReadResult read, String? password})?> _load(
    Uint8List bytes,
    String name,
  ) async {
    String? password;
    while (true) {
      try {
        return (
          read: await loadInkenFile(bytes, password: password),
          password: password,
        );
      } on PdfPasswordRequired catch (e) {
        final ask = passwordPrompt;
        if (ask == null) rethrow;
        password = await ask(name, wrong: e.wrong);
        if (password == null) return null;
      }
    }
  }

  DocumentIo get _io => ref.read(documentIoProvider);

  /// Açık belge, kayıt yeri sorulmadan kaydedilemiyor mu?
  bool get needsSaveLocation {
    final doc = state;
    return doc != null && saveTargetFor(doc) == null;
  }

  /// Dosya seçiciyi açar ve seçilen dosyayı açar. Kullanıcı vazgeçerse
  /// `false` döner; okuma hatası ([OpenDocumentException] dahil) çağırana
  /// fırlatılır.
  Future<bool> pickAndOpen({required String typeLabel}) async {
    final file = await pickPdf(typeLabel: typeLabel);
    if (file == null) return false;
    await openPicked(file);
    return true;
  }

  /// Yalnızca dosya seçici; vazgeçilirse `null`. (Açık belge varken önce
  /// dosya seçilir, sonra kapatma sorulur.)
  Future<PickedDocument?> pickPdf({required String typeLabel}) =>
      _io.pickOpen(typeLabel: typeLabel);

  Future<void> openPicked(PickedDocument picked) => openBytes(
    name: picked.name,
    bytes: picked.bytes,
    path: picked.location,
    writable: picked.writable,
  );

  /// Okunmuş dosyayı açar (dosya seçici olmadan; testler de kullanır).
  /// Parolalı dosyada parola sorulur; vazgeçilirse hiçbir şey değişmez.
  Future<void> openBytes({
    required String name,
    required Uint8List bytes,
    String? path,
    bool writable = true,
  }) async {
    final loaded = await _load(bytes, name);
    if (loaded == null) return;
    final read = loaded.read;
    state = documentFromRead(
      name: name,
      bytes: bytes,
      read: read,
      path: path,
      writable: writable,
      password: loaded.password,
    );
    if (path != null) {
      _remember(path, name, bytes, writable: writable, pages: read.pageCount);
    }
  }

  /// Son belgelere ekler (küçük resim arka planda üretilir).
  void _remember(
    String location,
    String name,
    Uint8List bytes, {
    bool writable = true,
    int? pages,
  }) {
    unawaited(
      ref
          .read(recentDocumentsProvider.notifier)
          .remember(
            location: location,
            name: name,
            bytes: bytes,
            writable: writable,
            pageCount: pages,
          ),
    );
  }

  /// Tek boş (A4 dikey) sayfalık yeni belge açar ("Dosya → Yeni"). Yeri
  /// yoktur: ilk kayıt "Farklı kaydet" ile yapılır, son belgelere o zaman
  /// girer. [name] gösterilen ve önerilen dosya adıdır ("Adsız.pdf").
  Future<void> openNew({required String name}) async {
    final bytes = await newBlankPdf();
    final read = await loadInkenFile(bytes);
    state = documentFromRead(name: name, bytes: bytes, read: read);
  }

  /// "Başlarken" kılavuzunu açar ([loadGuide]): yeri yoktur, son
  /// belgelere girmez.
  Future<void> openGuide({
    required String name,
    required Uint8List bytes,
  }) async {
    final read = await loadInkenFile(bytes);
    state = documentFromRead(
      name: name,
      bytes: bytes,
      read: read,
      isGuide: true,
    );
  }

  /// Son belgelerden açar. Dosya yoksa ya da okunamıyorsa okuma hatası
  /// fırlatılır (liste değişmez; arayüz kaldırmayı önerir).
  Future<void> openRecent(RecentDocument recent) async {
    final bytes = await _io.read(recent.location);
    await openBytes(
      name: recent.name,
      bytes: bytes,
      path: recent.location,
      writable: recent.writable,
    );
  }

  /// Otomatik yedeği, ait olduğu dosyayla birlikte açar.
  ///
  /// Dosya okunamazsa okuma hatası; yedeğin sayfaları dosyaya uymuyorsa
  /// [OpenDocumentException] fırlatır.
  ///
  /// [images]: yedeğin görselleri (yedek klasöründen).
  Future<void> restore(
    InkenBackup backup, {
    Map<String, Uint8List> images = const {},
  }) async {
    final location = backup.sourcePath;
    final bytes = await _io.read(location);
    final loaded = await _load(bytes, backupDisplayName(backup));
    if (loaded == null) return;
    final read = loaded.read;
    if (!backup.fitsFile(read.pageCount)) {
      throw const OpenDocumentException(OpenFailure.pageMismatch);
    }
    final doc = documentFromRead(
      name: backupDisplayName(backup),
      bytes: bytes,
      read: read,
      path: location,
      password: loaded.password,
    );
    state = OpenDocument(
      name: doc.name,
      bytes: doc.bytes,
      displayBytes: doc.displayBytes,
      path: doc.path,
      model: doc.model,
      isProtected: doc.isProtected,
      recovered: backup.document,
      images: {...doc.images, ...images},
      password: doc.password,
    );
    _remember(location, doc.name, bytes, pages: read.pageCount);
  }

  /// Açık belgeyi [model] ile kaydeder. [target] verilmezse yer
  /// [saveTargetFor] ile bulunur, bulunamazsa [NeedsSaveLocation] fırlatılır.
  /// "Farklı kaydet"te [target]'ı kullanıcı seçer; uygunluğunu
  /// [canSaveAsOver] ile çağıran denetler.
  ///
  /// [displayBytes]: ekranda gösterilen, kaydedilen modelin sayfa düzenindeki
  /// görüntüleme kopyası (sayfa eklendiyse / silindiyse). Kayıttan sonra
  /// açık dosyanın görüntüleme kopyası odur.
  ///
  /// [images]: modeldeki görseller, yazıcıya hazır (bkz. [saveInkenFile]).
  Future<SaveOutcome> save(
    InkenDocument model, {
    DocTarget? target,
    Uint8List? displayBytes,
    Map<String, InkenImage> images = const {},
  }) async {
    final doc = state;
    if (doc == null) throw StateError('Açık belge yok');
    if (target == null) {
      final path = saveTargetFor(doc);
      if (path == null) throw const NeedsSaveLocation();
      target = (location: path, name: displayNameOf(path, fallback: doc.name));
    }
    final result = await saveInkenFile(
      doc.bytes,
      model,
      font: ref.read(textFontProvider)?.bytes,
      images: images,
      password: doc.password,
    );
    await _io.write(target.location, result.pdf);
    final saved = decodeInkenDocument(result.inkenJson);
    // Artık açık olan dosya kaydedilen dosyadır; görüntüleme baytları ve
    // kimlik aynı kalır (çizimler zaten katmanda).
    state = OpenDocument(
      name: target.name,
      bytes: result.pdf,
      displayBytes: displayBytes ?? doc.displayBytes,
      path: target.location,
      model: saved,
      sourceName: doc.sourceName,
      password: doc.password,
      images: {
        ...doc.images,
        for (final e in images.entries) e.key: e.value.png,
      },
    );
    // Kaydedilen dosya son belgelerin başına; küçük resmi çizimleriyle.
    _remember(
      target.location,
      target.name,
      result.pdf,
      pages: saved.pages.length,
    );
    return (
      path: target.location,
      name: target.name,
      model: saved,
      skippedItems: result.skippedItems,
    );
  }

  /// Açık belgenin [model] ile kaydedilmiş hâlini (kaydetmedeki gibi
  /// düzenlenebilir: çizimler `inken:` açıklamaları, `inken.json` ekte)
  /// [target]'a yazar; açık belge ve yeri değişmez (paylaşma). PDF'e
  /// yazılamayan öğe sayısını döner.
  Future<int> exportCopy(
    InkenDocument model,
    String target, {
    Map<String, InkenImage> images = const {},
  }) async {
    final doc = state;
    if (doc == null) throw StateError('Açık belge yok');
    if (samePath(target, doc.path)) {
      throw ArgumentError.value(target, 'target', 'açık dosyanın kendisi');
    }
    final result = await saveInkenFile(
      doc.bytes,
      model,
      font: ref.read(textFontProvider)?.bytes,
      images: images,
      password: doc.password,
    );
    await _io.write(target, result.pdf);
    return result.skippedItems;
  }

  /// Açık belgenin çizimleri sayfaya gömülmüş kopyasını [target]'a yazar;
  /// PDF'e yazılamayan öğe sayısını döner. Açık belge değişmez.
  ///
  /// [target], açık dosyanın kendisi olamaz (Inken verisini silerdi).
  Future<int> exportFlattened(
    InkenDocument model,
    String target, {
    Map<String, InkenImage> images = const {},
  }) async {
    final doc = state;
    if (doc == null) throw StateError('Açık belge yok');
    if (samePath(target, doc.path)) {
      throw ArgumentError.value(target, 'target', 'açık dosyanın kendisi');
    }
    final result = await exportFlattenedFile(
      doc.bytes,
      model,
      font: ref.read(textFontProvider)?.bytes,
      images: images,
      password: doc.password,
    );
    await _io.write(target, result.pdf);
    return result.skippedItems;
  }

  /// [model]'in [pages] sayfalarını (verilen sırayla) çizimleri gömülü
  /// olarak görüntüye çevirmek üzere açar: yalnızca bu sayfalar düzleştirilir
  /// ([pageSubset]); görüntü, dışa aktarılanla ve yazdırılanla aynıdır.
  /// Kapatmak ([PdfPageImager.dispose]) çağıranın işidir. Açık belge
  /// değişmez.
  Future<PdfPageImager> openPageImages(
    InkenDocument model,
    List<int> pages, {
    Map<String, InkenImage> images = const {},
  }) async {
    final doc = state;
    if (doc == null) throw StateError('Açık belge yok');
    final result = await exportFlattenedFile(
      doc.bytes,
      pageSubset(model, pages),
      font: ref.read(textFontProvider)?.bytes,
      images: images,
      password: doc.password,
    );
    return PdfPageImager.open(result.pdf, password: doc.password);
  }

  void close() => state = null;
}

final openDocumentProvider =
    NotifierProvider<OpenDocumentNotifier, OpenDocument?>(
      OpenDocumentNotifier.new,
    );
