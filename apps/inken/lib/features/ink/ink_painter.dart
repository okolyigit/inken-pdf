import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

import 'ink_images.dart';
import 'ink_session.dart';
import 'tool_state.dart' show imagePlaceholderColor;

/// Çizim rengini ekranda başka renge çevirir (gece modu: `nightInkColor`).
typedef InkRecolor = int Function(int argb);

/// Tek bir öğeyi sayfa uzayında çizer (tuvale ölçek dışarıdan uygulanır).
/// Metin, [font] verilirse PDF'tekiyle aynı harf şekilleriyle çizilir.
/// Görsel [images]'tan; henüz çözülmediyse yerinde soluk bir kutu.
/// [recolor] verilirse çizim renkleri ona göre çevrilir (görseller değil).
void paintItem(
  Canvas canvas,
  InkItem item, [
  TextFont? font,
  InkImages? images,
  InkRecolor? recolor,
]) {
  int col(int argb) => recolor == null ? argb : recolor(argb);
  switch (item) {
    case ImageItem():
      _paintImage(canvas, item, images);
    case Stroke():
      _paintStroke(canvas, item, col(item.color));
    case Shape():
      _paintShape(canvas, item, col(item.color));
    case TextItem():
      if (font == null) {
        _paintText(canvas, item, col(item.color));
      } else {
        canvas.drawPath(
          _textPath(item, font),
          Paint()
            ..color = Color(col(item.color))
            ..isAntiAlias = true,
        );
      }
  }
}

/// Metnin yolu; öğe değişmez olduğundan nesneye bağlı önbellekte.
final Expando<Path> _textPaths = Expando('metin yolu');

Path _textPath(TextItem t, TextFont font) {
  final cached = _textPaths[t];
  if (cached != null) return cached;
  final path = Path();
  final layout = layoutText(font, t.text, t.fontSize);
  for (final c in textOutline(font, layout, t.x, t.y)) {
    switch (c) {
      case MoveTo(:final x, :final y):
        path.moveTo(x, y);
      case LineTo(:final x, :final y):
        path.lineTo(x, y);
      case QuadTo(:final cx, :final cy, :final x, :final y):
        path.quadraticBezierTo(cx, cy, x, y);
      case ClosePath():
        path.close();
    }
  }
  return _textPaths[t] = path;
}

Paint _strokePaint(int color, double width) => Paint()
  ..color = Color(color)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _paintStroke(Canvas canvas, Stroke s, int color) {
  final pts = s.points;
  if (pts.isEmpty) return;
  final isPen = s.tool == InkTool.pen;
  if (pts.length == 1) {
    final w = isPen ? penWidthAt(s.width, pts[0].p) : s.width;
    canvas.drawCircle(
      Offset(pts[0].x, pts[0].y),
      w / 2,
      Paint()
        ..color = Color(color)
        ..isAntiAlias = true,
    );
    return;
  }
  final constant = !isPen || pts.every((p) => p.p == pts[0].p);
  if (constant) {
    // Tek yol: yarı saydam çizgide kendi üstüne binme koyulaşma yapmaz.
    final w = isPen ? penWidthAt(s.width, pts[0].p) : s.width;
    final path = Path()..moveTo(pts[0].x, pts[0].y);
    for (var i = 1; i < pts.length - 1; i++) {
      final mx = (pts[i].x + pts[i + 1].x) / 2;
      final my = (pts[i].y + pts[i + 1].y) / 2;
      path.quadraticBezierTo(pts[i].x, pts[i].y, mx, my);
    }
    path.lineTo(pts.last.x, pts.last.y);
    canvas.drawPath(path, _strokePaint(color, w));
    return;
  }
  // Değişken kalınlık: her nokta çevresindeki parça kendi kalınlığıyla.
  final paint = _strokePaint(color, s.width);
  var fromX = pts[0].x, fromY = pts[0].y;
  for (var i = 1; i < pts.length; i++) {
    final last = i == pts.length - 1;
    final toX = last ? pts[i].x : (pts[i].x + pts[i + 1].x) / 2;
    final toY = last ? pts[i].y : (pts[i].y + pts[i + 1].y) / 2;
    paint.strokeWidth = penWidthAt(s.width, (pts[i - 1].p + pts[i].p) / 2);
    final path = Path()..moveTo(fromX, fromY);
    if (last) {
      path.lineTo(toX, toY);
    } else {
      path.quadraticBezierTo(pts[i].x, pts[i].y, toX, toY);
    }
    canvas.drawPath(path, paint);
    fromX = toX;
    fromY = toY;
  }
}

