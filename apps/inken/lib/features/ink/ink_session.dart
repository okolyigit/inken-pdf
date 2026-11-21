import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:inken_core/inken_core.dart';

import 'ink_images.dart';

class _Ticker extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// Açık belgenin çizim durumu: kalıcı model (geri al / yinele ile) ve o an
/// çizilmekte olan çizgi ya da silinmekte olan öğeler.
///
/// İki ayrı bildirim vardır: oturumun kendisi yalnızca model değişince
/// (çizgi bitti, geri al…) haber verir; [live] ise her girdi noktasında.
/// Araç çubuğu ilkini, çizim katmanı ikisini de dinler.
class InkSession extends ChangeNotifier {
  InkSession(InkenDocument document, {InkImages? images})
    : _history = EditHistory(document),
      images = images ?? InkImages();

  /// Belgenin görselleri (kimlik → PNG); oturumla birlikte yaşar.
  final InkImages images;

  EditHistory _history;
  final _Ticker _live = _Ticker();

  /// Etkin çizgi / silgi her değiştiğinde haber verir.
  Listenable get live => _live;

  InkenDocument get document => _history.document;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  bool get isDirty => _history.isDirty;

  // ---- etkin çizgi

  StrokeBuilder? _builder;
  int? _activePage;
  InkTool _activeTool = InkTool.pen;
  int _activeColor = 0;
  double _activeWidth = 1;

  /// Çizilmekte olan çizginin ya da şeklin sayfası; yoksa `null`.
  int? get activePage =>
      _builder == null && _shape == null ? null : _activePage;

  /// Çizilmekte olan öğe (çizgi ya da şekil; henüz modele eklenmedi).
  InkItem? get activeItem => _shape ?? activeStroke;

  /// Çizilmekte olan çizgi (henüz modele eklenmedi).
  Stroke? get activeStroke {
    final b = _builder;
    if (b == null || b.isEmpty) return null;
    return Stroke(
      id: '',
      tool: _activeTool,
      color: _activeColor,
      width: _activeWidth,
      points: b.points,
    );
  }

  bool get isDrawing => _builder != null;

  /// [exact]: noktalar ölçme aracından geliyor, yumuşatılmaz.
  void beginStroke({
    required int page,
    required InkTool tool,
    required int color,
    required double width,
    required double minDistance,
    bool exact = false,
  }) {
    _activePage = page;
    _activeTool = tool;
    _activeColor = color;
    _activeWidth = width;
    _builder = StrokeBuilder(
      minDistance: minDistance,
      fixedPressure: tool == InkTool.highlighter ? 0.5 : null,
      // Noktalar zaten yerinde (ölçme aracının kenarı, pergel yayı):
      // yumuşatma onları kenardan içeri çekerdi.
      smoothing: exact ? 1 : 0.6,
    );
  }

  void addPoint(
    double x,
    double y, {
    double? pressure,
    required double timeMs,
    required double viewScale,
  }) {
    final b = _builder;
    if (b == null) return;
    b.add(x, y, pressure: pressure, timeMs: timeMs, viewScale: viewScale);
    _live.tick();
  }

  /// Çizgiyi modele ekler (tek geri alma adımı).
  void endStroke() {
    final b = _builder;
    final page = _activePage;
    _builder = null;
    if (b == null || page == null || b.isEmpty) return;
    _history.execute(
      AddItems(page, [
        Stroke(
          id: newItemId(),
          tool: _activeTool,
          color: _activeColor,
          width: _activeWidth,
          points: b.finish(),
        ),
      ]),
    );
    notifyListeners();
  }

  // ---- şekil

  Shape? _shape;

  /// Şekil çizilmekte mi?
  bool get isShaping => _shape != null;

  void beginShape({
    required int page,
    required ShapeKind kind,
    required int color,
    required double width,
    required double x,
    required double y,
  }) {
    _activePage = page;
    _shape = Shape(
      id: '',
      kind: kind,
      color: color,
      width: width,
      x1: x,
      y1: y,
      x2: x,
      y2: y,
    );
    _live.tick();
  }

