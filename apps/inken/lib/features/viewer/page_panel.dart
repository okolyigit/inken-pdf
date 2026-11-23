import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../capture/capture_layer.dart' show CaptureAction;
import '../ink/ink_images.dart';
import '../ink/ink_painter.dart';
import '../ink/ink_session.dart';
import '../settings/settings_store.dart';
import 'app_menus.dart';
import 'page_templates.dart';

/// Sayfa küçük resimleri paneli açık mı; kalıcı (`settings.json`).
class PagePanelNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(settingsStoreProvider).get<bool>('pagePanel') ?? false;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('pagePanel', on);
  }

  void toggle() => set(!state);
}

final pagePanelProvider = NotifierProvider<PagePanelNotifier, bool>(
  PagePanelNotifier.new,
);

/// Panelden yapılan sayfa işlemleri; görüntüleyici ekranı verir.
class PagePanelActions {
  const PagePanelActions({
    required this.rotate,
    required this.move,
    required this.insert,
    required this.delete,
    required this.orientation,
    required this.setOrientation,
    required this.color,
    required this.setColor,
    this.images,
  });

  /// [pages] sayfalarını [turns] çeyrek tur döndürür (1 sağa, -1 sola).
  final void Function(Set<int> pages, int turns) rotate;

  /// [pages] sayfalarını taşır: ilki [to] konumuna gelir (taşınanlar
  /// çıkarıldıktan sonraki sıra; [MovePages]).
  final void Function(Set<int> pages, int to) move;

  /// [index] konumuna [template] zeminli sayfa ekler.
  final void Function(int index, PageTemplate template) insert;

  /// Sayfaları siler (en az bir sayfa kalır).
  final ValueChanged<Set<int>> delete;

  /// Eklenecek sayfanın yönü.
  final PageOrientation orientation;
  final ValueChanged<PageOrientation> setOrientation;

  /// Eklenecek sayfanın kâğıt rengi ve değiştirilmesi.
  final PageColor color;
  final ValueChanged<PageColor> setColor;

  /// Sayfaları görsel olarak kopyalar (tek sayfa), kaydeder ya da paylaşır;
  /// görüntü hazırlanırken `null`.
  final void Function(Set<int> pages, CaptureAction action)? images;
}

/// Panel menüsünün neyi gösterdiği.
sealed class _PanelMenu {
  const _PanelMenu();
}

/// Sayfa işlemleri menüsü (sağ tık, uzun basış menüsü, "⋯").
class _PagesMenu extends _PanelMenu {
  const _PagesMenu(this.pages);
  final Set<int> pages;
}

/// "+" menüsü: [index] konumuna sayfa ekler.
class _InsertMenu extends _PanelMenu {
  const _InsertMenu(this.index);
  final int index;
}

/// Belgenin solundaki sayfa listesi: her sayfanın küçük resmi (çizimleriyle)
/// ve numarası. Geçerli sayfa vurgulu ve görünür tutulur; dokunmak o
/// sayfaya gider. Açma / kapama sekmesi ([PanelGrip]) panelin dışında,
/// belge alanının sol kenarındadır.
///
/// Sayfa işlemleri ([actions]): sağ tık ya da "⋯" menüsü (döndür, önüne /
/// arkasına ekle, sil), sayfanın altındaki "+" (arkasına ekle). Ctrl ile
/// dokunmak sayfayı seçime ekler / çıkarır, Shift aralık seçer; dokunmatikte
/// uzun basış seçim kipini açar (sonraki dokunuşlar seçer). Seçim varken
/// üstteki şeritten seçili sayfalar taşınır, döndürülür ya da silinir.
///
/// Sıralama: fareyle sayfa (seçiliyse seçimle birlikte) sürüklenip araya
/// bırakılır; dokunmatikte ve kalemde uzun basış sayfayı kaldırır (hareket
/// etmeden bırakılırsa seçim kipi açılır). Menüde ve şeritte yukarı / aşağı
/// taşı.
class PagePanel extends StatefulWidget {
  const PagePanel({
    super.key,
    required this.viewer,
    required this.session,
    this.actions,
    this.night = false,
  });

  /// Gece modu: küçük resimler de koyu (sayfa süzgeci, çizim renkleri).
  final bool night;

  /// Panelin genişliği (mantıksal piksel); içindekiler sekmesinde
  /// başlıklar sığsın diye [outlineWidth].
  static const double width = 168;
  static const double outlineWidth = 264;

  final InkenViewerController viewer;

  /// Çizimler; belge yüklenene kadar `null`.
  final InkSession? session;

  /// Sayfa işlemleri; `null` ise panel yalnızca gezinir.
  final PagePanelActions? actions;

  @override
  State<PagePanel> createState() => _PagePanelState();
}

class _PagePanelState extends State<PagePanel> {
  final ScrollController _scroll = ScrollController();
  final MenuController _menu = MenuController();
  final GlobalKey _menuAnchor = GlobalKey();
  int? _shown;

