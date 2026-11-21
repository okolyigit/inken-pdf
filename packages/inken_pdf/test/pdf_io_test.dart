// Kayıt / yükleme gidiş-dönüş testleri (gerçek PDFium ile).
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import 'pdfium_test_helper.dart';

const _red = 0xFFD32F2F;

/// `INKEN_TEST_OUT=<klasör>` verilirse çıktı PDF'leri oraya yazılır
/// (Poppler / Adobe / Firefox ile elle ya da CI'da görsel kontrol için).
void _dump(String name, Uint8List pdf) {
  final dir = Platform.environment['INKEN_TEST_OUT'];
  if (dir == null) return;
  File('$dir/$name').writeAsBytesSync(pdf);
}

Stroke _pen(String id, List<InkPoint> pts, {int color = _red}) =>
    Stroke(id: id, tool: InkTool.pen, color: color, width: 3, points: pts);

/// Fixture için her öğe türünden birer tane içeren model.
InkenDocument _richDocument(Uint8List pdf) {
  final doc = InkenDocument.forPdf(pageSizes(pdf));
  final first = doc.pages.first.copyWith(
    items: [
      _pen('pen-const', const [InkPoint(72, 100), InkPoint(150, 120)]),
      _pen('pen-pressure', const [
        InkPoint(72, 150, 0.2),
        InkPoint(100, 160, 0.6),
        InkPoint(130, 150, 1),
      ]),
      _pen('dot', const [InkPoint(200, 200)]),
      const Stroke(
        id: 'hl',
        tool: InkTool.highlighter,
        color: 0x66FFEB3B,
        width: 16,
        points: [InkPoint(72, 60), InkPoint(300, 60)],
      ),
      for (final k in ShapeKind.values)
        Shape(
          id: 'shape-${k.name}',
          kind: k,
          color: 0xFF1565C0,
          width: 2,
          x1: 80,
          y1: 300.0 + 60 * k.index,
          x2: 240,
          y2: 340.0 + 60 * k.index,
        ),
    ],
  );
  return doc.copyWith(pages: [first, ...doc.pages.skip(1)]);
}

