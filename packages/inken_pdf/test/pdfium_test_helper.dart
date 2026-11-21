// Testlerde PDFium'a doğrudan erişim: kütüphane yolu, sayfa boyutu, render.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:inken_pdf/src/pdf_io.dart' show pdfiumModulePath;
import 'package:pdfium_dart/pdfium_dart.dart';

late final PDFium pdfium;

/// `flutter test` PDFium'u derler ama yükleyici kendiliğinden bulamaz;
/// derlenen kütüphanenin yolunu verir.
void setUpPdfium() {
  const candidates = [
    'build/native_assets/linux/libpdfium.so',
    '../../apps/inken/build/native_assets/linux/libpdfium.so',
  ];
  final path = candidates
      .map((c) => File(c).absolute.path)
      .firstWhere(
        (c) => File(c).existsSync(),
        orElse: () => throw StateError(
          'libpdfium.so bulunamadı; önce `flutter build linux` ya da '
          'uygulamada `flutter test` çalıştırın',
        ),
      );
  pdfiumModulePath = path;
  pdfium = getPdfium(modulePath: path)..FPDF_InitLibrary();
}

Uint8List fixture(String name) =>
    File('../../test/fixtures/$name').readAsBytesSync();

T withDoc<T>(Uint8List pdf, T Function(FPDF_DOCUMENT doc) body) {
  final buf = malloc<Uint8>(pdf.length);
  buf.asTypedList(pdf.length).setAll(0, pdf);
  final doc = pdfium.FPDF_LoadMemDocument(buf.cast(), pdf.length, nullptr);
  if (doc == nullptr) throw StateError('PDF açılamadı');
  try {
    return body(doc);
  } finally {
    pdfium.FPDF_CloseDocument(doc);
    malloc.free(buf);
  }
}

/// Sayfaların ekrandaki (döndürülmüş) boyutları — pdfrx'in verdiğiyle aynı.
List<({double width, double height})> pageSizes(Uint8List pdf) =>
    withDoc(pdf, (doc) {
      return [
        for (var i = 0; i < pdfium.FPDF_GetPageCount(doc); i++)
          _withPage(
            doc,
            i,
            (page) => (
              width: pdfium.FPDF_GetPageWidthF(page),
              height: pdfium.FPDF_GetPageHeightF(page),
            ),
          ),
      ];
    });

T _withPage<T>(FPDF_DOCUMENT doc, int i, T Function(FPDF_PAGE page) body) {
  final page = pdfium.FPDF_LoadPage(doc, i);
  try {
    return body(page);
  } finally {
    pdfium.FPDF_ClosePage(page);
  }
}

/// Sayfanın 1 pt = 1 piksel render'ı, açıklamalarla birlikte.
class Rendered {
  Rendered(this.width, this.height, this.bgra);
  final int width, height;
  final Uint8List bgra;

  /// (x, y) pikselinin rengi `0xRRGGBB`.
  int rgb(int x, int y) {
    final i = (y * width + x) * 4;
    return (bgra[i + 2] << 16) | (bgra[i + 1] << 8) | bgra[i];
  }
}

Rendered render(Uint8List pdf, int pageIndex) => withDoc(
  pdf,
  (doc) => _withPage(doc, pageIndex, (page) {
    final w = pdfium.FPDF_GetPageWidthF(page).round();
    final h = pdfium.FPDF_GetPageHeightF(page).round();
    final bmp = pdfium.FPDFBitmap_Create(w, h, 0);
    pdfium.FPDFBitmap_FillRect(bmp, 0, 0, w, h, 0xFFFFFFFF);
    pdfium.FPDF_RenderPageBitmap(bmp, page, 0, 0, w, h, 0, FPDF_ANNOT);
    final stride = pdfium.FPDFBitmap_GetStride(bmp);
    final src = pdfium.FPDFBitmap_GetBuffer(bmp)
        .cast<Uint8>()
        .asTypedList(stride * h);
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      out.setRange(y * w * 4, (y + 1) * w * 4, src, y * stride);
    }
    pdfium.FPDFBitmap_Destroy(bmp);
    return Rendered(w, h, out);
  }),
);

/// Inken'e ait olmayan (NM'siz) bir Ink açıklaması ekler.
Uint8List addForeignInk(Uint8List pdf) => withDoc(pdf, (doc) {
  final page = pdfium.FPDF_LoadPage(doc, 0);
  using((a) {
    final annot = pdfium.FPDFPage_CreateAnnot(page, FPDF_ANNOT_INK);
    final rect = a<FS_RECTF>();
    rect.ref
      ..left = 400
      ..bottom = 100
      ..right = 500
      ..top = 150;
    pdfium.FPDFAnnot_SetRect(annot, rect);
    pdfium.FPDFAnnot_SetAP(
      annot,
      FPDF_ANNOT_APPEARANCEMODE_NORMAL,
      'q 0 0 0 RG 1 w 400 100 m 500 150 l S Q'
          .toNativeUtf16(allocator: a)
          .cast(),
    );
    pdfium.FPDFPage_CloseAnnot(annot);
  });
  pdfium.FPDF_ClosePage(page);
  return saveCopy(doc);
});

int attachmentCount(Uint8List pdf) =>
    withDoc(pdf, pdfium.FPDFDoc_GetAttachmentCount);

final BytesBuilder _sink = BytesBuilder();
int _writeBlock(Pointer<FPDF_FILEWRITE_> self, Pointer<Void> data, int size) {
  _sink.add(data.cast<Uint8>().asTypedList(size));
  return 1;
}

Uint8List saveCopy(FPDF_DOCUMENT doc) {
  final fw = calloc<FPDF_FILEWRITE_>();
  fw.ref.version = 1;
  fw.ref.WriteBlock =
      Pointer.fromFunction<
        Int Function(Pointer<FPDF_FILEWRITE_>, Pointer<Void>, UnsignedLong)
      >(_writeBlock, 0);
  _sink.clear();
  pdfium.FPDF_SaveAsCopy(doc, fw, FPDF_NO_INCREMENTAL);
  calloc.free(fw);
  return _sink.takeBytes();
}

/// Güvenlik işleyicisi sürümü; şifresiz dosyada -1.
int securityRevision(Uint8List pdf) =>
    withDoc(pdf, pdfium.FPDF_GetSecurityHandlerRevision);
