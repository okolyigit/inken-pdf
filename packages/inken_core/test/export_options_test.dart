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
}