  /// Seçili sayfalar (Ctrl / Shift ya da uzun basışla); boşken işlemler
  /// tıklanan sayfaya uygulanır.
  Set<int> _selected = {};

  /// Shift ile aralık seçiminin başı.
  int? _rangeStart;

  /// Dokunmatik seçim kipi: dokunmak sayfaya gitmez, seçer.
  bool _selecting = false;

  /// Fare üstündeki sayfa (denetimleri gösterir).
  int? _hover;

  _PanelMenu? _openMenu;

  /// Sürüklenen sayfalar ve bırakılacak yer (0…sayfa sayısı: o sayfanın
  /// önü; sayı: en son).
  Set<int>? _dragging;
  int? _dropSlot;

  /// Son sürükleme bir yere bırakıldı mı (dokunmatikte bırakılmadıysa uzun
  /// basış seçim kipini açar).
  bool _dropped = false;

  /// Sürüklerken liste kenarına gelince kendiliğinden kaydırma.
  Timer? _edgeTimer;
  double _edgeSpeed = 0;

  /// Gösterilen sekme: sayfalar ya da içindekiler.
  bool _outline = false;

  void _showOutline(bool on) => setState(() {
    _outline = on;
    _shown = null; // sayfalara dönünce geçerli sayfa yeniden görünür kılınır
    _openMenu = null;
  });

  /// Küçük resim kutusunun dış genişliği (kenarlık dahil).
  static const double _thumbWidth = PagePanel.width - 2 * Space.s4;

  /// Kenarlık kalınlığı (her sayfada aynı; yalnızca rengi değişir: öğe
  /// yükseklikleri seçimden bağımsız kalsın).
  static const double _border = 2;

  /// Sayfa resminin genişliği (kenarlığın içi); yükseklik sayfanın
  /// oranından.
  static const double _imageWidth = _thumbWidth - 2 * _border;

  /// Sayfa numarası satırının yüksekliği ("⋯" ve "+" düğmeleri de burada).
  static const double _labelHeight = 28;

  static const double _listPadding = Space.s3;

  /// [aspect] (en / boy) oranlı sayfanın listedeki tam yüksekliği.
  static double _extentFor(double aspect) =>
      2 * Space.s2 +
      _imageWidth / aspect +
      2 * _border +
      Space.s1 +
      _labelHeight;

  double _aspect(int i) {
    final sizes = widget.viewer.pageSizes;
    return i < sizes.length && sizes[i].height > 0 && sizes[i].width > 0
        ? sizes[i].width / sizes[i].height
        : 210 / 297;
  }

  @override
  void initState() {
    super.initState();
    widget.viewer.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
  }

  @override
  void didUpdateWidget(PagePanel old) {
    super.didUpdateWidget(old);
    if (old.viewer != widget.viewer) {
      old.viewer.removeListener(_follow);
      widget.viewer.addListener(_follow);
    }
  }

  @override
  void dispose() {
    widget.viewer.removeListener(_follow);
    _edgeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Geçerli sayfa değişince listede görünür tutulur: konumu yüksekliklerin
  /// toplamından bilinir (öğe kurulmamış olsa da), yalnızca görünmüyorsa
  /// kaydırılır.
  void _follow() {
    final page = widget.viewer.currentPage;
    if (page == null || page == _shown || !_scroll.hasClients) return;
    _shown = page;
    var top = _listPadding;
    for (var i = 0; i < page; i++) {
      top += _extentFor(_aspect(i));
    }
    final bottom = top + _extentFor(_aspect(page));
    final position = _scroll.position;
    final view = position.viewportDimension;
    double? to;
    if (top < position.pixels) {
      to = top;
    } else if (bottom > position.pixels + view) {
      to = bottom - view;
    }
    if (to == null) return;
    to = to.clamp(0, position.maxScrollExtent);
    final far = (to - position.pixels).abs() > view * 2;
    if (far || MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(to, duration: Motion.normal, curve: Motion.curve);
    }
  }

  bool get _canChange =>
      widget.actions != null && (widget.session?.canChangePages ?? false);

  void _clearSelection() => setState(() {
    _selected = {};
    _selecting = false;
  });

  void _tap(int i) {
    final keys = HardwareKeyboard.instance;
    if (keys.isShiftPressed) {
      final from = _rangeStart ?? widget.viewer.currentPage ?? i;
      setState(() {
        _selected = {
          for (var k = from < i ? from : i; k <= (from < i ? i : from); k++) k,
        };
      });
      return;
    }
    if (keys.isControlPressed || keys.isMetaPressed || _selecting) {
      setState(() {
        _selected = {..._selected};
        if (!_selected.remove(i)) _selected.add(i);
        _rangeStart = i;
        if (_selected.isEmpty) _selecting = false;
      });
      return;
    }
    if (_selected.isNotEmpty) _clearSelection();
    _rangeStart = i;
    widget.viewer.goToPage(i);
  }

  void _longPress(int i, {bool haptic = true}) {
    if (widget.actions == null) return;
    if (haptic) HapticFeedback.selectionClick();
    setState(() {
      _selecting = true;
      _selected = {..._selected, i};
      _rangeStart = i;
    });
  }

  /// İşlemlerin uygulanacağı sayfalar: [i] seçiliyse seçim, değilse [i].
  Set<int> _targets(int i) => _selected.contains(i) ? {..._selected} : {i};

  void _showMenu(_PanelMenu menu, Offset global) {
    final box = _menuAnchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || widget.actions == null) return;
    setState(() => _openMenu = menu);
    _menu.open(position: box.globalToLocal(global));
  }