void _paintShape(Canvas canvas, Shape s, int color) {
  final paint = _strokePaint(color, s.width);
  final a = Offset(s.x1, s.y1), b = Offset(s.x2, s.y2);
  switch (s.kind) {
    case ShapeKind.line:
      canvas.drawLine(a, b, paint);
    case ShapeKind.arrow:
      canvas.drawLine(a, b, paint);
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final head = arrowHeadLength(s.width);
      for (final d in [math.pi * 5 / 6, -math.pi * 5 / 6]) {
        canvas.drawLine(
          b,
          b + Offset(math.cos(angle + d), math.sin(angle + d)) * head,
          paint,
        );
      }
    case ShapeKind.rectangle:
      canvas.drawRect(Rect.fromPoints(a, b), paint);
    case ShapeKind.ellipse:
      canvas.drawOval(Rect.fromPoints(a, b), paint);
    case ShapeKind.coordinate:
      // PDF görünümüyle aynı çizgiler (`coordinatePlaneLines`).
      final lines = coordinatePlaneLines(s);
      final grid = _strokePaint(
        coordinateGridColor(color),
        coordinateGridWidth(s.width),
      );
      for (final g in lines.grid) {
        canvas.drawLine(Offset(g.x1, g.y1), Offset(g.x2, g.y2), grid);
      }
      for (final x in lines.axes) {
        canvas.drawLine(Offset(x.x1, x.y1), Offset(x.x2, x.y2), paint);
      }
  }
}

void _paintText(Canvas canvas, TextItem t, int color) {
  final painter = TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(color: Color(color), fontSize: t.fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: t.width);
  painter.paint(canvas, Offset(t.x, t.y));
  painter.dispose();
}

void _paintImage(Canvas canvas, ImageItem g, InkImages? images) {
  final dst = Rect.fromLTWH(g.x, g.y, g.width, g.height);
  final image = images?.image(g.imageId);
  if (image == null) {
    canvas.drawRect(dst, Paint()..color = const Color(imagePlaceholderColor));
    return;
  }
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst,
    Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true,
  );
}

/// Sayfaların tamamlanmış çizimlerini [ui.Picture] olarak saklar.
/// Sayfa öğe listesi değişmez olduğundan, liste nesnesi aynıysa içerik de
/// aynıdır; yalnızca değişen sayfa yeniden kaydedilir.
///
/// Bir görsel sonradan çözülünce ([InkImages.version]) sayfalar yeniden
/// kaydedilir.
class InkPictureCache {
  final Map<int, (List<InkItem>, int, InkRecolor?, ui.Picture)> _pictures =
      {};

  ui.Picture pictureFor(
    int page,
    List<InkItem> items, [
    TextFont? font,
    InkImages? images,
    InkRecolor? recolor,
  ]) {
    final version = images?.version ?? 0;
    final cached = _pictures[page];
    if (cached != null &&
        identical(cached.$1, items) &&
        cached.$2 == version &&
        cached.$3 == recolor) {
      return cached.$4;
    }
    cached?.$4.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final item in items) {
      paintItem(canvas, item, font, images, recolor);
    }
    final picture = recorder.endRecording();
    _pictures[page] = (items, version, recolor, picture);
    return picture;
  }

  void dispose() {
    for (final entry in _pictures.values) {
      entry.$4.dispose();
    }
    _pictures.clear();
  }
}