  /// Bitiş noktasını günceller; sayfanın içinde tutulur. [constrain]:
  /// Shift ([constrainShapeEnd]).
  void updateShape(double x, double y, {bool constrain = false}) {
    final s = _shape;
    final page = _activePage;
    if (s == null || page == null) return;
    final layer = document.pages[page];
    var end = constrainShapeEnd(s.kind, s.x1, s.y1, x, y, constrain: constrain);
    if (end.x < 0 || end.x > layer.width || end.y < 0 || end.y > layer.height) {
      // Sayfa dışına taşan bitiş, önce kenara çekilip yeniden düzeltilir.
      end = constrainShapeEnd(
        s.kind,
        s.x1,
        s.y1,
        x.clamp(0, layer.width),
        y.clamp(0, layer.height),
        constrain: constrain,
      );
      end = (x: end.x.clamp(0, layer.width), y: end.y.clamp(0, layer.height));
    }
    _shape = s.copyWith(x2: end.x, y2: end.y);
    _live.tick();
  }

  /// En az bu kadar (pt) büyük şekiller modele girer; daha küçüğü yanlışlıkla
  /// dokunuş sayılır.
  static const double minShapeSize = 2;

  /// Şekli modele ekler (tek geri alma adımı).
  void endShape() {
    final s = _shape;
    final page = _activePage;
    _shape = null;
    if (s == null || page == null) return;
    final big =
        (s.x2 - s.x1).abs() >= minShapeSize ||
        (s.y2 - s.y1).abs() >= minShapeSize;
    final flat =
        s.kind == ShapeKind.rectangle ||
            s.kind == ShapeKind.ellipse ||
            s.kind == ShapeKind.coordinate
        ? (s.x2 - s.x1).abs() < 0.01 || (s.y2 - s.y1).abs() < 0.01
        : false;
    if (!big || flat) {
      _live.tick();
      return;
    }
    _history.execute(AddItems(page, [s.copyWith(id: newItemId())]));
    _changed();
  }

  void cancelShape() {
    if (_shape == null) return;
    _shape = null;
    _live.tick();
  }

  void cancelStroke() {
    if (_builder == null) return;
    _builder = null;
    _live.tick();
  }

  // ---- silgi

  int? _erasePage;
  final Set<String> _pendingErase = {};

  /// Piksel silgisi sürerken sayfanın güncel (bölünmüş) öğeleri; çizgi
  /// silgisinde `null`.
  List<InkItem>? _pixelItems;

  /// Silgi hareketi sürerken silinecek olarak işaretlenen öğeler.
  Set<String> get pendingErase => _pendingErase;
  int? get erasePage => _erasePage;

  /// Piksel silgisi sürerken [erasePage]'in gösterilecek öğeleri.
  List<InkItem>? get pixelPreview => _pixelItems;

  void beginErase(int page, {bool pixel = false}) {
    _erasePage = page;
    _pendingErase.clear();
    _pixelItems = pixel ? document.pages[page].items : null;
  }

  /// Silginin a→b hareketinin dokunduğu öğeleri işaretler (sayfa uzayı).
  /// Piksel silgisinde çizgilerin değen kısımlarını keser; çizgi olmayan
  /// öğeler (şekil, metin) bütün olarak silinir. Görsellere dokunmaz.
  void eraseSegment(double ax, double ay, double bx, double by, double radius) {
    final page = _erasePage;
    if (page == null) return;
    final working = _pixelItems;
    if (working != null) {
      _pixelErase(working, ax, ay, bx, by, radius);
      return;
    }
    final hits = itemsHitBySegment(
      document.pages[page],
      ax,
      ay,
      bx,
      by,
      radius,
      images: false,
    );
    if (hits.difference(_pendingErase).isEmpty) return;
    _pendingErase.addAll(hits);
    _live.tick();
  }

