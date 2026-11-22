import 'dart:typed_data';

import 'package:inken_core/inken_core.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_io.dart';

/// [readInkenPdf]'i PDFium'un worker isolate'inde çalıştırır. Parolalı
/// dosyada [password] verilmezse ya da yanlışsa [PdfPasswordRequired].
Future<InkenReadResult> loadInkenFile(
  Uint8List bytes, {
  String? password,
}) async {
  final (result, needsPassword) = await PdfrxEntryFunctions.instance.compute(
    _read,
    (bytes, password),
  );
  if (needsPassword != null) {
    throw PdfPasswordRequired(wrong: needsPassword);
  }
  return result!;
}

/// İstisnalar isolate'ten türünü kaybederek gelir; parola durumu bu yüzden
/// sonuçla döner: (sonuç, `null`) ya da (`null`, yanlış mı).
(InkenReadResult?, bool?) _read((Uint8List, String?) r) {
  try {
    return (readInkenPdf(r.$1, password: r.$2), null);
  } on PdfPasswordRequired catch (e) {
    return (null, e.wrong);
  }
}

/// [document]'i [source] baytlarına yazar; [writeInkenPdf]'i PDFium'un
/// worker isolate'inde çalıştırır. Dosyaya yazmak çağıranın işidir
/// (geçici dosya → `rename`).
///
/// [font]: metin fontunun baytları (bkz. [writeInkenPdf]).
/// [images]: belgedeki görseller (bkz. [writeInkenPdf]).
/// [password]: [source]'un açılış parolası; yazılan dosya da onu ister.
Future<InkenWriteResult> saveInkenFile(
  Uint8List source,
  InkenDocument document, {
  Uint8List? font,
  Map<String, InkenImage> images = const {},
  String? password,
}) => PdfrxEntryFunctions.instance.compute(_write, (
  source,
  encodeInkenDocument(document),
  font,
  images,
  password,
));

typedef _Request = (
  Uint8List,
  String,
  Uint8List?,
  Map<String, InkenImage>,
  String?,
);

InkenWriteResult _write(_Request r) =>
    writeInkenPdf((r.$1, r.$2), r.$3, r.$4, r.$5);

InkenExportResult _export(_Request r) =>
    writeFlattenedPdf((r.$1, r.$2), r.$3, r.$4, r.$5);

/// [document]'i [source]'a düzleştirerek yazar ([writeFlattenedPdf]);
/// PDFium'un worker isolate'inde.
Future<InkenExportResult> exportFlattenedFile(
  Uint8List source,
  InkenDocument document, {
  Uint8List? font,
  Map<String, InkenImage> images = const {},
  String? password,
}) => PdfrxEntryFunctions.instance.compute(_export, (
  source,
  encodeInkenDocument(document),
  font,
  images,
  password,
));

/// Görüntüleme kopyasını [document]'in sayfa düzenine getirir
/// ([arrangeDisplayPdf]); PDFium'un worker isolate'inde. Çizimler
/// gönderilmez, yalnızca sayfa düzeni.
Future<Uint8List> arrangeDisplay(
  Uint8List display,
  InkenDocument document, {
  String? password,
}) => PdfrxEntryFunctions.instance.compute(_arrange, (
  display,
  encodeInkenDocument(pageLayoutOnly(document)),
  password,
));

Uint8List _arrange((Uint8List, String, String?) r) =>
    arrangeDisplayPdf((r.$1, r.$2), r.$3);

/// Tek boş sayfalık yeni PDF ([createBlankPdf]); PDFium'un worker
/// isolate'inde. Varsayılan sayfa A4 dikeydir.
Future<Uint8List> newBlankPdf({
  ({double width, double height}) size = a4Portrait,
}) => PdfrxEntryFunctions.instance.compute(createBlankPdf, size);

/// Dosyadaki açıklamaların özeti ([listAnnotations]); PDFium'un worker
/// isolate'inde (tanılama ve uygulama içi testler).
Future<List<InkenAnnotationInfo>> inspectAnnotations(Uint8List pdf) =>
    PdfrxEntryFunctions.instance.compute(listAnnotations, pdf);

/// Belge bilgileri ([readPdfInfo]); PDFium'un worker isolate'inde.
Future<PdfInfo> loadPdfInfo(Uint8List pdf, {String? password}) =>
    PdfrxEntryFunctions.instance.compute(_info, (pdf, password));

PdfInfo _info((Uint8List, String?) r) => readPdfInfo(r.$1, password: r.$2);

/// [extractPdfPages], PDFium'un iş parçacığında.
Future<Uint8List> extractPages(Uint8List pdf, List<int> pages) =>
    PdfrxEntryFunctions.instance.compute(_extract, (pdf, pages));

Uint8List _extract((Uint8List, List<int>) r) => extractPdfPages(r.$1, r.$2);
