import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  const stroke = Stroke(
    id: 's',
    tool: InkTool.pen,
    color: 0xFF000000,
    width: 2,
    points: [InkPoint(1, 2), InkPoint(3, 4)],
  );
  // 0: dosyadan, çizimli · 1: eklenmiş, boş · 2: dosyadan, boş ·
  // 3: eklenmiş, çizimli
  final doc = InkenDocument(
    pages: [
      const PageLayer(sourceIndex: 0, width: 595, height: 842, items: [stroke]),
      const PageLayer(template: PageTemplate.grid, width: 595, height: 842),
      const PageLayer(sourceIndex: 1, width: 595, height: 842),
      const PageLayer(
        template: PageTemplate.blank,
        width: 595,
        height: 842,
        items: [stroke],
      ),
    ],
  );

  test('tümü, bu sayfa, çizimli', () {
    expect(selectExportPages(doc, ExportPageSet.all), [0, 1, 2, 3]);
    expect(selectExportPages(doc, ExportPageSet.current, current: 2), [2]);
    expect(selectExportPages(doc, ExportPageSet.current, current: 9), [3]);
    expect(selectExportPages(doc, ExportPageSet.drawn), [0, 3]);
  });

  test('aralık: verilen sıra, tekrarsız; geçersizse null', () {
    expect(selectExportPages(doc, ExportPageSet.range, range: '3-1, 2'), [
      2,
      1,
      0,
    ]);
    expect(selectExportPages(doc, ExportPageSet.range, range: '5'), isNull);
    expect(selectExportPages(doc, ExportPageSet.range, range: ''), isNull);
  });

  test('boş eklenen sayfalar atlanır, dosyadan gelen boş sayfa kalır', () {
    expect(selectExportPages(doc, ExportPageSet.all, skipBlankInserted: true), [
      0,
      2,
      3,
    ]);
    expect(
      selectExportPages(
        doc,
        ExportPageSet.current,
        current: 1,
        skipBlankInserted: true,
      ),
      isEmpty,
    );
  });

  test('çizimsiz belgede çizimli sayfa yok', () {
    final plain = InkenDocument.forPdf([(width: 595, height: 842)]);
    expect(selectExportPages(plain, ExportPageSet.drawn), isEmpty);
  });

  test('dpi seçenekleri ve varsayılan', () {
    expect(exportDpis, contains(defaultExportDpi));
  });

  group('öğrenci kopyası', () {
    final answers = InkenDocument(
      pages: [
        const PageLayer(
          sourceIndex: 0,
          width: 595,
          height: 842,
          items: [
            Stroke(
              id: 'siyah',
              tool: InkTool.pen,
              color: 0xFF1A1A1A,
              width: 2,
              points: [InkPoint(1, 2), InkPoint(3, 4)],
            ),
            TextItem(
              id: 'cevap',
              text: 'x = 4',
              color: 0x80D42A3F, // yarı saydam kırmızı
              fontSize: 24,
              x: 10,
              y: 10,
              width: 80,
              height: 30,
            ),
            ImageItem(
              id: 'resim',
              imageId: 'g',
              x: 0,
              y: 0,
              width: 10,
              height: 10,
            ),
          ],
        ),
        const PageLayer(
          sourceIndex: 1,
          width: 595,
          height: 842,
          items: [
            Shape(
              id: 'daire',
              kind: ShapeKind.ellipse,
              color: 0xFFD42A3F,
              width: 2,
              x1: 0,
              y1: 0,
              x2: 50,
              y2: 50,
            ),
          ],
        ),
      ],
    );

    test('kullanılan renkler: saydamlıksız, tekrarsız, sırayla', () {
      expect(usedColors(answers, [0, 1]), [0x1A1A1A, 0xD42A3F]);
      expect(usedColors(answers, [1]), [0xD42A3F]);
      expect(hasImages(answers, [0]), isTrue);
      expect(hasImages(answers, [1]), isFalse);
    });

    test('kırmızı gizlenir: yarı saydam metin ve şekil gider', () {
      final student = hideItems(answers, colors: {0xD42A3F});
      expect(student.pages[0].items.map((i) => i.id), ['siyah', 'resim']);
      expect(student.pages[1].items, isEmpty);
      expect(student.pages, hasLength(2), reason: 'sayfa silinmez');
    });

    test('görseller gizlenir; hiçbir şey gizlenmiyorsa aynı belge', () {
      final noImages = hideItems(answers, images: true);
      expect(noImages.pages[0].items.map((i) => i.id), ['siyah', 'cevap']);
      expect(identical(hideItems(answers), answers), isTrue);
    });

    test('gizlenmiş kopya gidiş-dönüşte bozulmaz', () {
      final student = hideItems(answers, colors: {0x1A1A1A}, images: true);
      expect(decodeInkenDocument(encodeInkenDocument(student)), student);
    });
  });
}