  void _pixelErase(
    List<InkItem> items,
    double ax,
    double ay,
    double bx,
    double by,
    double radius,
  ) {
    final layer = document.pages[_erasePage!].copyWith(items: items);
    final hits = itemsHitBySegment(
      layer,
      ax,
      ay,
      bx,
      by,
      radius,
      images: false,
    );
    if (hits.isEmpty) return;
    var changed = false;
    final result = <InkItem>[];
    for (final item in items) {
      if (!hits.contains(item.id)) {
        result.add(item);
        continue;
      }
      if (item is! Stroke) {
        changed = true;
        continue;
      }
      final pieces = eraseStrokePoints(item, ax, ay, bx, by, radius);
      if (pieces == null) {
        result.add(item);
        continue;
      }
      changed = true;
      for (final points in pieces) {
        result.add(item.copyWith(id: newItemId(), points: points));
      }
    }
    if (!changed) return;
    _pixelItems = result;
    _live.tick();
  }

  /// İşaretlenenleri tek adımda siler.
  void endErase() {
    final page = _erasePage;
    final pixel = _pixelItems;
    _erasePage = null;
    _pixelItems = null;
    if (page == null) return;
    if (pixel != null) {
      final before = document.pages[page].items;
      if (identical(pixel, before)) return;
      _history.execute(SetPageItems(page, before, pixel));
      _changed();
      return;
    }
    if (_pendingErase.isEmpty) return;
    final command = RemoveItems(document, page, {..._pendingErase});
    _pendingErase.clear();
    if (command.isEmpty) return;
    _history.execute(command);
    _changed();
  }

  void cancelErase() {
    _erasePage = null;
    final hadPixel = _pixelItems != null;
    _pixelItems = null;
    if (_pendingErase.isEmpty && !hadPixel) return;
    _pendingErase.clear();
    _live.tick();
  }

  // ---- seçim

  int? _selPage;
  Set<String> _selected = const {};

  /// Seçimin sayfası; seçim yoksa `null`.
  int? get selectionPage => _selected.isEmpty ? null : _selPage;

  /// Seçili öğelerin kimlikleri.
  Set<String> get selection => _selected;
  bool get hasSelection => _selected.isNotEmpty;

  /// Seçimin sınır kutusu (sayfa uzayı, taşıma sürüyorsa kaydırılmış).
  ({double left, double top, double right, double bottom})? get selectionBox {
    final page = selectionPage;
    if (page == null) return null;
    final b = selectionBounds(document.pages[page], _selected);
    if (b == null) return null;
    if (_resizing) {
      final (:ax, :ay, :sx, :sy) = resizeTransform!;
      final x1 = ax + (b.left - ax) * sx, x2 = ax + (b.right - ax) * sx;
      final y1 = ay + (b.top - ay) * sy, y2 = ay + (b.bottom - ay) * sy;
      return (
        left: math.min(x1, x2),
        top: math.min(y1, y2),
        right: math.max(x1, x2),
        bottom: math.max(y1, y2),
      );
    }
    // Başka sayfaya sürüklenirken kutu kaynak sayfada çizilmez.
    if (_moveTarget != null) return null;
    return (
      left: b.left + _moveDx,
      top: b.top + _moveDy,
      right: b.right + _moveDx,
      bottom: b.bottom + _moveDy,
    );
  }

  /// Görseli [page] sayfasına ekler (tek geri alma adımı) ve seçer:
  /// köşelerinden hemen boyutlandırılabilsin. Baytları önceden
  /// [images]'a eklenmiş olmalıdır.
  void insertImage(int page, ImageItem item) {
    _history.execute(AddItems(page, [item]));
    _changed();
    select(page, {item.id});
  }

  /// [page] sayfasındaki her şeyi seçer.
  void selectAll(int page) {
    if (page < 0 || page >= document.pages.length) return;
    final ids = {for (final i in document.pages[page].items) i.id};
    if (ids.isEmpty) return clearSelection();
    select(page, ids);
  }

  /// Seçili öğeler, sayfadaki sıralarıyla (kopyalamak için).
  List<InkItem> get selectedItems {
    final page = selectionPage;
    if (page == null) return const [];
    return [
      for (final i in document.pages[page].items)
        if (_selected.contains(i.id)) i,
    ];
  }

  /// Seçimde rengi değiştirilebilen öğe var mı (görsel dışında)?
  bool get selectionHasColor => selectedItems.any(hasColor);