void main() {
  // Grup gövdeleri (fixture okuma) testlerden önce çalışır.
  setUpPdfium();

  group('düz PDF', () {
    test('inken.json yok: görüntüleme baytları dosyanın kendisi', () {
      final src = fixture('two_pages.pdf');
      final r = readInkenPdf(src);
      expect(r.inkenJson, isNull);
      expect(r.pageCount, 2);
      expect(identical(r.displayPdf, src), isTrue);
      expect(r.isProtected, isFalse);
    });

    test('bozuk bayt FormatException', () {
      expect(
        () => readInkenPdf(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('yeni boş PDF', () {
    test('tek A4 sayfa, düz PDF olarak okunur, sayfa beyaz', () {
      final pdf = createBlankPdf(a4Portrait);
      final r = readInkenPdf(pdf);
      expect(r.inkenJson, isNull);
      expect(r.pageCount, 1);
      expect(r.isProtected, isFalse);
      final size = pageSizes(pdf).single;
      expect(size.width, closeTo(a4Portrait.width, 0.01));
      expect(size.height, closeTo(a4Portrait.height, 0.01));
      final page = render(pdf, 0);
      expect(page.rgb(page.width ~/ 2, page.height ~/ 2), 0xFFFFFF);
    });

    test('verilen boyut kullanılır; geçersiz boyut reddedilir', () {
      final size = pageSizes(createBlankPdf((width: 842, height: 595))).single;
      expect(size.width, closeTo(842, 0.01));
      expect(size.height, closeTo(595, 0.01));
      expect(
        () => createBlankPdf((width: 0, height: 100)),
        throwsArgumentError,
      );
    });

    test('çizimle kaydet → aç gidiş-dönüş', () {
      final pdf = createBlankPdf(a4Portrait);
      final base = InkenDocument.forPdf(pageSizes(pdf));
      final model = base.copyWith(
        pages: [
          base.pages.single.copyWith(
            items: [
              _pen('p', const [InkPoint(72, 100), InkPoint(150, 120)]),
            ],
          ),
        ],
      );
      final saved = writeInkenPdf((pdf, encodeInkenDocument(model)));
      final r = readInkenPdf(saved.pdf);
      expect(r.pageCount, 1);
      expect(r.inkenJson, saved.inkenJson);
      expect(
        decodeInkenDocument(r.inkenJson!).pages.single.items,
        hasLength(1),
      );
    });
  });

  group('gidiş-dönüş', () {
    final src = fixture('two_pages.pdf');
    final model = _richDocument(src);
    late InkenWriteResult saved;

    setUpAll(() {
      saved = writeInkenPdf((src, encodeInkenDocument(model)));
      _dump('rich.pdf', saved.pdf);
    });

    test('model → kaydet → aç → model eşit', () {
      final r = readInkenPdf(saved.pdf);
      expect(r.inkenJson, saved.inkenJson);
      final loaded = decodeInkenDocument(r.inkenJson!);
      // inken.json 1/1000 pt'ye yuvarlıyor; karşılaştırma yuvarlanmış modelle.
      expect(loaded, decodeInkenDocument(encodeInkenDocument(model)));
      expect(r.pageCount, 2);
      expect(saved.skippedItems, 0);
    });

    test('her öğe için bir açıklama: doğru tür, /NM ve görünüm akışı', () {
      final annots = listAnnotations(saved.pdf);
      final items = model.pages.first.items;
      expect(annots, hasLength(items.length));
      expect(annots.map((a) => a.name).toSet(), {
        for (final i in items) '$inkenAnnotationPrefix${i.id}',
      });
      expect(annots.every((a) => a.hasAp && a.page == 0), isTrue);
      int subtypeOf(String id) =>
          annots.firstWhere((a) => a.name == 'inken:$id').subtype;
      expect(subtypeOf('pen-pressure'), FPDF_ANNOT_INK);
      expect(subtypeOf('shape-line'), FPDF_ANNOT_INK);
      expect(subtypeOf('shape-arrow'), FPDF_ANNOT_INK);
      expect(subtypeOf('shape-rectangle'), FPDF_ANNOT_SQUARE);
      expect(subtypeOf('shape-ellipse'), FPDF_ANNOT_CIRCLE);
      expect(subtypeOf('shape-coordinate'), FPDF_ANNOT_INK);
      expect(attachmentCount(saved.pdf), 1);
    });

    test('yeniden kayıt: açıklama ve ek çoğalmaz', () {
      final again = writeInkenPdf((saved.pdf, saved.inkenJson));
      final third = writeInkenPdf((again.pdf, again.inkenJson));
      expect(
        listAnnotations(third.pdf),
        hasLength(model.pages[0].items.length),
      );
      expect(attachmentCount(third.pdf), 1);
      expect(readInkenPdf(third.pdf).inkenJson, saved.inkenJson);
    });

    test('silinen öğenin açıklaması da silinir', () {
      final loaded = decodeInkenDocument(saved.inkenJson);
      final fewer = loaded.copyWith(
        pages: [
          loaded.pages[0].copyWith(
            items: loaded.pages[0].items.take(2).toList(),
          ),
          loaded.pages[1],
        ],
      );
      final r = writeInkenPdf((saved.pdf, encodeInkenDocument(fewer)));
      expect(listAnnotations(r.pdf), hasLength(2));
    });

    test('görüntüleme kopyası Inken açıklamalarını gizler', () {
      final r = readInkenPdf(saved.pdf);
      expect(listAnnotations(r.displayPdf), isEmpty);
      // Kopya, çizimsiz orijinalle piksel piksel aynı.
      expect(render(r.displayPdf, 0).bgra, render(src, 0).bgra);
      expect(render(saved.pdf, 0).bgra, isNot(render(src, 0).bgra));
    });

    test('başkasının açıklamasına dokunulmaz', () {
      final foreign = addForeignInk(saved.pdf);
      final r = writeInkenPdf((foreign, saved.inkenJson));
      final annots = listAnnotations(r.pdf);
      expect(annots.where((a) => a.name.isEmpty), hasLength(1));
      // Gizleme de yalnızca kendi açıklamalarımızı kaldırır.
      expect(listAnnotations(readInkenPdf(r.pdf).displayPdf), hasLength(1));
    });

    test('font verilmezse metin yazılmaz, sayılır', () {
      final withText = model.copyWith(
        pages: [
          model.pages[0].copyWith(
            items: const [
              TextItem(
                id: 't',
                text: 'x',
                color: 0xFF000000,
                fontSize: 14,
                x: 10,
                y: 10,
                width: 20,
                height: 20,
              ),
            ],
          ),
          model.pages[1],
        ],
      );
      final r = writeInkenPdf((src, encodeInkenDocument(withText)));
      expect(r.skippedItems, 1);
      expect(listAnnotations(r.pdf), isEmpty);
      // Model yine de korunur.
      expect(decodeInkenDocument(r.inkenJson).pages[0].items, hasLength(1));
    });
  });

  group('metin (harf şekilleriyle)', () {
    final src = fixture('two_pages.pdf');
    final fontBytes = File('../../apps/inken/assets/fonts/DejaVuSans.ttf')
        .readAsBytesSync();
    final font = TextFont.parse(fontBytes);
    final base = InkenDocument.forPdf(pageSizes(src));
    final text = measureTextItem(
      font,
      const TextItem(
        id: 'yazi',
        text: 'Çöz: √x ≤ 2\nİyi şanslar',
        color: 0xFFD42A3F,
        fontSize: 28,
        x: 60,
        y: 400,
        width: 0,
        height: 0,
      ),
    );
    final model = base.copyWith(
      pages: [
        base.pages[0].copyWith(items: [text]),
        base.pages[1],
      ],
    );
    late InkenWriteResult saved;

    setUpAll(() {
      saved = writeInkenPdf((src, encodeInkenDocument(model)), fontBytes);
      _dump('text', saved.pdf);
    });

    test('Stamp olarak yazılır, atlanmaz; model aynen gidip gelir', () {
      expect(saved.skippedItems, 0);
      final annots = listAnnotations(saved.pdf);
      expect(annots, hasLength(1));
      expect(annots.single.subtype, 13); // FPDF_ANNOT_STAMP
      expect(annots.single.name, 'inken:yazi');
      expect(annots.single.hasAp, isTrue);
      expect(decodeInkenDocument(saved.inkenJson), model);
    });

    test('font gömülmez: dosya yalnızca birkaç KB büyür', () {
      final plain = writeInkenPdf((src, encodeInkenDocument(base)));
      expect(saved.pdf.length - plain.pdf.length, lessThan(40 * 1024));
    });

    test('kırmızı metin kutusunda görünür; görüntüleme kopyasında yok', () {
      final r = render(saved.pdf, 0);
      // Sayfa uzayı (pt) = piksel (72 dpi render); kutunun içinde kırmızı.
      var red = 0;
      for (var y = text.y.floor(); y < (text.y + text.height).ceil(); y++) {
        for (var x = text.x.floor(); x < (text.x + text.width).ceil(); x++) {
          final c = r.rgb(x, y);
          if ((c >> 16) > 0xB0 && ((c >> 8) & 0xFF) < 0x80) red++;
        }
      }
      expect(red, greaterThan(200));
      // Kutunun dışında, hemen sağında kırmızı yok.
      final outside = r.rgb(
        (text.x + text.width + 20).round(),
        text.y.round() + 10,
      );
      expect(outside, 0xFFFFFF);
      expect(
        render(readInkenPdf(saved.pdf).displayPdf, 0).bgra,
        render(src, 0).bgra,
      );
    });

    test('düzleştirilmiş dışa aktarmada sayfaya gömülür', () {
      final flat = writeFlattenedPdf((
        src,
        encodeInkenDocument(model),
      ), fontBytes);
      expect(flat.skippedItems, 0);
      expect(listAnnotations(flat.pdf), isEmpty);
      expect(render(flat.pdf, 0).bgra, render(saved.pdf, 0).bgra);
    });
  });

  group('eklenen sayfalar', () {
    final src = fixture('two_pages.pdf');

    test('siyah ve saman kâğıdı sayfa: zemin rengi sayfa içeriğinde', () {
      final base = InkenDocument.forPdf(pageSizes(src));
      final doc = base.copyWith(
        pages: [
          base.pages[0],
          newPageLike(base, 0, PageTemplate.grid, color: PageColor.black),
          newPageLike(base, 0, PageTemplate.blank, color: PageColor.straw),
          base.pages[1],
        ],
      );
      final r = writeInkenPdf((src, encodeInkenDocument(doc)));
      _dump('colored-pages.pdf', r.pdf);
      final read = readInkenPdf(r.pdf);
      expect(read.pageCount, 4);
      final saved = decodeInkenDocument(r.inkenJson);
      expect(saved.pages[1].color, PageColor.black);
      expect(saved.pages[2].color, PageColor.straw);
      int at(int page, double fx, double fy) {
        final img = render(read.displayPdf, page);
        return img.rgb((img.width * fx).round(), (img.height * fy).round());
      }

      // Kareler arasında zemin, kenarda zemin; saman kâğıdında her yer.
      expect(at(1, 0.003, 0.5), pageColorArgb(PageColor.black) & 0xFFFFFF);
      expect(at(2, 0.5, 0.5), pageColorArgb(PageColor.straw) & 0xFFFFFF);
      // Kareli siyah sayfada çizgiler zeminden açık.
      final img = render(read.displayPdf, 1);
      var light = 0;
      for (var i = 0; i < img.bgra.length; i += 4) {
        if (img.bgra[i] > 0x30) light++;
      }
      expect(light, greaterThan(1000));
      // Görüntüleme kopyası da aynı düzeni üretir.
      final shown = arrangeDisplayPdf((src, encodeInkenDocument(doc)));
      final s = render(shown, 2);
      expect(
        s.rgb(s.width ~/ 2, s.height ~/ 2),
        pageColorArgb(PageColor.straw) & 0xFFFFFF,
      );
    });

    test(
      'araya kareli sayfa: dosyada gerçek sayfa, sıralar yeniden numaralı',
      () {
        final base = InkenDocument.forPdf(pageSizes(src));
        final size = base.pages.first;
        final doc = base.copyWith(
          pages: [
            base.pages[0],
            PageLayer(
              template: PageTemplate.grid,
              width: size.width,
              height: size.height,
              items: [
                _pen('on-grid', const [InkPoint(50, 50), InkPoint(100, 100)]),
              ],
            ),
            base.pages[1],
          ],
        );
        final r = writeInkenPdf((src, encodeInkenDocument(doc)));
        _dump('inserted.pdf', r.pdf);
        final read = readInkenPdf(r.pdf);
        expect(read.pageCount, 3);
        final saved = decodeInkenDocument(r.inkenJson);
        expect(saved.pages.map((p) => p.sourceIndex), [0, 1, 2]);
        expect(saved.pages[1].template, PageTemplate.grid);
        expect(listAnnotations(r.pdf).single.page, 1);
        // Kareli zemin sayfa içeriğinde: gizlenmiş kopyada da görünür.
        final shown = render(read.displayPdf, 1);
        var nonWhite = 0;
        for (var i = 0; i < shown.bgra.length; i += 4) {
          if (shown.bgra[i] != 0xFF) nonWhite++;
        }
        expect(nonWhite, greaterThan(1000));

        // Yeniden kayıtta sayfa tekrar eklenmez.
        final again = writeInkenPdf((r.pdf, r.inkenJson));
        expect(readInkenPdf(again.pdf).pageCount, 3);
      },
    );

    test('her şablon yazılabiliyor', () {
      final base = InkenDocument.forPdf(pageSizes(src));
      for (final t in PageTemplate.values) {
        final doc = base.copyWith(
          pages: [
            PageLayer(template: t, width: 300, height: 400),
            ...base.pages,
          ],
        );
        final r = writeInkenPdf((src, encodeInkenDocument(doc)));
        expect(readInkenPdf(r.pdf).pageCount, 3, reason: t.name);
      }
    });

    test('koordinat düzleminde eksenler kare çizgilerinin üstünde', () {
      final base = InkenDocument.forPdf(pageSizes(src));
      // 300 × 400: sayfa ortası 1 cm'nin katı değil.
      final doc = base.copyWith(
        pages: [
          PageLayer(template: PageTemplate.coordinate, width: 300, height: 400),
          ...base.pages,
        ],
      );
      final r = writeInkenPdf((src, encodeInkenDocument(doc)));
      final paths = _pathLines(r.pdf, 0);
      // İlki kare çizgileri, ikincisi eksenler.
      expect(paths, hasLength(2));
      final (gridX, gridY) = paths[0];
      final (axisX, axisY) = paths[1];
      expect(axisX, hasLength(1));
      expect(axisY, hasLength(1));
      expect(axisX.single, closeTo(150, 0.01));
      expect(axisY.single, closeTo(200, 0.01));
      bool onGrid(List<double> lines, double v) =>
          lines.any((l) => (l - v).abs() < 0.01);
      expect(onGrid(gridX, axisX.single), isTrue, reason: '$gridX');
      expect(onGrid(gridY, axisY.single), isTrue, reason: '$gridY');
      // Aralık 1 cm, sayfa içinde; eksenin iki yanı simetrik.
      for (final lines in [gridX, gridY]) {
        lines.sort();
        for (var i = 1; i < lines.length; i++) {
          expect(lines[i] - lines[i - 1], closeTo(28.35, 0.01));
        }
      }
      expect(gridX.first, greaterThan(0));
      expect(gridX.last, lessThan(300));
      expect(gridX.first + gridX.last, closeTo(300, 0.01));
      expect(gridY.first + gridY.last, closeTo(400, 0.01));
    });

    test('model dosyayla uyuşmuyorsa hata', () {
      final base = InkenDocument.forPdf(pageSizes(src));
      final outside = base.copyWith(
        pages: [base.pages[0], base.pages[1].copyWith(sourceIndex: 5)],
      );
      expect(
        () => writeInkenPdf((src, encodeInkenDocument(outside))),
        throwsStateError,
      );
      final swapped = base.copyWith(pages: base.pages.reversed.toList());
      expect(
        () => writeInkenPdf((src, encodeInkenDocument(swapped))),
        throwsUnsupportedError,
      );
    });
  });

  group('döndürülmüş ve kırpılmış sayfalar', () {
    // rotated.pdf: /Rotate 0, 90, 180, 270 ve CropBox'ı kaydırılmış sayfa.
    final src = fixture('rotated.pdf');
    final sizes = pageSizes(src);

    test('çizim ekranda çizildiği yerde görünür', () {
      // Her sayfada ekran koordinatında sol üst çeyreğe yatay bir çizgi.
      final base = InkenDocument.forPdf(sizes);
      final doc = base.copyWith(
        pages: [
          for (final (i, p) in base.pages.indexed)
            p.copyWith(
              items: [
                _pen('r$i', [
                  InkPoint(p.width * 0.15, p.height * 0.2),
                  InkPoint(p.width * 0.35, p.height * 0.2),
                ]),
              ],
            ),
        ],
      );
      final saved = writeInkenPdf((src, encodeInkenDocument(doc)));
      _dump('rotated.pdf', saved.pdf);
      for (final (i, p) in sizes.indexed) {
        final img = render(saved.pdf, i);
        expect((img.width, img.height), (p.width.round(), p.height.round()));
        final hit = img.rgb((p.width * 0.25).round(), (p.height * 0.2).round());
        expect(hit, 0xD32F2F, reason: 'sayfa $i: çizgi yerinde değil');
        // Simetrik karşı köşe boş: yansıma / dönme hatası olsaydı orada çıkardı.
        final mirror = img.rgb(
          (p.width * 0.75).round(),
          (p.height * 0.8).round(),
        );
        expect(mirror, 0xFFFFFF, reason: 'sayfa $i: ters köşe');
      }
    });
  });

  group('açılış parolalı PDF', () {
    // user_password.pdf: two_pages.pdf'in parolalı kopyası (1234).
    final src = fixture('user_password.pdf');
    const pw = '1234';
    Matcher needsPassword({required bool wrong}) => throwsA(
      isA<PdfPasswordRequired>().having((e) => e.wrong, 'wrong', wrong),
    );

    test('parolasız ve yanlış parolayla açılmaz; doğruyla açılır', () {
      expect(() => readInkenPdf(src), needsPassword(wrong: false));
      expect(
        () => readInkenPdf(src, password: 'yanlış'),
        needsPassword(wrong: true),
      );
      final r = readInkenPdf(src, password: pw);
      expect(r.pageCount, 2);
      expect(r.isProtected, isTrue);
    });

    test('kayıt parolayı korur; çizimler ve inken.json geri okunur', () {
      final base = InkenDocument.forPdf(pageSizes(fixture('two_pages.pdf')));
      final model = InsertPage(1, newPageLike(base, 0, PageTemplate.grid))
          .apply(
            AddItems(0, [
              _pen('a', const [InkPoint(72, 100), InkPoint(150, 120)]),
            ]).apply(base),
          );
      final saved = writeInkenPdf(
        (src, encodeInkenDocument(model)),
        null,
        const {},
        pw,
      );
      expect(() => readInkenPdf(saved.pdf), needsPassword(wrong: false));
      final back = readInkenPdf(saved.pdf, password: pw);
      expect(back.pageCount, 3);
      expect(back.inkenJson, isNotNull);
      final m = decodeInkenDocument(back.inkenJson!);
      expect(m.pages[0].items, hasLength(1));
      expect(m.pages[1].template, PageTemplate.grid);
      // Yeniden kayıt da parolayla.
      final again = writeInkenPdf(
        (saved.pdf, saved.inkenJson),
        null,
        const {},
        pw,
      );
      expect(readInkenPdf(again.pdf, password: pw).pageCount, 3);
    });

    test('görüntüleme kopyası ve düzleştirilmiş çıktı da parolalı', () {
      final base = InkenDocument.forPdf(pageSizes(fixture('two_pages.pdf')));
      final model = RotatePages(base, [0], 1).apply(base);
      final json = encodeInkenDocument(pageLayoutOnly(model));
      final display = arrangeDisplayPdf((src, json), pw);
      expect(() => readInkenPdf(display), needsPassword(wrong: false));
      expect(readInkenPdf(display, password: pw).pageCount, 2);
      final flat = writeFlattenedPdf(
        (src, encodeInkenDocument(model)),
        null,
        const {},
        pw,
      );
      expect(() => readInkenPdf(flat.pdf), needsPassword(wrong: false));
      expect(readInkenPdf(flat.pdf, password: pw).inkenJson, isNull);
    });
  });

  group('sayfa döndürme', () {
    test('çizim sayfayla döner; kayıtta /Rotate değişir, model sıfırlanır', () {
      final src = fixture('two_pages.pdf');
      final base = InkenDocument.forPdf(pageSizes(src));
      final p0 = base.pages[0];
      // Döndürmeden önce sol üst çeyrekte yatay çizgi.
      final drawn = AddItems(0, [
        _pen('a', [
          InkPoint(p0.width * 0.15, p0.height * 0.2),
          InkPoint(p0.width * 0.35, p0.height * 0.2),
        ]),
      ]).apply(base);
      final model = RotatePages(drawn, [0], 1).apply(drawn);
      final r = writeInkenPdf((src, encodeInkenDocument(model)));
      _dump('rotated_page.pdf', r.pdf);
      final sizes = pageSizes(r.pdf);
      expect(sizes[0].width, closeTo(p0.height, 0.01));
      expect(sizes[0].height, closeTo(p0.width, 0.01));
      expect(sizes[1].width, closeTo(base.pages[1].width, 0.01));
      // Saat yönünde: sol üst çeyrek sağ üst çeyreğe, çizgi dikey.
      final img = render(r.pdf, 0);
      final w = sizes[0].width;
      final h = sizes[0].height;
      expect(img.rgb((w * 0.8).round(), (h * 0.25).round()), 0xD32F2F);
      expect(img.rgb((w * 0.2).round(), (h * 0.75).round()), 0xFFFFFF);
      final saved = decodeInkenDocument(r.inkenJson);
      expect(saved.pages.every((p) => p.rotation == null), isTrue);
      expect(saved.pages[0].width, closeTo(p0.height, 0.01));
      // Yeniden kayıt bir daha döndürmez.
      final again = writeInkenPdf((r.pdf, r.inkenJson));
      expect(pageSizes(again.pdf)[0].width, closeTo(p0.height, 0.01));
      expect(
        render(again.pdf, 0).rgb((w * 0.8).round(), (h * 0.25).round()),
        0xD32F2F,
      );
    });

    test('zaten döndürülmüş sayfalara eklenir; görüntüleme kopyası aynı', () {
      final src = fixture('rotated.pdf');
      final base = InkenDocument.forPdf(pageSizes(src));
      final all = [for (var i = 0; i < base.pages.length; i++) i];
      final model = RotatePages(base, all, -1).apply(base);
      final r = writeInkenPdf((src, encodeInkenDocument(model)));
      final display = arrangeDisplayPdf((
        readInkenPdf(src).displayPdf,
        encodeInkenDocument(pageLayoutOnly(model)),
      ));
      for (final out in [r.pdf, display]) {
        final sizes = pageSizes(out);
        for (final (i, p) in model.pages.indexed) {
          expect(sizes[i].width, closeTo(p.width, 0.01), reason: '$i');
          expect(sizes[i].height, closeTo(p.height, 0.01), reason: '$i');
        }
      }
    });

    test('eklenen sayfa döndürülünce yeni yönde oluşur', () {
      final src = fixture('two_pages.pdf');
      final base = InkenDocument.forPdf(pageSizes(src));
      final withPage = InsertPage(
        1,
        newPageLike(base, 0, PageTemplate.lined),
      ).apply(base);
      final model = RotatePages(withPage, [1], 1).apply(withPage);
      final r = writeInkenPdf((src, encodeInkenDocument(model)));
      final s = pageSizes(r.pdf)[1];
      expect(s.width, closeTo(base.pages[0].height, 0.01));
      expect(s.height, closeTo(base.pages[0].width, 0.01));
    });
  });

  group('düzleştirilmiş dışa aktarma', () {
    final src = fixture('two_pages.pdf');
    final model = _richDocument(src);
    final json = encodeInkenDocument(model);
    late InkenWriteResult saved;
    late InkenExportResult flat;

    setUpAll(() {
      saved = writeInkenPdf((src, json));
      flat = writeFlattenedPdf((src, json));
      _dump('flattened.pdf', flat.pdf);
    });

    /// Farklı piksel sayısı (kanal farkı [tolerance]'tan büyük olanlar).
    int differing(Rendered a, Rendered b, {int tolerance = 8}) {
      var n = 0;
      for (var i = 0; i < a.bgra.length; i += 4) {
        for (var c = 0; c < 3; c++) {
          if ((a.bgra[i + c] - b.bgra[i + c]).abs() > tolerance) {
            n++;
            break;
          }
        }
      }
      return n;
    }

    test('açıklama ve inken.json kalmaz; dosya düz PDF olarak açılır', () {
      expect(listAnnotations(flat.pdf), isEmpty);
      expect(attachmentCount(flat.pdf), 0);
      final r = readInkenPdf(flat.pdf);
      expect(r.inkenJson, isNull);
      expect(r.pageCount, 2);
      expect(flat.skippedItems, 0);
    });

    test('açıklamalı kayıtla aynı görünür', () {
      expect(
        differing(render(flat.pdf, 0), render(src, 0)),
        greaterThan(1000),
        reason: 'çizimler sayfa içeriğinde olmalı',
      );
      for (var i = 0; i < 2; i++) {
        final a = render(flat.pdf, i);
        // Kenar yumuşatma farkları dışında aynı.
        expect(
          differing(a, render(saved.pdf, i)),
          lessThan(a.width * a.height ~/ 1000),
          reason: 'sayfa $i',
        );
      }
    });

    test('Inken dosyasından da: eski açıklama ve ek kaldırılır', () {
      final again = writeFlattenedPdf((saved.pdf, saved.inkenJson));
      expect(listAnnotations(again.pdf), isEmpty);
      expect(attachmentCount(again.pdf), 0);
      expect(differing(render(again.pdf, 0), render(flat.pdf, 0)), 0);
    });

    test('başkasının açıklaması da içeriğe gömülür', () {
      final foreign = addForeignInk(src);
      final r = writeFlattenedPdf((foreign, json));
      expect(listAnnotations(r.pdf), isEmpty);
      expect(
        differing(render(r.pdf, 0), render(flat.pdf, 0)),
        greaterThan(0),
        reason: 'yabancı çizgi görünmeli',
      );
    });
  });

  group('sayfa silme ve görüntüleme düzeni', () {
    // mixed_sizes.pdf: sayfalar farklı boyutta; silinenin hangisi olduğu
    // boyuttan anlaşılır.
    late Uint8List src;
    late InkenDocument base;
    setUp(() {
      src = fixture('mixed_sizes.pdf');
      base = InkenDocument.forPdf(pageSizes(src));
    });

    test('silinen kaynak sayfa dosyadan çıkar; çizimler kalan sayfada', () {
      expect(base.pages.length, greaterThanOrEqualTo(3));
      final ink = _pen('a', const [InkPoint(50, 50), InkPoint(90, 90)]);
      final model = base.copyWith(
        pages: [
          base.pages[0],
          base.pages[2].copyWith(items: [ink]),
          ...base.pages.skip(3),
        ],
      );
      final r = writeInkenPdf((src, encodeInkenDocument(model)));
      _dump('deleted_page.pdf', r.pdf);
      final sizes = pageSizes(r.pdf);
      expect(sizes.length, base.pages.length - 1);
      expect(sizes[1].width, closeTo(base.pages[2].width, 0.01));
      expect(sizes[1].height, closeTo(base.pages[2].height, 0.01));
      final annots = listAnnotations(r.pdf);
      expect(annots.single.page, 1);
      final saved = decodeInkenDocument(r.inkenJson);
      expect(saved.pages.map((p) => p.sourceIndex), [
        for (var i = 0; i < sizes.length; i++) i,
      ]);
      // Yeniden kayıt: kaynak artık kaydedilen dosya, düzen değişmez.
      final again = writeInkenPdf((r.pdf, r.inkenJson));
      expect(pageSizes(again.pdf).length, sizes.length);
    });

    test(
      'sil ve araya ekle birlikte; yabancı açıklama silinen sayfayla gider',
      () {
        final foreign = addForeignInk(src); // ilk sayfada
        final model = base.copyWith(
          pages: [
            newPageLike(base, 1, PageTemplate.grid),
            ...base.pages.skip(1),
          ],
        );
        final r = writeInkenPdf((foreign, encodeInkenDocument(model)));
        final sizes = pageSizes(r.pdf);
        expect(sizes.length, base.pages.length);
        expect(sizes[0].width, closeTo(base.pages[1].width, 0.01));
        expect(listAnnotations(r.pdf), isEmpty);
      },
    );

    test('görüntüleme kopyası modelin düzenine gelir', () {
      final read = readInkenPdf(src);
      final model = base.copyWith(
        pages: [
          base.pages[0],
          newPageLike(base, 0, PageTemplate.lined),
          ...base.pages.skip(2),
        ],
      );
      final display = arrangeDisplayPdf((
        read.displayPdf,
        encodeInkenDocument(pageLayoutOnly(model)),
      ));
      final sizes = pageSizes(display);
      expect(sizes.length, model.pages.length);
      for (final (i, p) in model.pages.indexed) {
        expect(sizes[i].width, closeTo(p.width, 0.01), reason: '$i');
        expect(sizes[i].height, closeTo(p.height, 0.01), reason: '$i');
      }
      // Kopyada gömülü model yok; açıklama yok.
      expect(listAnnotations(display), isEmpty);
    });
  });
}

/// Sayfa [index]'teki her yol nesnesinin düz çizgileri: dikeylerin x'leri,
/// yatayların y'leri (PDF uzayı). Yollar yalnızca MoveTo + LineTo çiftleri.
List<(List<double>, List<double>)> _pathLines(Uint8List pdf, int index) =>
    withDoc(pdf, (doc) {
      final p = pdfium;
      final page = p.FPDF_LoadPage(doc, index);
      try {
        return using((a) {
          final x = a<Float>(), y = a<Float>();
          final result = <(List<double>, List<double>)>[];
          for (var i = 0; i < p.FPDFPage_CountObjects(page); i++) {
            final obj = p.FPDFPage_GetObject(page, i);
            if (p.FPDFPageObj_GetType(obj) != FPDF_PAGEOBJ_PATH) continue;
            final pts = <(double, double)>[];
            for (var j = 0; j < p.FPDFPath_CountSegments(obj); j++) {
              p.FPDFPathSegment_GetPoint(
                p.FPDFPath_GetPathSegment(obj, j),
                x,
                y,
              );
              pts.add((x.value, y.value));
            }
            final xs = <double>[], ys = <double>[];
            for (var j = 0; j + 1 < pts.length; j += 2) {
              final (ax, ay) = pts[j];
              final (bx, by) = pts[j + 1];
              if ((ax - bx).abs() < 1e-3) xs.add(ax);
              if ((ay - by).abs() < 1e-3) ys.add(ay);
            }
            result.add((xs, ys));
          }
          return result;
        });
      } finally {
        p.FPDF_ClosePage(page);
      }
    });