  void _rotate(Set<int> pages, int turns) =>
      widget.actions?.rotate(pages, turns);

  void _insert(int index, PageTemplate t) {
    widget.actions?.insert(index, t);
    _clearSelection();
  }

  void _delete(Set<int> pages) {
    widget.actions?.delete(pages);
    _clearSelection();
  }

  /// [pages] sayfalarını [slot] konumunun önüne taşır (0…sayfa sayısı).
  /// Seçim varsa taşınan sayfalarda kalır (oklarla art arda taşınabilsin).
  void _moveTo(Set<int> pages, int slot) {
    final a = widget.actions;
    if (a == null || !_canChange || pages.isEmpty) return;
    final to = slot - pages.where((p) => p < slot).length;
    a.move(pages, to);
    setState(() {
      if (_selected.isNotEmpty) {
        _selected = {for (var k = 0; k < pages.length; k++) to + k};
        _rangeStart = to;
      }
    });
  }

  /// Bir sıra yukarı ([dir] -1) ya da aşağı (1): sayfalar bitişik blok
  /// olarak komşusunun öbür yanına geçer.
  void _moveBy(Set<int> pages, int dir) {
    final first = pages.reduce(math.min);
    final last = pages.reduce(math.max);
    _moveTo(pages, dir < 0 ? first - 1 : last + 2);
  }

  /// Sürükleme sırasında bırakma yeri: imleç sayfanın üst yarısındaysa
  /// önü, alt yarısındaysa arkası.
  void _dragOver(int i, BuildContext tile, Offset global) {
    final box = tile.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(global).dy;
    final slot = y < box.size.height / 2 ? i : i + 1;
    if (slot != _dropSlot) setState(() => _dropSlot = slot);
  }

  void _dragStart(Set<int> pages) => setState(() {
    _dragging = pages;
    _dropSlot = null;
    _dropped = false;
    _openMenu = null;
  });