  /// Seçim kenarlarından (tek eksende) boyutlandırılabilir mi? Yazı
  /// esnetilemediği için seçimde metin varsa hayır.
  bool get selectionCanStretch =>
      hasSelection && !selectedItems.any((i) => i is TextItem);

  /// Seçilenleri [color] rengine boyar (tek geri alma adımı).
  void recolorSelection(int color) {
    final page = selectionPage;
    if (page == null) return;
    final command = RecolorItems(document, page, _selected, color);
    if (command.isEmpty) return;
    _history.execute(command);
    notifyListeners();
  }

  /// [items]'ı [page] sayfasına yeni kimliklerle (dx, dy) kaydırarak ekler,
  /// sayfanın içinde tutar ve seçer (yapıştır). Tek geri alma adımı.
  void pasteItems(
    int page,
    List<InkItem> items, {
    double dx = 0,
    double dy = 0,
  }) {
    if (items.isEmpty || page < 0 || page >= document.pages.length) return;
    final layer = document.pages[page];
    var copies = [
      for (final i in items) translateItem(i, dx, dy).copyWith(id: newItemId()),
    ];
    // Sayfaya sığmayan kopya içeri itilir.
    final probe = layer.copyWith(items: copies);
    final b = selectionBounds(probe, {for (final c in copies) c.id})!;
    final shiftX = _clampShift(0, b.left, b.right, layer.width);
    final shiftY = _clampShift(0, b.top, b.bottom, layer.height);
    if (shiftX != 0 || shiftY != 0) {
      copies = [for (final c in copies) translateItem(c, shiftX, shiftY)];
    }
    _history.execute(AddItems(page, copies));
    _changed();
    select(page, {for (final c in copies) c.id});
  }

