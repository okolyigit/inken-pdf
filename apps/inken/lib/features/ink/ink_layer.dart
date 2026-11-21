import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';

import '../../l10n/app_localizations.dart';
import 'draw_gesture.dart';
import 'fading_ink.dart';
import '../viewer/night_mode.dart';
import 'ink_painter.dart';
import 'ink_session.dart';
import 'instruments.dart';
import 'item_clipboard.dart';
import 'selection_bar.dart';
import 'text_font_provider.dart';
import 'tool_state.dart';

/// Görüntüleyicinin ([child]) üstüne çizim katmanını ve çizim girdisini
/// ekler. Çizmeyen girdiler (gezinme aracı, kalem modunda parmak, fare
/// tekerleği) dokunulmadan görüntüleyiciye ulaşır.
class InkLayer extends ConsumerStatefulWidget {
  const InkLayer({
    super.key,
    required this.geometry,
    required this.session,
    required this.child,
  });

  final PageGeometry geometry;
  final InkSession session;

  /// PDF görüntüleyici; bu katmanla aynı kutuyu doldurmalıdır.
  final Widget child;

  @override
  ConsumerState<InkLayer> createState() => _InkLayerState();
}

class _InkLayerState extends ConsumerState<InkLayer>
    with SingleTickerProviderStateMixin {
  final InkPictureCache _cache = InkPictureCache();

  /// Geçici kalemin solarak kaybolan çizgileri.
  late final FadingInk _fading = FadingInk(this);

  /// Silgi dairesinin ekrandaki merkezi (gösterge); yoksa `null`.
  final ValueNotifier<Offset?> _cursorAt = ValueNotifier(null);
  bool _laser = false;
  bool _shaping = false;

  /// Etkin hareketin sayfası ve türü.
  PageViewport? _view;

  /// Çizgi bir ölçme aracının kenarına yaslanıyor (cetvel, gönye, iletki);
  /// noktalar kenara taşınır.
  InstrumentSnap? _snap;

  /// Çizginin yarı kalınlığı (pt): yaslanan çizgi aracın dışında kalır.
  double _snapHalfWidth = 0;

  /// Hareketin ekrandaki konumu; yaslanıyorsa kenarın üstünde.
  Offset _at(PointerEvent e, PageViewport view) =>
      _snap?.apply(e.localPosition, _snapHalfWidth * view.scale) ??
      e.localPosition;
  bool _erasing = false;

  /// Silme, kalemin düğmesiyle (araç silgi değilken) başladı: düğme
  /// bırakılınca durur.
  bool _buttonErasing = false;

  /// Düğme bu temasta bırakıldı: kalem kalkana kadar hiçbir şey yapılmaz
  /// (bırakırken kazara çizgi çıkmasın).
  bool _idleUntilLift = false;
  _SelectGesture _select = _SelectGesture.none;

  /// Fare hangi tutamağın üzerinde (boyutlandırma imleci için); yoksa `null`.
  int? _overHandle;

  /// Taşımanın başladığı nokta (sayfa uzayı).
  Offset? _moveFrom;

  /// Fare seçimin üzerinde mi (taşıma imleci için)?
  bool _overSelection = false;

  /// Dokunma payı (ekran pikseli): öğeye dokunarak seçme ve seçim kutusu.
  static const double _hitSlop = 8;
  Offset? _lastErasePoint;

  // ---- metin

  /// Açık yazma kutusunun taslağı (konum, renk, büyüklük); yazı
  /// [_textController]'da. Kutu kapalıyken `null`.
  TextItem? _draft;
  int? _draftPage;
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _textFocus = FocusNode(debugLabel: 'metin')
    ..addListener(() {
      if (!_textFocus.hasFocus) _commitText();
    });
  final GlobalKey _editorKey = GlobalKey();

  /// Çizim renginin ekrandaki karşılığı (gece modunda açık ton).
  int _screenColor(int argb) =>
      ref.watch(nightModeProvider) ? nightInkColor(argb) : argb;

  /// Metin aracında hareketin başladığı nokta (sayfa uzayı).
  Offset? _textDown;

  TextFont? get _font => ref.read(textFontProvider)?.font;

  /// [p]'deki metni düzenlemeye açar ya da oraya yeni yazma kutusu koyar.
  void _openTextAt(PageViewport view, Offset p) {
    _commitText();
    final layer = widget.session.document.pages[view.index];
    final hitId = itemAt(layer, p.dx, p.dy, _hitSlop / view.scale);
    final hit = layer.items.whereType<TextItem>().where((i) => i.id == hitId);
    final TextItem draft;
    if (hit.isNotEmpty) {
      draft = hit.first;
      widget.session.beginTextEdit(view.index, id: draft.id);
    } else {
      final tools = ref.read(toolProvider);
      final size = textSizes[tools.textSize];
      final factor = ref.read(textFontProvider)?.lineHeightFactor ?? 1.2;
      // İmleç dokunulan yerin ortasında olsun.
      draft = TextItem(
        id: '',
        text: '',
        color: tools.textColor,
        fontSize: size,
        x: p.dx.clamp(0, layer.width),
        y: (p.dy - size * factor / 2).clamp(0, layer.height),
        width: 0,
        height: 0,
      );
      widget.session.beginTextEdit(view.index);
    }
    setState(() {
      _draft = draft;
      _draftPage = view.index;
      _textController.text = draft.text;
      _textController.selection = TextSelection.collapsed(
        offset: draft.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _draft != null) _textFocus.requestFocus();
    });
  }

  /// Yazma kutusunu kapatır; yazıyı ölçüp modele işler.
  void _commitText() {
    final draft = _draft;
    if (draft == null) return;
    _draft = null;
    _draftPage = null;
    final text = _textController.text;
    final font = _font;
    final result = draft.copyWith(text: text);
    widget.session.endTextEdit(
      font == null
          ? _measureWithoutFont(result)
          : measureTextItem(font, result),
    );
    _textController.clear();
    if (_disposing) return;
    if (_textFocus.hasFocus) _textFocus.unfocus();
    if (mounted) setState(() {});
  }

  /// Font yüklenemediyse kaba ölçü (yalnızca seçim ve silgi için).
  static TextItem _measureWithoutFont(TextItem t) {
    final lines = t.text.split('\n');
    final longest = lines.fold(0, (m, l) => l.length > m ? l.length : m);
    return t.copyWith(
      width: longest * t.fontSize * 0.6,
      height: lines.length * t.fontSize * 1.2,
    );
  }

  /// Yazma kutusunun ekrandaki dikdörtgeni (dokunuşlar ona bırakılır).
  final GlobalKey _barKey = GlobalKey();

  bool _insideBar(Offset global) {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  bool _insideEditor(Offset global) {
    final box = _editorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(global);
  }

  Widget _editor(BuildContext context) {
    final draft = _draft;
    final page = _draftPage;
    if (draft == null || page == null) return const SizedBox.shrink();
    final c = context.colors;
    final factor = ref.read(textFontProvider)?.lineHeightFactor ?? 1.2;
    return ListenableBuilder(
      listenable: widget.geometry,
      builder: (context, _) {
        final view = widget.geometry.viewportOf(page);
        if (view == null) return const SizedBox.shrink();
        final at = view.toView(Offset(draft.x, draft.y));
        final size = draft.fontSize * view.scale;
        const pad = Space.s1;
        final style = TextStyle(
          fontFamily: InkenTextFont.family,
          fontSize: size,
          height: factor,
          color: Color(_screenColor(draft.color)),
          leadingDistribution: TextLeadingDistribution.even,
        );
        return Stack(
          children: [
            Positioned(
              left: at.dx - pad,
              top: at.dy - pad,
              child: Container(
                key: _editorKey,
                padding: const EdgeInsets.all(pad - 1),
                decoration: BoxDecoration(
                  border: Border.all(color: c.brand.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: size),
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              _textFocus.unfocus,
                        },
                        child: TextField(
                          key: const ValueKey('text-editor'),
                          controller: _textController,
                          focusNode: _textFocus,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: style,
                          strutStyle: StrutStyle(
                            fontFamily: InkenTextFont.family,
                            fontSize: size,
                            height: factor,
                            forceStrutHeight: true,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          cursorColor: Color(_screenColor(draft.color)),
                          decoration: const InputDecoration.collapsed(
                            hintText: null,
                          ),
                          onTapOutside: (_) => _textFocus.unfocus(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _disposing = false;

  @override
  void dispose() {
    _disposing = true;
    // Belge kapanırken açık kalan yazı kaybolmasın.
    if (_draft != null) {
      try {
        _commitText();
      } on Object catch (e) {
        debugPrint('Metin işlenemedi: $e');
      }
    }
    _textFocus.dispose();
    _textController.dispose();
    _cache.dispose();
    _fading.dispose();
    _cursorAt.dispose();
    super.dispose();
  }

  bool _isStylus(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  bool _accepts(PointerDownEvent e) {
    if (_isStylus(e)) ref.read(toolProvider.notifier).noteStylus();
    final tools = ref.read(toolProvider);
    // El ve metin seçme araçlarında dokunuş görüntüleyicinindir.
    if (tools.tool == Tool.hand ||
        tools.tool == Tool.textSelect ||
        !widget.geometry.isReady) {
      return false;
    }
    // Yazma kutusunun içi metin alanına aittir (imleç, seçme).
    if (_draft != null && _insideEditor(e.position)) return false;
    // Seçim çubuğunun düğmeleri kendi dokunuşlarını alır.
    if (_insideBar(e.position)) return false;
    final draws = switch (e.kind) {
      PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
      PointerDeviceKind.mouse => e.buttons == kPrimaryMouseButton,
      PointerDeviceKind.touch => tools.touchDraws,
      _ => false,
    };
    // Sayfaların dışında başlayan hareket görüntüleyiciye kalır; seçimin
    // sayfa dışına taşan tutamakları hariç.
    return draws &&
        (widget.geometry.pageAt(e.localPosition) != null ||
            (tools.tool == Tool.select &&
                _handleViewAt(e.localPosition) != null));
  }

  /// Kalemin silgi ucu ya da yan düğmesi silgi sayılır.
  bool _wantsEraser(PointerEvent e) =>
      ref.read(toolProvider).tool == Tool.eraser || _stylusErases(e);

  /// Kalemin silgi ucu ya da basılı yan düğmesi (araç değişmeden siler).
  bool _stylusErases(PointerEvent e) =>
      e.kind == PointerDeviceKind.invertedStylus ||
      (_isStylus(e) &&
          e.buttons & (kPrimaryStylusButton | kSecondaryStylusButton) != 0);

  /// Yazarken kalemin düğmesine basıldı: o ana kadar yazılan kalır, temas
  /// silgiyle sürer.
  void _switchToButtonEraser(PageViewport view, PointerEvent e) {
    if (_laser) {
      _fading.end();
      _laser = false;
    } else {
      widget.session.endStroke();
    }
    final tools = ref.read(toolProvider);
    final p = view.toPage(e.localPosition);
    _erasing = true;
    _buttonErasing = true;
    widget.session.beginErase(
      view.index,
      pixel: tools.eraserMode == EraserMode.pixel,
    );
    _lastErasePoint = p;
    _cursorAt.value = e.localPosition;
    widget.session.eraseSegment(
      p.dx,
      p.dy,
      p.dx,
      p.dy,
      tools.eraserRadius / view.scale,
    );
  }

  /// Cihaz gerçek basınç bildiriyorsa 0..1'e ölçekler, yoksa `null`.
  double? _pressure(PointerEvent e) {
    if (!_isStylus(e) || e.pressureMax <= e.pressureMin) return null;
    final p = (e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin);
    // Bazı sürücüler kalem için hep 0 ya da 1 verir: basınç yok say.
    return (p <= 0 || p >= 1) && !_pressureVaries ? null : p.clamp(0.0, 1.0);
  }

  bool _pressureVaries = false;
  double? _firstPressure;

  void _trackPressure(PointerEvent e) {
    if (!_isStylus(e)) return;
    _firstPressure ??= e.pressure;
    if ((e.pressure - _firstPressure!).abs() > 0.02) _pressureVaries = true;
  }

  /// [local] seçimin bir tutamağının üzerindeyse seçimin sayfası.
  PageViewport? _handleViewAt(Offset local) {
    final page = widget.session.selectionPage;
    if (page == null) return null;
    final view = widget.geometry.viewportOf(page);
    if (view == null || _handleAt(view, local) == null) return null;
    return view;
  }

  /// Kendi imleci olan araçlar (sistem imleci gizlenir, katman çizer).
  static bool _ownCursor(Tool tool) =>
      tool == Tool.eraser ||
      tool == Tool.pen ||
      tool == Tool.highlighter ||
      tool == Tool.laser;

  /// Çizerken imleç kalemin ucunu izler (parmakta imleç yok).
  void _followCursor(PointerEvent e) {
    if (e.kind == PointerDeviceKind.touch) return;
    if (_erasing || _ownCursor(ref.read(toolProvider).tool)) {
      _cursorAt.value = e.localPosition;
    }
  }

  void _onStart(PointerEvent e) {
    _followCursor(e);
    final view =
        (ref.read(toolProvider).tool == Tool.select
            ? _handleViewAt(e.localPosition)
            : null) ??
        widget.geometry.pageAt(e.localPosition);
    if (view == null) return;
    _view = view;
    _erasing = _wantsEraser(e);
    _buttonErasing = _erasing && ref.read(toolProvider).tool != Tool.eraser;
    _idleUntilLift = false;
    final p = view.toPage(e.localPosition);
    final tools = ref.read(toolProvider);
    if (!_erasing && tools.tool == Tool.select) {
      _startSelect(view, p);
      return;
    }
    if (_erasing) {
      widget.session.beginErase(
        view.index,
        pixel: tools.eraserMode == EraserMode.pixel,
      );
      _lastErasePoint = p;
      _cursorAt.value = e.localPosition;
      widget.session.eraseSegment(
        p.dx,
        p.dy,
        p.dx,
        p.dy,
        tools.eraserRadius / view.scale,
      );
      return;
    }
    if (tools.tool == Tool.text) {
      _textDown = p;
      return;
    }
    if (tools.tool == Tool.shape) {
      _shaping = true;
      widget.session.beginShape(
        page: view.index,
        kind: tools.shapeKind,
        color: tools.shapeColor,
        width: penWidths[tools.shapeWidth],
        x: p.dx,
        y: p.dy,
      );
      return;
    }
    _snap = snapsToInstruments(tools.tool)
        ? InstrumentSnap.find(
            ref.read(instrumentsProvider).values,
            widget.geometry,
            e.localPosition,
          )
        : null;
    _laser = tools.tool == Tool.laser;
    _snapHalfWidth = (_laser ? laserWidth : tools.strokeWidth) / 2;
    if (_laser) {
      final p = view.toPage(_at(e, view));
      _fading.begin(
        view.index,
        minDistance: 0.5 / view.scale,
        color: tools.laserColor,
      );
      _fading.add(p.dx, p.dy, e.timeStamp.inMicroseconds / 1000, view.scale);
      return;
    }
    _trackPressure(e);
    widget.session.beginStroke(
      page: view.index,
      tool: tools.tool == Tool.highlighter ? InkTool.highlighter : InkTool.pen,
      color: tools.strokeColor,
      width: tools.strokeWidth,
      // Yarım ekran pikselinden yakın noktalar atlanır.
      minDistance: 0.5 / view.scale,
      exact: _snap != null,
    );
    _addPoint(e);
  }

  /// Seçim aracı: seçimin üzerinden başlayan hareket taşır; bir öğenin
  /// üzerinden başlayan hareket o öğeyi seçip taşır; boş yerden başlayan
  /// hareket seçim dikdörtgeni çizer (dokunuş seçimi kaldırır).
  void _startSelect(PageViewport view, Offset p) {
    final session = widget.session;
    final pad = _hitSlop / view.scale;
    final corner = _handleAt(view, view.toView(p));
    if (corner != null) {
      _select = _SelectGesture.resize;
      session.beginResize(corner, p.dx, p.dy);
      return;
    }
    if (session.selectionContains(view.index, p.dx, p.dy, pad)) {
      _beginMove(p);
      return;
    }
    final hit = itemAt(session.document.pages[view.index], p.dx, p.dy, pad);
    if (hit != null) {
      session.select(view.index, {hit});
      _beginMove(p);
      return;
    }
    _select = _SelectGesture.marquee;
    session.beginMarquee(view.index, p.dx, p.dy);
  }

  /// Ekrandaki [local] noktasına en yakın tutamak (dokunma payı içinde).
  int? _handleAt(PageViewport view, Offset local) {
    final r = selectionScreenRect(view, widget.session, _hitSlop / 2);
    if (r == null) return null;
    final corners = selectionHandles(
      r,
      edges: widget.session.selectionCanStretch,
    );
    int? best;
    var bestD = _hitSlop * 1.5;
    for (final (i, c) in corners.indexed) {
      final d = (c - local).distance;
      if (d <= bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  void _beginMove(Offset p) {
    _select = _SelectGesture.move;
    _moveFrom = p;
    widget.session.beginMove();
  }

  void _updateSelect(PageViewport view, Offset local) {
    final p = view.toPage(local);
    switch (_select) {
      case _SelectGesture.move:
        final from = _moveFrom!;
        // Başka bir sayfanın üzerine sürüklendiyse oraya taşınır.
        final over = widget.geometry.pageAt(local);
        if (over != null && over.index != view.index) {
          final q = over.toPage(local);
          widget.session.updateMoveToPage(
            over.index,
            q.dx - from.dx,
            q.dy - from.dy,
          );
        } else {
          widget.session.updateMove(p.dx - from.dx, p.dy - from.dy);
        }
      case _SelectGesture.marquee:
        widget.session.updateMarquee(p.dx, p.dy);
      case _SelectGesture.resize:
        widget.session.updateResize(p.dx, p.dy);
      case _SelectGesture.none:
        break;
    }
  }

  void _endSelect() {
    switch (_select) {
      case _SelectGesture.move:
        widget.session.endMove();
      case _SelectGesture.marquee:
        widget.session.endMarquee();
      case _SelectGesture.resize:
        widget.session.endResize();
      case _SelectGesture.none:
        break;
    }
    _select = _SelectGesture.none;
    _moveFrom = null;
  }

  void _addPoint(PointerEvent e) {
    final view = _view;
    if (view == null) return;
    final p = view.toPage(_at(e, view));
    widget.session.addPoint(
      p.dx,
      p.dy,
      pressure: _pressure(e),
      timeMs: e.timeStamp.inMicroseconds / 1000,
      viewScale: view.scale,
    );
  }

  void _onUpdate(PointerEvent e) {
    final view = _view;
    if (view == null || _idleUntilLift) return;
    _followCursor(e);
    if (_select != _SelectGesture.none) {
      _updateSelect(view, e.localPosition);
      return;
    }
    // Kalemin düğmesi temas sürerken basılır / bırakılır: yazan araçta
    // silgiye geçer; düğmeyle başlayan silme düğme bırakılınca durur.
    if (_isStylus(e) && _textDown == null && !_shaping) {
      final button = _stylusErases(e);
      if (button && !_erasing) {
        _switchToButtonEraser(view, e);
        return;
      }
      if (!button && _buttonErasing) {
        widget.session.endErase();
        _erasing = false;
        _buttonErasing = false;
        _idleUntilLift = true;
        return;
      }
    }
    if (_erasing) {
      final p = view.toPage(e.localPosition);
      final last = _lastErasePoint ?? p;
      _cursorAt.value = e.localPosition;
      widget.session.eraseSegment(
        last.dx,
        last.dy,
        p.dx,
        p.dy,
        ref.read(toolProvider).eraserRadius / view.scale,
      );
      _lastErasePoint = p;
      return;
    }
    if (_shaping) {
      final p = view.toPage(e.localPosition);
      widget.session.updateShape(
        p.dx,
        p.dy,
        constrain: HardwareKeyboard.instance.isShiftPressed,
      );
      return;
    }
    if (_laser) {
      final p = view.toPage(_at(e, view));
      _fading.add(p.dx, p.dy, e.timeStamp.inMicroseconds / 1000, view.scale);
      return;
    }
    _trackPressure(e);
    _addPoint(e);
  }

  void _onEnd(PointerEvent e) {
    final view = _view;
    if (view == null) return;
    if (_idleUntilLift) {
      _idleUntilLift = false;
      _view = null;
      _lastErasePoint = null;
      _laser = false;
      if (e.kind != PointerDeviceKind.mouse) _cursorAt.value = null;
      return;
    }
    _buttonErasing = false;
    // Parmak kalkınca imleç kalmaz; fare / kalem ucunu göstermeye devam
    // eder.
    if (e.kind == PointerDeviceKind.touch) _cursorAt.value = null;
    final textDown = _textDown;
    if (textDown != null) {
      _textDown = null;
      _view = null;
      _openTextAt(view, textDown);
      return;
    }
    if (_select != _SelectGesture.none) {
      _endSelect();
    } else if (_erasing) {
      widget.session.endErase();
      if (e.kind != PointerDeviceKind.mouse) _cursorAt.value = null;
    } else if (_shaping) {
      widget.session.endShape();
    } else if (_laser) {
      _fading.end();
    } else {
      widget.session.endStroke();
    }
    _view = null;
    _snap = null;
    _lastErasePoint = null;
    _laser = false;
    _shaping = false;
  }

  void _onCancel() {
    _textDown = null;
    _buttonErasing = false;
    _idleUntilLift = false;
    widget.session.cancelShape();
    _shaping = false;
    if (_select == _SelectGesture.marquee) widget.session.clearSelection();
    widget.session.cancelMove();
    _select = _SelectGesture.none;
    _moveFrom = null;
    widget.session.cancelStroke();
    widget.session.cancelErase();
    _fading.end();
    _cursorAt.value = null;
    _view = null;
    _snap = null;
    _lastErasePoint = null;
    _laser = false;
  }

  void _trackHover(Offset local) {
    final view = widget.geometry.pageAt(local);
    var over = false;
    final handle = view == null ? null : _handleAt(view, local);
    if (handle != _overHandle) setState(() => _overHandle = handle);
    if (view != null && handle == null) {
      final p = view.toPage(local);
      over = widget.session.selectionContains(
        view.index,
        p.dx,
        p.dy,
        _hitSlop / view.scale,
      );
    }
    if (over != _overSelection) setState(() => _overSelection = over);
  }

  @override
  Widget build(BuildContext context) {
    final tool = ref.watch(toolProvider.select((t) => t.tool));
    final eraserRadius = ref.watch(toolProvider.select((t) => t.eraserRadius));
    if (!_ownCursor(tool)) _cursorAt.value = null;
    // Seçim yalnızca seçim aracında yaşar.
    ref.listen(toolProvider.select((t) => t.tool), (_, next) {
      if (next != Tool.select) widget.session.clearSelection();
      // Başka araca geçmek yazıyı tamamlar.
      if (next != Tool.text) _commitText();
    });
    final font = ref.watch(textFontProvider)?.font;
    final colors = context.colors;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        DrawGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DrawGestureRecognizer>(
              () => DrawGestureRecognizer(
                accepts: _accepts,
                isDeferred: (e) => e.kind == PointerDeviceKind.touch,
                debugOwner: this,
              ),
              (r) => r
                ..accepts = _accepts
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd
                ..onCancel = _onCancel,
            ),
      },
      child: MouseRegion(
        cursor: switch (tool) {
          Tool.hand => SystemMouseCursors.grab,
          Tool.text || Tool.textSelect => SystemMouseCursors.text,
          Tool.eraser ||
          Tool.pen ||
          Tool.highlighter ||
          Tool.laser => SystemMouseCursors.none,
          Tool.select => switch (_overHandle) {
            0 || 2 => SystemMouseCursors.resizeUpLeftDownRight,
            1 || 3 => SystemMouseCursors.resizeUpRightDownLeft,
            4 || 6 => SystemMouseCursors.resizeUpDown,
            5 || 7 => SystemMouseCursors.resizeLeftRight,
            _ =>
              _overSelection || _select == _SelectGesture.move
                  ? SystemMouseCursors.move
                  : SystemMouseCursors.basic,
          },
          _ => SystemMouseCursors.precise,
        },
        onHover: (e) {
          if (_ownCursor(tool)) _cursorAt.value = e.localPosition;
          if (tool == Tool.select) _trackHover(e.localPosition);
        },
        onExit: (_) {
          _cursorAt.value = null;
          if (_overSelection || _overHandle != null) {
            setState(() {
              _overSelection = false;
              _overHandle = null;
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: InkLayerPainter(
                    geometry: widget.geometry,
                    session: widget.session,
                    cache: _cache,
                    font: font,
                    recolor: ref.watch(nightModeProvider)
                        ? nightInkColor
                        : null,
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: SelectionPainter(
                  geometry: widget.geometry,
                  session: widget.session,
                  outline: colors.brand,
                  fill: colors.brand.withValues(alpha: 0.08),
                  halo: colors.surfaceRaised,
                  pad: _hitSlop / 2,
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: FadingInkPainter(
                  geometry: widget.geometry,
                  ink: _fading,
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _ToolCursorPainter(
                  at: _cursorAt,
                  geometry: widget.geometry,
                  // Kalemin silgi ucu / yan düğmesi: o sırada silgi halkası.
                  tool: () =>
                      _erasing ? Tool.eraser : ref.read(toolProvider).tool,
                  tools: ref.watch(toolProvider),
                  eraserRadius: eraserRadius,
                ),
              ),
            ),
            _editor(context),
            SelectionBar(
              barKey: _barKey,
              geometry: widget.geometry,
              session: widget.session,
              pad: _hitSlop / 2,
              onCopy: () => copySelection(
                ref,
                widget.session,
                label: AppLocalizations.of(context).clipboardMarker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SelectGesture { none, marquee, move, resize }

/// Sayfa üzerindeki araç imleci (sistem imleci gizliyken):
/// - silgi: kapladığı alanı gösteren halka;
/// - kalem / fosforlu: ucu tam yazacağı noktada duran ikon ve uçta seçili
///   renk ve kalınlıkta nokta (yazmadan önce ne çıkacağı görülür; kalemde
///   nokta ikonun üstünde, geniş fosforluda altında);
/// - geçici kalem: renginde parlayan nokta.
class _ToolCursorPainter extends CustomPainter {
  _ToolCursorPainter({
    required this.at,
    required this.geometry,
    required this.tool,
    required this.tools,
    required this.eraserRadius,
  }) : super(repaint: at);

  final ValueNotifier<Offset?> at;
  final PageGeometry geometry;
  final Tool Function() tool;
  final ToolState tools;
  final double eraserRadius;

  static const _ink = Color(cursorInk);
  static const _halo = Color(cursorHalo);

  /// İkon boyu ve ucunun ikon kutusundaki yeri (Lucide 24'lük ızgarada).
  static const double _iconSize = 22;
  static const _penTip = Offset(2.3 / 24, 21.7 / 24);
  static const _highlighterTip = Offset(3.5 / 24, 19.5 / 24);

  static final Map<IconData, TextPainter> _glyphs = {};
  static final Map<IconData, TextPainter> _halos = {};

  static TextPainter _glyph(IconData icon, {required bool halo}) =>
      (halo ? _halos : _glyphs).putIfAbsent(icon, () {
        final style = TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: _iconSize,
          height: 1,
          color: halo ? null : _ink,
          foreground: halo
              ? (Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..strokeJoin = StrokeJoin.round
                  ..color = _halo)
              : null,
        );
        return TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: style,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      });

  @override
  void paint(Canvas canvas, Size size) {
    final c = at.value;
    if (c == null) return;
    switch (tool()) {
      case Tool.eraser:
        _ring(canvas, c, eraserRadius);
      case Tool.pen:
        _icon(canvas, c, LucideIcons.pen, _penTip);
        _dot(
          canvas,
          c,
          Color(tools.strokeColorFor(Tool.pen)),
          tools.strokeWidthFor(Tool.pen),
        );
      case Tool.highlighter:
        // Fosforlu geniş: önce iz, ikon üstünde.
        _dot(
          canvas,
          c,
          Color(tools.strokeColorFor(Tool.highlighter)),
          tools.strokeWidthFor(Tool.highlighter),
        );
        _icon(canvas, c, LucideIcons.highlighter, _highlighterTip);
      case Tool.laser:
        final color = Color(tools.laserColor);
        canvas.drawCircle(
          c,
          9,
          Paint()
            ..color = color.withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(c, 5, Paint()..color = _halo);
        canvas.drawCircle(c, 3.5, Paint()..color = color);
      default:
        break;
    }
  }

  void _ring(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _halo,
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _ink.withValues(alpha: 0.8),
    );
  }

  /// Uçta mürekkep: ekrandaki gerçek kalınlıkta (en az 3 px), ince hale ile.
  void _dot(Canvas canvas, Offset c, Color color, double widthPt) {
    final scale = geometry.pageAt(c)?.scale ?? 1;
    final r = math.max(1.5, widthPt * scale / 2);
    canvas.drawCircle(c, r + 1, Paint()..color = _halo);
    canvas.drawCircle(c, r, Paint()..color = color);
  }

  void _icon(Canvas canvas, Offset c, IconData icon, Offset tip) {
    final origin = c - Offset(tip.dx * _iconSize, tip.dy * _iconSize);
    _glyph(icon, halo: true).paint(canvas, origin);
    _glyph(icon, halo: false).paint(canvas, origin);
  }

  @override
  bool shouldRepaint(_ToolCursorPainter old) =>
      old.at != at ||
      old.tools != tools ||
      old.eraserRadius != eraserRadius ||
      old.geometry != geometry;
}