  void _dragEnd() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgeSpeed = 0;
    if (_dragging == null && _dropSlot == null) return;
    setState(() {
      _dragging = null;
      _dropSlot = null;
    });
  }

  void _drop(Set<int> pages) {
    final slot = _dropSlot;
    final count = widget.viewer.pageCount;
    // Kendi yerine bırakmak taşıma sayılmaz (dokunmatikte seçim kipi açılır).
    _dropped =
        slot != null &&
        !MovePages(
          count,
          pages,
          slot - pages.where((p) => p < slot).length,
        ).isNoop;
    _dragEnd();
    if (_dropped) _moveTo(pages, slot!);
  }

  /// İmleç listenin üst / alt kenarına yakınsa liste o yöne kayar.
  void _dragUpdate(Offset global) {
    final box = _menuAnchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(global).dy;
    const zone = Sizes.target;
    final h = box.size.height;
    _edgeSpeed = y < zone
        ? -(zone - y.clamp(0, zone)) / zone
        : y > h - zone
        ? (y.clamp(h - zone, h) - (h - zone)) / zone
        : 0;
    if (_edgeSpeed == 0) {
      _edgeTimer?.cancel();
      _edgeTimer = null;
      return;
    }
    _edgeTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scroll.hasClients || _edgeSpeed == 0) return;
      final pos = _scroll.position;
      final to = (pos.pixels + _edgeSpeed * 14).clamp(0.0, pos.maxScrollExtent);
      if (to != pos.pixels) _scroll.jumpTo(to);
    });
  }

  List<Widget> _menuChildren(AppLocalizations l10n, int count) {
    final a = widget.actions;
    final menu = _openMenu;
    if (a == null || menu == null) return const [];
    final enabled = _canChange;
    List<Widget> insertAt(int index, String prefix) => pageInsertMenuChildren(
      l10n,
      orientation: a.orientation,
      onOrientation: a.setOrientation,
      color: a.color,
      onColor: a.setColor,
      onInsert: enabled ? (t) => _insert(index, t) : null,
      keyPrefix: prefix,
    );
    switch (menu) {
      case _InsertMenu(:final index):
        return insertAt(index, 'panel-insert');
      case _PagesMenu(:final pages):
        final first = pages.reduce((a, b) => a < b ? a : b);
        final last = pages.reduce((a, b) => a > b ? a : b);
        return [
          MenuItemButton(
            key: const ValueKey('panel-rotate-right'),
            leadingIcon: const Icon(LucideIcons200.rotateCw),
            onPressed: enabled ? () => _rotate(pages, 1) : null,
            child: Text(l10n.rotateRight),
          ),
          MenuItemButton(
            key: const ValueKey('panel-rotate-left'),
            leadingIcon: const Icon(LucideIcons200.rotateCcw),
            onPressed: enabled ? () => _rotate(pages, -1) : null,
            child: Text(l10n.rotateLeft),
          ),
          menuSeparator,
          MenuItemButton(
            key: const ValueKey('panel-move-up'),
            leadingIcon: const Icon(LucideIcons200.arrowUp),
            onPressed: enabled && first > 0 ? () => _moveBy(pages, -1) : null,
            child: Text(l10n.movePageUp),
          ),
          MenuItemButton(
            key: const ValueKey('panel-move-down'),
            leadingIcon: const Icon(LucideIcons200.arrowDown),
            onPressed: enabled && last < count - 1
                ? () => _moveBy(pages, 1)
                : null,
            child: Text(l10n.movePageDown),
          ),
          menuSeparator,
          SubmenuButton(
            key: const ValueKey('panel-insert-before'),
            leadingIcon: const Icon(LucideIcons200.filePlus2),
            menuChildren: insertAt(first, 'panel-before'),
            child: Text(l10n.insertPageBefore),
          ),
          SubmenuButton(
            key: const ValueKey('panel-insert-after'),
            leadingIcon: const Icon(LucideIcons200.filePlus2),
            menuChildren: insertAt(last + 1, 'panel-after'),
            child: Text(l10n.insertPageAfter),
          ),
          menuSeparator,
          SubmenuButton(
            key: const ValueKey('panel-as-image'),
            leadingIcon: const Icon(LucideIcons200.fileImage),
            menuChildren: [
              MenuItemButton(
                key: const ValueKey('panel-image-copy'),
                leadingIcon: const Icon(LucideIcons200.copy),
                onPressed: a.images != null && pages.length == 1
                    ? () => a.images!(pages, CaptureAction.copy)
                    : null,
                child: Text(
                  pages.length == 1 ? l10n.copy : l10n.copyOnePageOnly,
                ),
              ),
              MenuItemButton(
                key: const ValueKey('panel-image-save'),
                leadingIcon: const Icon(LucideIcons200.download),
                onPressed: a.images == null
                    ? null
                    : () => a.images!(pages, CaptureAction.save),
                child: Text(l10n.captureSave),
              ),
              MenuItemButton(
                key: const ValueKey('panel-image-share'),
                leadingIcon: const Icon(LucideIcons200.share2),
                onPressed: a.images == null
                    ? null
                    : () => a.images!(pages, CaptureAction.share),
                child: Text(l10n.captureShare),
              ),
            ],
            child: Text(l10n.pagesAsImage),
          ),
          menuSeparator,
          MenuItemButton(
            key: const ValueKey('panel-delete'),
            leadingIcon: const Icon(LucideIcons200.trash2),
            onPressed: enabled && pages.length < count
                ? () => _delete(pages)
                : null,
            child: Text(l10n.deletePages(pages.length)),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final session = widget.session;
    return AnimatedContainer(
      key: const ValueKey('page-panel'),
      duration: Motion.normal,
      curve: Motion.curve,
      width: _outline ? PagePanel.outlineWidth : PagePanel.width,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: Column(
        children: [
          _PanelTabs(outline: _outline, onChanged: _showOutline),
          Expanded(
            child: _outline
                ? _OutlineView(viewer: widget.viewer)
                : _list(context, l10n, session),
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    InkSession? session,
  ) => Semantics(
    container: true,
    label: l10n.pagePanelTitle,
    child: ListenableBuilder(
      listenable: Listenable.merge([widget.viewer, ?session]),
      builder: (context, _) {
        final viewer = widget.viewer;
        final count = viewer.pageCount;
        final pages = session?.document.pages;
        // Sayfa ekleme / silme sürerken model ile gösterilen kopya
        // uyuşmayabilir; o sırada çizimler küçük resme çizilmez.
        final layers = pages != null && pages.length == count ? pages : null;
        final selected = {
          for (final i in _selected)
            if (i < count) i,
        };
        final hasActions = widget.actions != null;
        final list = ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: _listPadding),
          itemCount: count,
          itemExtentBuilder: (i, _) => _extentFor(_aspect(i)),
          itemBuilder: (context, i) {
            final current = viewer.currentPage == i;
            final slot = _dropSlot;
            final tile = _PageTile(
              index: i,
              current: current,
              selected: selected.contains(i),
              controls: hasActions && (current || _hover == i),
              width: _imageWidth,
              thumbHeight: _imageWidth / _aspect(i),
              border: _border,
              labelHeight: _labelHeight,
              thumbnail: PageThumbnail(
                controller: viewer,
                pageIndex: i,
                colorFilter: widget.night ? NightMode.pageFilter : null,
              ),
              layer: layers?[i],
              night: widget.night,
              session: session,
              onTap: () => _tap(i),
              // Dokunmatikte uzun basış sürükleyiciye ait ([_draggable]).
              onLongPress: null,
              onHover: (on) {
                if (on == (_hover == i)) return;
                setState(() => _hover = on ? i : null);
              },
              onMenu: hasActions
                  ? (at) => _showMenu(_PagesMenu(_targets(i)), at)
                  : null,
              onAdd: hasActions
                  ? (at) => _showMenu(_InsertMenu(i + 1), at)
                  : null,
              dropBefore: slot == i,
              dropAfter: slot == count && i == count - 1,
              dimmed: _dragging?.contains(i) ?? false,
            );
            if (!hasActions) return tile;
            return _draggable(i, count, viewer, tile);
          },
        );
        final body = MenuAnchor(
          controller: _menu,
          menuChildren: _menuChildren(l10n, count),
          child: KeyedSubtree(key: _menuAnchor, child: list),
        );
        if (selected.isEmpty) return body;
        return Column(
          children: [
            _SelectionStrip(
              count: selected.length,
              enabled: _canChange,
              canDelete: selected.length < count,
              canMoveUp: selected.reduce(math.min) > 0,
              canMoveDown: selected.reduce(math.max) < count - 1,
              onMove: (dir) => _moveBy(selected, dir),
              onRotate: (turns) => _rotate(selected, turns),
              onDelete: () => _delete(selected),
              onClear: _clearSelection,
            ),
            Expanded(child: body),
          ],
        );
      },
    ),
  );
}

extension on _PagePanelState {
  /// Sayfa kutusunu sürüklenebilir ve bırakma hedefi yapar. Fare: hemen
  /// sürüklenir (seçiliyse seçimle). Dokunmatik ve kalem: uzun basış sayfayı
  /// seçer ve kaldırır; kıpırdamadan bırakılırsa yalnızca seçim kalır.
  Widget _draggable(
    int i,
    int count,
    InkenViewerController viewer,
    Widget tile,
  ) {
    final enabled = _canChange && count > 1;
    final mouseData = _selected.contains(i) ? {..._selected} : {i};
    final touchData = {..._selected, i};
    Widget feedback(Set<int> pages) => _DragFeedback(
      viewer: viewer,
      page: i,
      count: pages.length,
      width: _PagePanelState._imageWidth * 0.7,
      aspect: _aspect(i),
      night: widget.night,
    );
    final target = Builder(
      builder: (context) => DragTarget<Set<int>>(
        onWillAcceptWithDetails: (_) => _canChange,
        onMove: (d) => _dragOver(i, context, d.offset),
        onAcceptWithDetails: (d) => _drop(d.data),
        builder: (context, _, _) => tile,
      ),
    );
    if (!enabled) {
      return GestureDetector(
        onLongPress: widget.actions == null ? null : () => _longPress(i),
        child: target,
      );
    }
    return _DeviceDraggable<Set<int>>(
      data: mouseData,
      devices: const {PointerDeviceKind.mouse},
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback(mouseData),
      onDragStarted: () => _dragStart(mouseData),
      onDragUpdate: (d) => _dragUpdate(d.globalPosition),
      onDragEnd: (_) => _dragEnd(),
      onDraggableCanceled: (_, _) => _dragEnd(),
      child: _DeviceDraggable<Set<int>>(
        data: touchData,
        devices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        delay: kLongPressTimeout,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback(touchData),
        // Seçim şeridi sürüklerken açılmaz (liste parmağın altında
        // kaymasın): kıpırdamadan bırakılırsa bırakınca açılır.
        onDragStarted: () {
          HapticFeedback.selectionClick();
          _dragStart(touchData);
        },
        onDragUpdate: (d) => _dragUpdate(d.globalPosition),
        onDragEnd: (_) {
          final moved = _dropped;
          _dragEnd();
          if (!moved) _longPress(i, haptic: false);
        },
        // Bırakma hedefi dışında bırakılırsa onDragEnd yine çağrılır.
        onDraggableCanceled: (_, _) => _dragEnd(),
        child: target,
      ),
    );
  }
}

/// Yalnızca [devices] işaretçileriyle sürüklenen [Draggable]; [delay]
/// verilirse uzun basışla başlar ([LongPressDraggable] gibi). Fare hemen
/// sürüklesin, dokunmatik listeyi kaydırabilsin diye.
class _DeviceDraggable<T extends Object> extends Draggable<T> {
  const _DeviceDraggable({
    required super.child,
    required super.feedback,
    required this.devices,
    super.data,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
    super.onDraggableCanceled,
    this.delay,
  });

  final Set<PointerDeviceKind> devices;
  final Duration? delay;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    final delay = this.delay;
    if (delay == null) {
      return ImmediateMultiDragGestureRecognizer(supportedDevices: devices)
        ..onStart = onStart;
    }
    return DelayedMultiDragGestureRecognizer(
        delay: delay,
        supportedDevices: devices,
      )
      // Titreşim seçimden gelir (_longPress).
      ..onStart = onStart;
  }
}

/// Sürüklenen sayfanın küçük resmi; birden çok sayfada sayısı.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.viewer,
    required this.page,
    required this.count,
    required this.width,
    required this.aspect,
    required this.night,
  });

  final InkenViewerController viewer;
  final int page;
  final int count;
  final double width;
  final double aspect;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FractionalTranslation(
      // İmleç küçük resmin ortasında.
      translation: const Offset(-0.5, -0.5),
      child: Opacity(
        opacity: 0.9,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width,
              height: width / aspect,
              decoration: BoxDecoration(
                border: Border.all(color: c.brand, width: 2),
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: c.shadowPop,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm - 2),
                child: PageThumbnail(
                  controller: viewer,
                  pageIndex: page,
                  colorFilter: night ? NightMode.pageFilter : null,
                ),
              ),
            ),
            if (count > 1)
              Positioned(
                right: -Space.s2,
                top: -Space.s2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.brand,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    '$count',
                    style: InkenText.caption.copyWith(color: c.onBrand),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Panelin üstündeki sekmeler: sayfalar · içindekiler.
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.outline, required this.onChanged});

  final bool outline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    Widget tab(String id, bool on, IconData icon, String label) => Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          key: ValueKey('panel-tab-$id'),
          onTap: () => onChanged(id == 'outline'),
          child: Semantics(
            button: true,
            selected: on == outline,
            label: label,
            excludeSemantics: true,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: on == outline ? c.brand : c.line,
                    width: on == outline ? 2 : 1,
                  ),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: on == outline ? c.brand : c.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        tab('pages', false, LucideIcons200.layoutGrid, l10n.pagePanelPages),
        tab('outline', true, LucideIcons200.listTree, l10n.outline),
      ],
    );
  }
}

