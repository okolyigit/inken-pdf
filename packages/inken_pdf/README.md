# inken_pdf

Inken PDF'in PDF motoru. Uygulama PDF'e yalnızca bu paket üzerinden erişir.

- Görüntüleme: pdfrx (`InkenPdfViewer`, `InkenViewerController`, `PageThumbnail`).
- Yazma / okuma: PDFium (`writeInkenPdf`, `readInkenPdf`, `writeFlattenedPdf`). Fonksiyonlar senkron ve bayt-girdi → bayt-çıktıdır; uygulamada pdfrx'in PDFium worker isolate'inde çalışır (`inken_file.dart`).
- `pdfrx` ve `pdfium_dart` tam sürümle sabittir; güncelleme gidiş-dönüş testleriyle doğrulanır.

```sh
flutter test        # PDFium testleri: libpdfium.so derlemeden bulunur
INKEN_TEST_OUT=/tmp/out flutter test   # çıktı PDF'lerini diske yazar
```