/// Görünen sayfaların çizimlerini, görüntüleyicinin o anki kaydırma ve
/// yakınlaştırmasına göre çizer.
class InkLayerPainter extends CustomPainter {
  InkLayerPainter({
    required this.geometry,
    required this.session,
    required this.cache,
    this.font,
    this.recolor,
  }) : super(
         repaint: Listenable.merge([
           geometry,
           session,
           session.live,
           session.images,
         ]),
       );

  final PageGeometry geometry;
  final InkSession session;
  final InkPictureCache cache;

  /// Metnin harf şekilleri (yoksa Flutter'ın metin çizimi).
  final TextFont? font;

  /// Gece modunda çizim renklerinin ekrandaki karşılığı.
  final InkRecolor? recolor;

  @override
  void paint(Canvas canvas, Size size) {
    if (!geometry.isReady) return;
    canvas.clipRect(Offset.zero & size);
    final pages = session.document.pages;
    final images = session.images;
    final active = session.activeItem;
    final activePage = session.activePage;
    final erasing = session.pendingErase;
    final pixel = session.pixelPreview;
    final movingRest = session.movingRest;
    final target = session.moveTarget;
    for (final view in geometry.visiblePages) {
      if (view.index >= pages.length) continue;
      final pixelHere = pixel != null && session.erasePage == view.index;
      final movingHere =
          movingRest != null && session.selectionPage == view.index;
      final editingRest = session.textEditPage == view.index
          ? session.editingRest
          : null;
      final items = pixelHere
          ? pixel
          : movingHere
          ? movingRest
          : editingRest ?? pages[view.index].items;
      final hasActive = active != null && activePage == view.index;
      final targetHere = target != null && target.page == view.index;
      if (items.isEmpty && !hasActive && !movingHere && !targetHere) continue;
      canvas.save();
      canvas.clipRect(view.rect);
      canvas.translate(view.rect.left, view.rect.top);
      canvas.scale(view.scale);
      if (pixelHere) {
        // Piksel silgisi: bölünmüş öğeler doğrudan çizilir.
        for (final item in items) {
          paintItem(canvas, item, font, images, recolor);
        }
      } else if (erasing.isNotEmpty && session.erasePage == view.index) {
        // Silinmek üzere olanlar soluk görünür.
        for (final item in items) {
          if (erasing.contains(item.id)) {
            canvas.saveLayer(null, Paint()..color = const Color(0x40000000));
            paintItem(canvas, item, font, images, recolor);
            canvas.restore();
          } else {
            paintItem(canvas, item, font, images, recolor);
          }
        }
      } else if (items.isNotEmpty) {
        canvas.drawPicture(cache.pictureFor(view.index, items, font, images, recolor));
      }
      if (movingHere && target == null) {
        // Taşınanlar kaydırılarak, geri kalanı önbellekten.
        final (:dx, :dy) = session.moveOffset;
        canvas.save();
        canvas.translate(dx, dy);
        // Boyutlandırma: çizgi kalınlığı da ölçeklendiğinden tuval ölçeği
        // sonucu gösterir (kenar tutamağında eksen eksen).
        if (session.resizeTransform case (
          :final ax,
          :final ay,
          :final sx,
          :final sy,
        )) {
          canvas.translate(ax, ay);
          canvas.scale(sx, sy);
          canvas.translate(-ax, -ay);
        }
        for (final item in session.movingItems!) {
          paintItem(canvas, item, font, images, recolor);
        }
        canvas.restore();
      }
      if (targetHere && session.movingItems != null) {
        // Başka sayfaya sürüklenenler hedef sayfada.
        canvas.save();
        canvas.translate(target.dx, target.dy);
        for (final item in session.movingItems!) {
          paintItem(canvas, item, font, images, recolor);
        }
        canvas.restore();
      }
      if (hasActive) paintItem(canvas, active, font, images, recolor);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(InkLayerPainter old) =>
      old.geometry != geometry ||
      old.session != session ||
      old.cache != cache ||
      old.font != font ||
      old.recolor != recolor;
}

/// Seçim kutusunun ekrandaki dikdörtgeni ([pad] piksel payla); seçim bu
/// sayfada değilse `null`.
Rect? selectionScreenRect(PageViewport view, InkSession session, double pad) {
  if (session.selectionPage != view.index) return null;
  final b = session.selectionBox;
  if (b == null) return null;
  return Rect.fromPoints(
    view.toView(Offset(b.left, b.top)),
    view.toView(Offset(b.right, b.bottom)),
  ).inflate(pad);
}

/// Boyutlandırma tutamakları: 0 sol üst, 1 sağ üst, 2 sağ alt, 3 sol alt.
List<Offset> selectionCorners(Rect r) => [
  r.topLeft,
  r.topRight,
  r.bottomRight,
  r.bottomLeft,
];

/// Tutamaklar: 0–3 köşeler ([selectionCorners]); [edges] ise 4 üst, 5 sağ,
/// 6 alt, 7 sol kenarın ortası (tek eksende boyutlandırma).
List<Offset> selectionHandles(Rect r, {bool edges = false}) => [
  ...selectionCorners(r),
  if (edges) ...[r.topCenter, r.centerRight, r.bottomCenter, r.centerLeft],
];

/// Tutamak karesinin kenarı (ekran pikseli).
const double handleSize = 9;

/// Seçim kutusu ve seçim dikdörtgeni; ekran uzayında, ince çizgiyle
/// (yakınlaştırmadan bağımsız kalınlık).
class SelectionPainter extends CustomPainter {
  SelectionPainter({
    required this.geometry,
    required this.session,
    required this.outline,
    required this.fill,
    required this.halo,
    required this.pad,
  }) : super(repaint: Listenable.merge([geometry, session, session.live]));

  final PageGeometry geometry;
  final InkSession session;

  /// Çizgi rengi, dikdörtgenin dolgusu ve çizginin altındaki açık zemin.
  final Color outline;
  final Color fill;
  final Color halo;

  /// Seçim kutusunun öğelerden uzaklığı (ekran pikseli).
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    if (!geometry.isReady) return;
    canvas.clipRect(Offset.zero & size);
    final m = session.marquee;
    final mPage = session.marqueePage;
    final sPage = session.selectionPage;
    for (final view in geometry.visiblePages) {
      if (m != null && mPage == view.index) {
        final r = Rect.fromPoints(
          view.toView(Offset(m.x1, m.y1)),
          view.toView(Offset(m.x2, m.y2)),
        );
        canvas.drawRect(r, Paint()..color = fill);
        _dashedRect(canvas, r);
      }
      if (sPage == view.index) {
        final r = selectionScreenRect(view, session, pad);
        if (r == null) continue;
        _dashedRect(canvas, r);
        final handles = selectionHandles(r, edges: session.selectionCanStretch);
        for (final c in handles) {
          final h = Rect.fromCenter(
            center: c,
            width: handleSize,
            height: handleSize,
          );
          canvas.drawRect(h, Paint()..color = halo);
          canvas.drawRect(
            h,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = outline,
          );
        }
      }
    }
  }

  /// Açık zemin üstüne kesik çizgi: hem açık hem koyu sayfada görünür.
  void _dashedRect(Canvas canvas, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = halo,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = outline;
    const dash = 5.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      if (len == 0) return;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        canvas.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(SelectionPainter old) =>
      old.geometry != geometry ||
      old.session != session ||
      old.outline != outline ||
      old.fill != fill ||
      old.halo != halo ||
      old.pad != pad;
}