/// İçindekiler ağacı: başlığa dokunmak o sayfaya gider; alt başlıklar
/// açılıp kapanır. Geçerli sayfanın bölümü vurgulu. Belge yeniden
/// yüklenince (sayfa ekle / sil) ağaç yeniden okunur.
class _OutlineView extends StatefulWidget {
  const _OutlineView({required this.viewer});

  final InkenViewerController viewer;

  @override
  State<_OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends State<_OutlineView> {
  Future<List<InkenOutlineItem>>? _items;
  int? _loadedFor;

  /// Açık başlıklar (yol: kök sıralarından, ör. "1.0").
  final Set<String> _expanded = {};

  void _reload() {
    final viewer = widget.viewer;
    if (!viewer.isReady || _loadedFor == viewer.documentGeneration) return;
    _loadedFor = viewer.documentGeneration;
    _items = viewer.loadOutline();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return ListenableBuilder(
      listenable: widget.viewer,
      builder: (context, _) {
        _reload();
        return FutureBuilder<List<InkenOutlineItem>>(
          future: _items,
          builder: (context, snap) {
            final items = snap.data;
            if (items == null) return const SizedBox.shrink();
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(Space.s4),
                child: Text(
                  l10n.outlineEmpty,
                  key: const ValueKey('outline-empty'),
                  style: InkenText.caption.copyWith(color: c.inkMuted),
                ),
              );
            }
            final rows = <(InkenOutlineItem, int, String)>[];
            void walk(List<InkenOutlineItem> list, int depth, String path) {
              for (final (i, item) in list.indexed) {
                final id = path.isEmpty ? '$i' : '$path.$i';
                rows.add((item, depth, id));
                if (_expanded.contains(id)) walk(item.children, depth + 1, id);
              }
            }

            walk(items, 0, '');
            // Geçerli bölüm: geçerli sayfadan önce başlayan son görünen başlık.
            final current = widget.viewer.currentPage ?? 0;
            String? active;
            for (final (item, _, id) in rows) {
              final p = item.page;
              if (p != null && p <= current) active = id;
            }
            return ListView.builder(
              key: const ValueKey('outline-list'),
              padding: const EdgeInsets.symmetric(vertical: Space.s2),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final (item, depth, id) = rows[i];
                return _OutlineRow(
                  item: item,
                  depth: depth,
                  id: id,
                  active: id == active,
                  expanded: _expanded.contains(id),
                  onToggle: () => setState(() {
                    if (!_expanded.remove(id)) _expanded.add(id);
                  }),
                  onTap: item.page == null
                      ? null
                      : () => widget.viewer.goToPage(item.page!, top: item.top),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({
    required this.item,
    required this.depth,
    required this.id,
    required this.active,
    required this.expanded,
    required this.onToggle,
    required this.onTap,
  });

  final InkenOutlineItem item;
  final int depth;
  final String id;
  final bool active;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    const toggle = 28.0;
    final page = item.page;
    return InkWell(
      key: ValueKey('outline-$id'),
      onTap: onTap,
      hoverColor: c.surfaceHover,
      child: Container(
        color: active ? c.brandTint : null,
        constraints: const BoxConstraints(minHeight: 36),
        padding: EdgeInsets.only(
          left: Space.s1 + depth * Space.s3,
          right: Space.s3,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: toggle,
              child: item.children.isEmpty
                  ? null
                  : IconButton(
                      key: ValueKey('outline-toggle-$id'),
                      tooltip: expanded
                          ? l10n.outlineCollapse
                          : l10n.outlineExpand,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tight(
                        const Size.square(toggle),
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: c.inkMuted,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        expanded
                            ? LucideIcons200.chevronDown
                            : LucideIcons200.chevronRight,
                        size: 16,
                      ),
                      onPressed: onToggle,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s2),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: InkenText.body.copyWith(
                    fontSize: 13,
                    color: page == null ? c.inkFaint : c.ink,
                    fontWeight: active || depth == 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (page != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.s2),
                child: Text(
                  '${page + 1}',
                  style: InkenText.numeric.copyWith(
                    fontSize: 12,
                    color: c.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Seçim varken panelin üstündeki şerit: kaç sayfa seçili; döndür, sil,
/// seçimi kaldır.
/// Seçim şeridindeki düğmelerin kenarı.
const double _stripButton = 30;

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({
    required this.count,
    required this.enabled,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onRotate,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final bool enabled;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;

  /// Bir sıra yukarı (-1) / aşağı (1).
  final ValueChanged<int> onMove;
  final ValueChanged<int> onRotate;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    Widget button(String id, IconData icon, String tip, VoidCallback? on) =>
        IconButton(
          key: ValueKey('panel-selection-$id'),
          tooltip: tip,
          onPressed: on,
          icon: Icon(icon, size: 18),
          // Beş düğme panelin iç genişliğine (~150 px) sığmalı; arayüz
          // boyutu büyüyünce de bütün düzen birlikte ölçeklenir.
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tight(const Size.square(_stripButton)),
          style: IconButton.styleFrom(
            foregroundColor: c.ink,
            disabledForegroundColor: c.inkFaint,
            // Dokunmatik platformlarda 48 px'e büyütülmesin (taşar).
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
    return Container(
      key: const ValueKey('panel-selection'),
      padding: const EdgeInsets.fromLTRB(Space.s3, Space.s2, Space.s1, 0),
      decoration: BoxDecoration(
        color: c.brandTint,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pagesSelected(count),
                  style: InkenText.caption.copyWith(color: c.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              button(
                'clear',
                LucideIcons200.x,
                l10n.clearPageSelection,
                onClear,
              ),
            ],
          ),
          Row(
            children: [
              button(
                'move-up',
                LucideIcons200.arrowUp,
                l10n.movePageUp,
                enabled && canMoveUp ? () => onMove(-1) : null,
              ),
              button(
                'move-down',
                LucideIcons200.arrowDown,
                l10n.movePageDown,
                enabled && canMoveDown ? () => onMove(1) : null,
              ),
              button(
                'rotate-left',
                LucideIcons200.rotateCcw,
                l10n.rotateLeft,
                enabled ? () => onRotate(-1) : null,
              ),
              button(
                'rotate-right',
                LucideIcons200.rotateCw,
                l10n.rotateRight,
                enabled ? () => onRotate(1) : null,
              ),
              button(
                'delete',
                LucideIcons200.trash2,
                l10n.deletePages(count),
                enabled && canDelete ? onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sayfa panelinin sekmesi, belge alanının sol kenarında, dikey ortada (perde
/// tutamağının dik duranı). Panelin dışındadır, böylece panelin kaydırma
/// çubuğuyla çakışmaz: kapalıyken açar (dokunmak ya da sağa çekmek), açıkken
/// panelin sağ kenarına bitişik durur ve kapatır (dokunmak ya da sola çekmek).
class PanelGrip extends StatelessWidget {
  const PanelGrip({super.key, required this.opens, required this.onTap});

  /// `true`: kapalı paneli açar; `false`: açık paneli kapatır.
  final bool opens;
  final VoidCallback onTap;

  /// Sekmenin genişliği.
  static const double width = Space.s4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final label = opens ? l10n.pagePanelOpen : l10n.pagePanelClose;
    final bar = Container(
      width: 5,
      height: Sizes.target,
      decoration: BoxDecoration(
        color: c.lineStrong,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    );
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: ValueKey(opens ? 'page-panel-open' : 'page-panel-close'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (opens ? v > 0 : v < 0) onTap();
          },
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            // Belgenin koyu zemininde seçilsin: panel renginde sekme (açıkken
            // panelin devamı gibi görünür).
            child: Container(
              width: width,
              height: Sizes.target + Space.s4,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(Radii.md),
                ),
                border: Border(
                  top: BorderSide(color: c.line),
                  right: BorderSide(color: c.line),
                  bottom: BorderSide(color: c.line),
                ),
                boxShadow: c.shadowPop,
              ),
              child: Center(child: bar),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.index,
    required this.current,
    required this.selected,
    required this.controls,
    required this.width,
    required this.thumbHeight,
    required this.border,
    required this.labelHeight,
    required this.thumbnail,
    required this.layer,
    required this.session,
    required this.night,
    required this.onTap,
    required this.onLongPress,
    required this.onHover,
    required this.onMenu,
    required this.onAdd,
    this.dropBefore = false,
    this.dropAfter = false,
    this.dimmed = false,
  });

  /// Sürüklenen sayfalar bu sayfanın önüne / arkasına bırakılacak: kenarda
  /// çizgi.
  final bool dropBefore;
  final bool dropAfter;

  /// Sürüklenen sayfalardan biri: soluk.
  final bool dimmed;

  final int index;
  final bool current;
  final bool selected;

  /// "⋯" ve "+" düğmeleri görünsün mü (geçerli ya da fare üstündeki sayfa).
  final bool controls;
  final double width;
  final double thumbHeight;
  final double border;
  final double labelHeight;
  final Widget thumbnail;
  final PageLayer? layer;
  final InkSession? session;
  final bool night;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool> onHover;

  /// Sayfa menüsünü verilen ekran noktasında açar (sağ tık, "⋯").
  final ValueChanged<Offset>? onMenu;

  /// Arkasına ekleme menüsünü açar ("+").
  final ValueChanged<Offset>? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final layer = this.layer;
    // Döndürme sonrası yeniden yüklenirken model ile küçük resmin oranı
    // bir an uyuşmayabilir; o arada çizimler çizilmez.
    final paintLayer =
        layer != null &&
        layer.items.isNotEmpty &&
        layer.height > 0 &&
        ((layer.width / layer.height) - width / thumbHeight).abs() < 0.02;

    Widget control(
      String id,
      IconData icon,
      String tip,
      ValueChanged<Offset> on,
    ) => Builder(
      builder: (context) => IconButton(
        key: ValueKey('page-$id-$index'),
        tooltip: tip,
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(Size.square(labelHeight)),
        style: IconButton.styleFrom(
          foregroundColor: c.inkMuted,
          hoverColor: c.surfaceHover,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          final box = context.findRenderObject()! as RenderBox;
          on(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
        },
      ),
    );

    final onMenu = this.onMenu;
    final onAdd = this.onAdd;
    Widget line() => Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: Space.s2),
      decoration: BoxDecoration(
        color: c.brand,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    );
    final body = Semantics(
      button: true,
      selected: current || selected,
      label: l10n.pageThumbnail(index + 1),
      child: InkWell(
        key: ValueKey('page-thumb-$index'),
        onTap: onTap,
        onLongPress: onLongPress,
        onHover: onHover,
        onSecondaryTapUp: onMenu == null
            ? null
            : (d) => onMenu(d.globalPosition),
        hoverColor: c.surfaceHover,
        child: Container(
          color: selected ? c.brandTint : null,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s4,
            vertical: Space.s2,
          ),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: width + 2 * border,
                  height: thumbHeight + 2 * border,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: current || selected ? c.brand : c.line,
                      width: border,
                    ),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.sm - border),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbnail,
                        if (paintLayer)
                          CustomPaint(
                            painter: _LayerPainter(
                              layer,
                              session?.images,
                              night ? nightInkColor : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.s1),
              SizedBox(
                height: labelHeight,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: labelHeight,
                      child: controls && onMenu != null
                          ? control(
                              'menu',
                              LucideIcons200.ellipsis,
                              l10n.pageActions,
                              onMenu,
                            )
                          : null,
                    ),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: InkenText.numeric.copyWith(
                            fontSize: 12,
                            color: current ? c.brand : c.inkMuted,
                            fontWeight: current
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: labelHeight,
                      child: controls && onAdd != null
                          ? control(
                              'add',
                              LucideIcons200.plus,
                              l10n.insertPageAfter,
                              onAdd,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Stack(
        children: [
          body,
          if (dropBefore) Positioned(left: 0, right: 0, top: 0, child: line()),
          if (dropAfter)
            Positioned(left: 0, right: 0, bottom: 0, child: line()),
        ],
      ),
    );
  }
}

/// Bir sayfanın çizimleri, küçük resmin boyutuna ölçeklenmiş. Metin font
/// olmadan (küçük boyda fark edilmez).
class _LayerPainter extends CustomPainter {
  _LayerPainter(this.layer, this.images, this.recolor) : super(repaint: images);

  /// Gece modunda çizim renkleri.
  final InkRecolor? recolor;

  final PageLayer layer;

  /// Görseller (çözülünce yeniden çizilir).
  final InkImages? images;

  @override
  void paint(Canvas canvas, Size size) {
    if (layer.width <= 0) return;
    canvas.scale(size.width / layer.width);
    for (final item in layer.items) {
      paintItem(canvas, item, null, images, recolor);
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) =>
      !identical(old.layer.items, layer.items) || old.recolor != recolor;
}