  void select(int page, Set<String> ids) {
    _selPage = page;
    _selected = Set.unmodifiable(ids);
    _live.tick();
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty && _marquee == null) return;
    _selected = const {};
    _marquee = null;
    _live.tick();
    notifyListeners();
  }

  /// (x, y), [page] sayfasındaki seçimin kutusunun [pad] payla içinde mi?
  bool selectionContains(int page, double x, double y, double pad) {
    if (page != selectionPage) return false;
    final b = selectionBox;
    if (b == null) return false;
    return x >= b.left - pad &&
        x <= b.right + pad &&
        y >= b.top - pad &&
        y <= b.bottom + pad;
  }

  // dikdörtgenle seçim

  int? _marqueePage;
  ({double x1, double y1, double x2, double y2})? _marquee;

  /// Çizilmekte olan seçim dikdörtgeni (sayfa uzayı) ve sayfası.
  ({double x1, double y1, double x2, double y2})? get marquee => _marquee;
  int? get marqueePage => _marquee == null ? null : _marqueePage;

  void beginMarquee(int page, double x, double y) {
    _selected = const {};
    _marqueePage = page;
    _marquee = (x1: x, y1: y, x2: x, y2: y);
    _live.tick();
    notifyListeners();
  }

  void updateMarquee(double x, double y) {
    final m = _marquee;
    if (m == null) return;
    _marquee = (x1: m.x1, y1: m.y1, x2: x, y2: y);
    _live.tick();
  }

  /// Dikdörtgenin içinde tamamen kalan öğeleri seçer.
  void endMarquee() {
    final m = _marquee;
    final page = _marqueePage;
    _marquee = null;
    if (m == null || page == null) return;
    final ids = itemsInRect(document.pages[page], m.x1, m.y1, m.x2, m.y2);
    select(page, ids);
  }

  // taşıma

  double _moveDx = 0, _moveDy = 0;
  bool _moving = false;

  /// Taşıma sürerken sayfanın seçili olmayan öğeleri (liste kimliği sabit,
  /// önbelleğe uygun) ve seçili öğeler; taşıma yoksa `null`.
  List<InkItem>? _movingRest;
  List<InkItem>? _movingItems;
  List<InkItem>? get movingRest => _movingRest;
  List<InkItem>? get movingItems => _movingItems;
  bool get isMoving => _moving;

  /// Taşımanın o anki kayması (sayfa uzayı).
  ({double dx, double dy}) get moveOffset => (dx: _moveDx, dy: _moveDy);

  int? _moveTarget;
  double _targetDx = 0, _targetDy = 0;

  /// Seçim başka bir sayfaya sürükleniyorsa o sayfa ve öğelerin oraya
  /// kayması (kaynak sayfa uzayından hedef sayfa uzayına); yoksa `null`.
  ({int page, double dx, double dy})? get moveTarget => _moveTarget == null
      ? null
      : (page: _moveTarget!, dx: _targetDx, dy: _targetDy);

  /// Seçimi başka bir sayfaya sürükler: öğeler [page] sayfasında (dx, dy)
  /// kayık görünür (sayfanın içinde kalır). [page] kaynak sayfaysa olağan
  /// taşımaya döner.
  void updateMoveToPage(int page, double dx, double dy) {
    final source = selectionPage;
    if (!_moving || source == null) return;
    if (page == source) {
      _moveTarget = null;
      return updateMove(dx, dy);
    }
    final b = selectionBounds(document.pages[source], _selected)!;
    final target = document.pages[page];
    _moveTarget = page;
    _targetDx = _clampShift(dx, b.left, b.right, target.width);
    _targetDy = _clampShift(dy, b.top, b.bottom, target.height);
    _live.tick();
  }

  void beginMove() {
    if (selectionPage == null) return;
    _moving = true;
    _moveDx = 0;
    _moveDy = 0;
    _splitSelection();
  }

  /// Önizleme için sayfayı seçili olan / olmayan diye ikiye ayırır.
  void _splitSelection() {
    final items = document.pages[selectionPage!].items;
    _movingRest = [
      for (final i in items)
        if (!_selected.contains(i.id)) i,
    ];
    _movingItems = [
      for (final i in items)
        if (_selected.contains(i.id)) i,
    ];
  }

  /// Toplam kaymayı ayarlar; seçim sayfanın dışına taşmaz.
  void updateMove(double dx, double dy) {
    final page = selectionPage;
    if (!_moving || page == null) return;
    if (_moveTarget != null) {
      _moveTarget = null;
    }
    final layer = document.pages[page];
    final b = selectionBounds(layer, _selected)!;
    _moveDx = _clampShift(dx, b.left, b.right, layer.width);
    _moveDy = _clampShift(dy, b.top, b.bottom, layer.height);
    _live.tick();
  }

  /// [lo, hi] aralığını [0, size] içinde tutan kayma. Aralık zaten taşıyorsa
  /// kullanıcıyı kısıtlamaz, yalnızca daha da dışarı çıkmasını engeller.
  static double _clampShift(double d, double lo, double hi, double size) {
    final min = math.min(-lo, 0.0), max = math.max(size - hi, 0.0);
    return d.clamp(min, max);
  }

  /// Taşımayı tek geri alma adımı olarak uygular.
  void endMove() {
    final page = selectionPage;
    final dx = _moveDx, dy = _moveDy;
    final target = moveTarget;
    _resetMove();
    if (page == null) return;
    if (target != null) {
      final command = TransferItems(
        document,
        page,
        target.page,
        _selected,
        target.dx,
        target.dy,
      );
      if (command.isEmpty) return;
      _history.execute(command);
      _selPage = target.page;
      notifyListeners();
      return;
    }
    if (dx == 0 && dy == 0) {
      _live.tick();
      return;
    }
    _history.execute(MoveItems(document, page, _selected, dx, dy));
    notifyListeners();
  }

  void cancelMove() {
    if (!_moving && !_resizing) return;
    _resetMove();
    _live.tick();
  }

  // boyutlandırma

  bool _resizing = false;
  double _anchorX = 0, _anchorY = 0;
  double _dirX = 0, _dirY = 0;
  double _grab = 1;
  double _scale = 1;
  double _minScale = 0, _maxScale = double.infinity;

  /// Kenar tutamağı: yalnızca bir eksende ölçeklenir (`true` yatay).
  bool? _edgeAxisX;

  bool get isResizing => _resizing;

  /// Boyutlandırma sürerken sabit nokta ve eksen ölçekleri; yoksa `null`.
  ({double ax, double ay, double sx, double sy})? get resizeTransform =>
      !_resizing
      ? null
      : switch (_edgeAxisX) {
          true => (ax: _anchorX, ay: _anchorY, sx: _scale, sy: 1.0),
          false => (ax: _anchorX, ay: _anchorY, sx: 1.0, sy: _scale),
          null => (ax: _anchorX, ay: _anchorY, sx: _scale, sy: _scale),
        };

  /// Seçim kutusunun en küçük boyutu (pt).
  static const double minSelectionSize = 4;

  /// [handle] tutamağından boyutlandırmaya başlar. Köşeler orantılı:
  /// 0 sol üst, 1 sağ üst, 2 sağ alt, 3 sol alt; karşı köşe sabit. Kenarlar
  /// tek eksende: 4 üst, 5 sağ, 6 alt, 7 sol; karşı kenar sabit.
  /// (x, y) tutulan nokta.
  void beginResize(int handle, double x, double y) {
    final page = selectionPage;
    if (page == null) return;
    final layer = document.pages[page];
    final b = selectionBounds(layer, _selected)!;
    if (handle >= 4) {
      if (!selectionCanStretch) return;
      final horizontal = handle == 5 || handle == 7;
      final towardMin = handle == 4 || handle == 7;
      _edgeAxisX = horizontal;
      _anchorX = horizontal ? (towardMin ? b.right : b.left) : b.left;
      _anchorY = horizontal ? b.top : (towardMin ? b.bottom : b.top);
      _dirX = horizontal ? (towardMin ? b.left : b.right) - _anchorX : 0;
      _dirY = horizontal ? 0 : (towardMin ? b.top : b.bottom) - _anchorY;
      final len = horizontal ? _dirX : _dirY;
      if (len == 0) return;
      final grab = horizontal ? (x - _anchorX) * _dirX : (y - _anchorY) * _dirY;
      _grab = grab > 0 ? grab : len * len;
      _minScale = math.min(minSelectionSize / len.abs(), 1);
      _maxScale = math.max(
        horizontal
            ? _axisMax(_anchorX, _dirX, layer.width)
            : _axisMax(_anchorY, _dirY, layer.height),
        1,
      );
    } else {
      _edgeAxisX = null;
      final left = handle == 0 || handle == 3;
      final top = handle == 0 || handle == 1;
      _anchorX = left ? b.right : b.left;
      _anchorY = top ? b.bottom : b.top;
      _dirX = (left ? b.left : b.right) - _anchorX;
      _dirY = (top ? b.top : b.bottom) - _anchorY;
      final grab = (x - _anchorX) * _dirX + (y - _anchorY) * _dirY;
      final len2 = _dirX * _dirX + _dirY * _dirY;
      if (len2 == 0) return;
      // Tutma noktası köşeden biraz dışarıda olabilir; ölçek tutulan
      // noktanın köşegen üzerindeki izdüşümüne göre, başta tam 1.
      _grab = grab > 0 ? grab : len2;
      final size = math.max(_dirX.abs(), _dirY.abs());
      _minScale = math.min(minSelectionSize / size, 1);
      _maxScale = math.max(
        math.min(
          _axisMax(_anchorX, _dirX, layer.width),
          _axisMax(_anchorY, _dirY, layer.height),
        ),
        1,
      );
    }
    _scale = 1;
    _resizing = true;
    _splitSelection();
    _live.tick();
  }

  /// Sabit noktadan [dir] yönünde büyürken sayfa kenarına değmeden önceki
  /// en büyük ölçek.
  static double _axisMax(double anchor, double dir, double size) {
    if (dir > 0) return (size - anchor) / dir;
    if (dir < 0) return anchor / -dir;
    return double.infinity;
  }

  void updateResize(double x, double y) {
    if (!_resizing) return;
    final proj = (x - _anchorX) * _dirX + (y - _anchorY) * _dirY;
    _scale = (proj / _grab).clamp(_minScale, _maxScale);
    _live.tick();
  }

  /// Boyutlandırmayı tek geri alma adımı olarak uygular.
  void endResize() {
    final page = selectionPage;
    final t = resizeTransform;
    _resetMove();
    if (t == null || page == null) return;
    if (t.sx == 1 && t.sy == 1) {
      _live.tick();
      return;
    }
    _history.execute(
      ScaleItems(
        document,
        page,
        _selected,
        t.sx,
        t.ax,
        t.ay,
        scaleY: t.sx == t.sy ? null : t.sy,
      ),
    );
    notifyListeners();
  }

  void _resetMove() {
    _resizing = false;
    _edgeAxisX = null;
    _moveTarget = null;
    _scale = 1;
    _moving = false;
    _moveDx = 0;
    _moveDy = 0;
    _movingRest = null;
    _movingItems = null;
  }

  /// Seçili öğeleri siler (tek geri alma adımı).
  void deleteSelection() {
    final page = selectionPage;
    if (page == null) return;
    final command = RemoveItems(document, page, _selected);
    _selected = const {};
    if (!command.isEmpty) _history.execute(command);
    notifyListeners();
  }

  /// Geri al / yinele gibi değişikliklerden sonra artık bulunmayan öğeleri
  /// seçimden çıkarır.
  void _pruneSelection() {
    final page = _selPage;
    if (_selected.isEmpty || page == null) return;
    if (page >= document.pages.length) {
      _selected = const {};
      return;
    }
    final present = {for (final i in document.pages[page].items) i.id};
    final kept = _selected.intersection(present);
    if (kept.length != _selected.length) _selected = Set.unmodifiable(kept);
  }

  // ---- metin düzenleme

  int? _textPage;
  String? _editingId;
  List<InkItem>? _editingRest;

  /// Yazma kutusu açık mı (yeni ya da var olan metin)?
  bool get isEditingText => _textPage != null;
  int? get textEditPage => _textPage;

  /// Düzenlenen metnin kimliği (yeni metinde `null`).
  String? get editingTextId => _editingId;

  /// Düzenleme sürerken sayfanın düzenlenen metin hariç öğeleri (metin
  /// yazma kutusunda görünür; liste kimliği sabit, önbelleğe uygun).
  List<InkItem>? get editingRest => _editingRest;

  void beginTextEdit(int page, {String? id}) {
    _textPage = page;
    _editingId = id;
    _editingRest = id == null
        ? null
        : [
            for (final i in document.pages[page].items)
              if (i.id != id) i,
          ];
    _live.tick();
  }

  /// Yazma kutusunu kapatır ve sonucu tek geri alma adımı olarak uygular:
  /// yeni metin eklenir, değişen metin değiştirilir, boşaltılan metin
  /// silinir. [result] `null` ya da boşsa metin yoktur.
  void endTextEdit(TextItem? result) {
    final page = _textPage;
    final id = _editingId;
    _textPage = null;
    _editingId = null;
    _editingRest = null;
    if (page == null || page >= document.pages.length) {
      _live.tick();
      return;
    }
    final before = id == null
        ? null
        : document.pages[page].items
              .whereType<TextItem>()
              .where((i) => i.id == id)
              .firstOrNull;
    final empty = result == null || result.text.trim().isEmpty;
    EditCommand? command;
    if (empty) {
      if (before != null) command = RemoveItems(document, page, {before.id});
    } else if (before == null) {
      command = AddItems(page, [result.copyWith(id: newItemId())]);
    } else {
      final after = result.copyWith(id: before.id);
      if (after != before) command = ReplaceItem(page, before, after);
    }
    if (command == null) {
      _live.tick();
      return;
    }
    _history.execute(command);
    _changed();
    _live.tick();
  }

  // ---- kayıt

  /// [snapshot]'ın kaydedildiğini işaretler. [saved], yazıcının döndürdüğü
  /// modeldir.
  ///
  /// Kayıt sürerken model değiştiyse (kullanıcı çizmeye devam etti) belge
  /// kirli kalır. Araya eklenen sayfalar kayıttan sonra dosyada gerçek sayfa
  /// olduğundan sayfa sıraları yeniden numaralanır; öyleyse geçmiş eski
  /// numaralara dayandığı için sıfırlanır (geri al o noktadan başlar).
  ///
  /// Kayıt sürerken çizim devam ettiyse ve sayfalar yeniden numaralandıysa
  /// güncel model de yeni numaralara taşınır ve kirli kalır (sayfa düzeni
  /// kayıt sırasında değişemez: [saving]).
  void markSaved(InkenDocument snapshot, InkenDocument saved) {
    // Döndürülen sayfalar da kayıttan sonra dosyada döndürülmüştür: bekleyen
    // döndürme sıfırlanır, geçmiş ona dayandığından baştan başlar.
    final renumbered =
        !_sameSourceIndexes(saved, snapshot) ||
        snapshot.pages.any((p) => p.pendingTurns != 0);
    if (identical(snapshot, document)) {
      if (renumbered) {
        _history = EditHistory(saved);
      } else {
        _history.markSaved();
      }
    } else if (renumbered) {
      if (document.pages.length != saved.pages.length) {
        throw StateError('Kayıt sırasında sayfa düzeni değişmiş');
      }
      _history = EditHistory(
        document.copyWith(
          pages: [
            for (final (i, p) in document.pages.indexed)
              p.copyWith(
                sourceIndex: saved.pages[i].sourceIndex,
                rotation: saved.pages[i].rotation,
              ),
          ],
        ),
        dirty: true,
      );
    } else {
      return;
    }
    _changed();
  }

  static bool _sameSourceIndexes(InkenDocument a, InkenDocument b) {
    if (a.pages.length != b.pages.length) return false;
    for (var i = 0; i < a.pages.length; i++) {
      if (a.pages[i].sourceIndex != b.pages[i].sourceIndex) return false;
    }
    return true;
  }

  /// Modeli yedekten gelenle değiştirir; belge kirli olur, geri al dosyadaki
  /// hale döner.
  void restore(InkenDocument recovered) {
    _history.execute(ReplaceDocument(document, recovered));
    _changed();
  }

  // ---- sayfalar

  /// Taşıma, boyutlandırma ya da metin yazma sürüyorsa sayfa düzeni
  /// değişmez (o işlemler sayfa sırasına bağlı).
  bool get canChangePages =>
      !_moving && !_resizing && !isEditingText && !saving;

  /// Kayıt sürüyor: sayfa düzeni değişemez (ekle / sil / geri al / yinele),
  /// çünkü kayıttan sonra sayfalar yeni dosyaya göre numaralanır. Çizim
  /// sürebilir.
  bool saving = false;

  /// [index] konumuna [page] sayfasını ekler; tek geri alma adımı.
  void insertPage(int index, PageLayer page) {
    if (!canChangePages) return;
    clearSelection();
    _history.execute(InsertPage(index, page));
    _changed();
  }

  /// [index] numaralı sayfayı çizimleriyle siler; tek geri alma adımı.
  /// Son kalan sayfa silinmez.
  void removePage(int index) {
    if (!canChangePages || document.pages.length <= 1) return;
    clearSelection();
    _history.execute(RemovePage(index, document.pages[index]));
    _changed();
  }

  /// [indexes] sayfalarını çizimleriyle birlikte siler; tek geri alma
  /// adımı. Hepsini silmek istenirse hiçbir şey yapılmaz (en az bir sayfa
  /// kalır).
  void removePages(Set<int> indexes) {
    if (!canChangePages || indexes.isEmpty) return;
    if (indexes.length >= document.pages.length) return;
    clearSelection();
    _history.execute(RemovePages(document, indexes));
    _changed();
  }

  /// [indexes] sayfalarını [turns] çeyrek tur saat yönünde (negatif: ters)
  /// döndürür; çizimler sayfayla döner. Tek geri alma adımı.
  void rotatePages(Set<int> indexes, int turns) {
    if (!canChangePages || indexes.isEmpty || turns % 4 == 0) return;
    clearSelection();
    _history.execute(RotatePages(document, indexes, turns));
    _changed();
  }

  // ---- geri al / yinele

  void undo() {
    if (!canChangePages) return;
    if (_history.undo()) _changed();
  }

  void redo() {
    if (!canChangePages) return;
    if (_history.redo()) _changed();
  }

  void _changed() {
    _pruneSelection();
    notifyListeners();
  }

  @override
  void dispose() {
    _live.dispose();
    images.dispose();
    super.dispose();
  }
}
