import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

const _flip = PdfAffine.flipY(842);

/// Akıştaki `x y m` / `x y l` / `… x y c` uç noktalarını sırayla toplar.
List<(double, double)> _endpoints(String stream) {
  final out = <(double, double)>[];
  for (final line in stream.split('\n')) {
    final parts = line.split(' ');
    final op = parts.last;
    if (op == 'm' || op == 'l' || op == 'c') {
      out.add((
        double.parse(parts[parts.length - 3]),
        double.parse(parts[parts.length - 2]),
      ));
    }
  }
  return out;
}

int _count(String stream, String op) =>
    stream.split('\n').where((l) => l == op || l.endsWith(' $op')).length;

void main() {
  group('pdfNum', () {
    test('sondaki sıfırlar ve -0 atılır', () {
      expect(pdfNum(1.0), '1');
      expect(pdfNum(1.5), '1.5');
      expect(pdfNum(0.12345), '0.123');
      expect(pdfNum(-0.0001), '0');
      expect(pdfNum(-2.25), '-2.25');
      expect(pdfNum(100), '100');
    });
  });

  group('PdfAffine', () {
    test('flipY: sol üst orijin → sol alt orijin', () {
      expect(_flip.apply(0, 0), (0.0, 842.0));
      expect(_flip.apply(100, 42), (100.0, 800.0));
    });
  });

  group('çizgi', () {
    test('sabit kalınlıklı kalem: tek yol, dönüştürülmüş uçlar', () {
      const s = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        points: [InkPoint(10, 10), InkPoint(20, 20), InkPoint(30, 10)],
      );
      final ap = appearanceFor(s, _flip)!;
      expect(ap.kind, AnnotationKind.ink);
      expect(_count(ap.stream, 'S'), 1);
      expect(ap.stream, isNot(contains('/GS gs')));
      // Kalınlık = penWidthAt(2, 0.5)
      expect(ap.stream, contains('${pdfNum(penWidthAt(2, 0.5))} w'));
      final e = _endpoints(ap.stream);
      expect(e.first, (10.0, 832.0));
      expect(e.last, (30.0, 832.0));
      // Ara uç: 1. ve 2. noktanın ortası (ekrandaki eğriyle aynı).
      expect(e[1], (25.0, 827.0));
      expect(ap.inkList, [
        [10.0, 832.0, 20.0, 822.0, 30.0, 832.0],
      ]);
    });

    test('basınçlı kalem: her parça kendi kalınlığıyla ayrı yol', () {
      const s = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 2,
        points: [InkPoint(0, 0, 0.2), InkPoint(10, 0, 0.8), InkPoint(20, 0, 1)],
      );
      final ap = appearanceFor(s, _flip)!;
      expect(_count(ap.stream, 'S'), 2);
      expect(ap.stream, contains('${pdfNum(penWidthAt(2, 0.5))} w'));
      expect(ap.stream, contains('${pdfNum(penWidthAt(2, 0.9))} w'));
    });

    test('fosforlu: yarı saydam, basınçtan bağımsız sabit kalınlık', () {
      const s = Stroke(
        id: 'h',
        tool: InkTool.highlighter,
        color: 0x66FFEB3B,
        width: 16,
        points: [InkPoint(0, 100, 0.2), InkPoint(50, 100, 0.9)],
      );
      final ap = appearanceFor(s, _flip)!;
      expect(ap.isTranslucent, isTrue);
      expect(ap.stream, startsWith('q\n/GS gs\n'));
      expect(ap.stream, contains('16 w'));
      expect(_count(ap.stream, 'S'), 1);
      expect(ap.stream, endsWith('Q'));
    });

    test('tek nokta: dolu daire', () {
      const s = Stroke(
        id: 'd',
        tool: InkTool.pen,
        color: 0xFF000000,
        width: 4,
        points: [InkPoint(50, 50)],
      );
      final ap = appearanceFor(s, _flip)!;
      expect(_count(ap.stream, 'f'), 1);
      expect(_count(ap.stream, 'S'), 0);
      final r = penWidthAt(4, 0.5) / 2;
      expect(ap.rect.left, closeTo(50 - r - 1, 1e-9));
      expect(ap.rect.top, closeTo(792 + r + 1, 1e-9));
    });

    test('sınır kutusu çizgi kalınlığını ve 1 pt payı içerir', () {
      const s = Stroke(
        id: 'h',
        tool: InkTool.highlighter,
        color: 0x66FFEB3B,
        width: 10,
        points: [InkPoint(100, 100), InkPoint(200, 100)],
      );
      final r = appearanceFor(s, _flip)!.rect;
      expect(r.left, 94);
      expect(r.right, 206);
      expect(r.bottom, 736);
      expect(r.top, 748);
    });

    test('renk RG ve rg olarak 0..1 aralığında', () {
      const s = Stroke(
        id: 's',
        tool: InkTool.pen,
        color: 0xFFFF0000,
        width: 2,
        points: [InkPoint(0, 0), InkPoint(1, 1)],
      );
      final ap = appearanceFor(s, _flip)!;
      expect(ap.stream, contains('1 0 0 RG\n1 0 0 rg\n'));
      expect(ap.stream, contains('1 J\n1 j\n'));
    });
  });

  group('şekil', () {
    Shape shape(ShapeKind kind) => Shape(
      id: kind.name,
      kind: kind,
      color: 0xFF2E7D32,
      width: 2,
      x1: 100,
      y1: 100,
      x2: 200,
      y2: 150,
    );

    test('dikdörtgen → Square, kapalı yol', () {
      final ap = appearanceFor(shape(ShapeKind.rectangle), _flip)!;
      expect(ap.kind, AnnotationKind.square);
      expect(ap.inkList, isEmpty);
      expect(_count(ap.stream, 'h'), 1);
      expect(_endpoints(ap.stream), [
        (100.0, 742.0),
        (200.0, 742.0),
        (200.0, 692.0),
        (100.0, 692.0),
      ]);
      expect(ap.rect, (left: 98.0, bottom: 690.0, right: 202.0, top: 744.0));
    });

    test('elips → Circle, dört eğri', () {
      final ap = appearanceFor(shape(ShapeKind.ellipse), _flip)!;
      expect(ap.kind, AnnotationKind.circle);
      expect(_count(ap.stream, 'c'), 4);
      expect(ap.rect.left, closeTo(98, 1e-9));
      expect(ap.rect.right, closeTo(202, 1e-9));
    });

    test('çizgi → Ink, tek alt liste', () {
      final ap = appearanceFor(shape(ShapeKind.line), _flip)!;
      expect(ap.kind, AnnotationKind.ink);
      expect(ap.inkList, [
        [100.0, 742.0, 200.0, 692.0],
      ]);
    });

    test('ok → Ink, gövde + iki kanat', () {
      final ap = appearanceFor(shape(ShapeKind.arrow), _flip)!;
      expect(ap.kind, AnnotationKind.ink);
      expect(ap.inkList, hasLength(3));
      expect(_count(ap.stream, 'm'), 3);
      // Kanatlar ok ucundan başlar.
      expect(ap.inkList[1].take(2), [200.0, 692.0]);
      expect(ap.inkList[2].take(2), [200.0, 692.0]);
    });
  });

  test('metin öğesi burada üretilmez', () {
    const t = TextItem(
      id: 't',
      text: 'x',
      color: 0xFF000000,
      fontSize: 14,
      x: 0,
      y: 0,
      width: 10,
      height: 10,
    );
    expect(appearanceFor(t, _flip), isNull);
  });

  test('döndürülmüş dönüşüm: noktalar ve kutu dönüşümle gider', () {
    // 90° döndürülmüş sayfa örneği: (u, v) → (v, u).
    const rot = PdfAffine(0, 1, 1, 0, 0, 0);
    const s = Stroke(
      id: 's',
      tool: InkTool.highlighter,
      color: 0x66FFEB3B,
      width: 2,
      points: [InkPoint(10, 50), InkPoint(30, 50)],
    );
    final ap = appearanceFor(s, rot)!;
    expect(ap.inkList.single, [50.0, 10.0, 50.0, 30.0]);
    expect(ap.rect, (left: 48.0, bottom: 8.0, right: 52.0, top: 32.0));
  });
}
