import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../presentation/stage_cover.dart';
import '../viewer/go_to_page.dart';
import 'ink_session.dart';
import 'tool_options.dart';
import 'tool_state.dart';

/// Tablette menü çubuğunun yerini tutan ince üst çubuk: solda menüleri
/// açan logo, sağda kayıt durumu. Araçların hepsi yüzen araç kutusundadır
/// ([ToolDock]); masaüstünde bu çubuk yoktur (menü çubuğu yeter).
class InkToolbar extends StatelessWidget {
  const InkToolbar({super.key, this.leading, this.middle, this.trailing});

  /// Menüleri açan logo düğmesi.
  final Widget? leading;

  /// Hızlı erişim çubuğu (sığmazsa kendi içinde kayar).
  final Widget? middle;

  /// Kayıt durumu.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: Sizes.appbarM,
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
      child: Row(
        children: [
          ?leading,
          if (middle case final m?)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                child: m,
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Belgenin üzerinde yüzen araç kutusu; sayfada yapılan her şey burada:
/// geri al / yinele, kaydır / seç, kalem, fosforlu, geçici kalem, silgi,
/// şekil, metin, spot ışığı / perde. Tam ekranda da görünür. Üstte / altta tek
/// sıra; solda / sağda iki sütun (kalem grubu ve silgi iç sütunda)
/// ([toolDockProvider]); ekrana sığmazsa kaydırılır.
/// Araç seçenekleri kutudan dışarı açılır: yatayda aşağı, dikeyde sağa.
class ToolDock extends ConsumerStatefulWidget {
  const ToolDock({super.key, required this.session});

  /// Belge yüklenene kadar `null`; o sırada geri al / yinele kapalıdır.
  final InkSession? session;

  @override
  ConsumerState<ToolDock> createState() => _ToolDockState();
}

class _ToolDockState extends ConsumerState<ToolDock> {
  final _portal = OverlayPortalController();
  final _links = {for (final t in Tool.values) t: LayerLink()};
  final _keys = {for (final t in Tool.values) t: GlobalKey()};
  final _dockKey = GlobalKey(debugLabel: 'tool-dock');

  /// Kenardaki kutuda panelin kutunun iç kenarından açılması için yatay
  /// kayma: dış sütundaki düğmenin paneli iç sütunun üstüne binmesin.
  double _panelShiftSide(Tool t, DockEdge edge) {
    final button = _keys[t]!.currentContext?.findRenderObject();
    final dock = _dockKey.currentContext?.findRenderObject();
    if (button is! RenderBox || dock is! RenderBox || !button.attached) {
      return 0;
    }
    final b = button.localToGlobal(Offset.zero, ancestor: dock);
    return edge == DockEdge.left
        ? dock.size.width - (b.dx + button.size.width)
        : -b.dx;
  }

  /// Yatay kutuda panelin ekranın sağından taşmaması için sola kayması
  /// (panel genişliği sabit; çentik düğmeyi göstermeye devam eder).
  double _panelShift(BuildContext overlayContext, Tool t) {
    final button = _keys[t]!.currentContext?.findRenderObject();
    final overlay = Overlay.of(overlayContext).context.findRenderObject();
    if (button is! RenderBox || overlay is! RenderBox || !button.attached) {
      return 0;
    }
    final left =
        button.localToGlobal(Offset.zero, ancestor: overlay).dx - Space.s2;
    final maxLeft = overlay.size.width - Space.s3 - Sizes.drop;
    if (left <= maxLeft) return 0;
    return math.max(maxLeft, Space.s3) - left;
  }

  /// Yan kenardaki kutunun tek sütun hâlinin içerik yüksekliği (son
  /// çizimden ölçülür; iki sütundayken sütunların boyundan hesaplanır).
  /// Bilinmiyorsa `null`: kutu ilk çizimde iki sütunla başlar.
  double? _singleHeight;
  final _contentKey = GlobalKey();
  final _innerKey = GlobalKey();
  final _outerKey = GlobalKey();

  /// Çizimden sonra tek sütun yüksekliğini ölçer; değiştiyse yeniden çizer.
  void _measureColumns(bool single) {
    double? height(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      return box is RenderBox && box.hasSize ? box.size.height : null;
    }

    final content = height(_contentKey);
    if (content == null) return;
    final double measured;
    if (single) {
      measured = content;
    } else {
      final inner = height(_innerKey);
      final outer = height(_outerKey);
      if (inner == null || outer == null) return;
      measured = singleColumnHeight(
        twoColumns: content,
        inner: inner,
        outer: outer,
        gap: Space.s2,
      );
    }
    if (_singleHeight != null && (_singleHeight! - measured).abs() < 0.5) {
      return;
    }
    if (mounted) setState(() => _singleHeight = measured);
  }

  /// Tutamaktan sürüklenen kutunun kayması ve sürükleniyor mu.
  Offset _drag = Offset.zero;
  bool _dragging = false;

  /// Araç düğmeleri ile panel aynı bölge: düğmeye dokunmak "dışarı" sayılmaz.
  final Object _region = Object();

  /// Hızlı renk yuvalarının ait olduğu yazan araç: seçili olan kalem,
  /// fosforlu ya da geçici kalem; başka araçtayken son seçilen.
  Tool _inkTool = Tool.pen;

  @override
  void initState() {
    super.initState();
    // Portal hep açık; panel açık değilken boş çizer (durum sağlayıcıda).
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final tools = ref.watch(toolProvider);
    if (inkTools.contains(tools.tool)) _inkTool = tools.tool;
    final edge = ref.watch(toolDockProvider);
    final axis = edge.axis;
    final vertical = axis == Axis.vertical;

    Widget tool(Tool t) {
      // Ok yok: ilk dokunuş aracı seçer, seçiliyken dokunmak seçenek
      // panelini açar / kapatır.
      final button = ToolButton(
        key: ValueKey('tool-${t.name}'),
        icon: toolIcon(t, tools.shapeKind),
        tooltip: toolTooltip(l10n, t),
        selected: tools.tool == t,
        ink: toolInkColor(tools, t),
        onTap: () => tapTool(ref, t),
      );
      return CompositedTransformTarget(
        key: _keys[t],
        link: _links[t]!,
        child: TapRegion(groupId: _region, child: button),
      );
    }

    // Seç ve Metin seç tek düğme: son kullanılan türün ikonu; seçiliyken
    // dokunmak tür panelini açar.
    Widget selectButton() {
      final kind = ref.watch(selectKindProvider);
      return CompositedTransformTarget(
        key: _keys[Tool.select],
        link: _links[Tool.select]!,
        child: TapRegion(
          groupId: _region,
          child: ToolButton(
            key: const ValueKey('tool-select'),
            icon: toolIcon(kind),
            tooltip: toolTooltip(l10n, kind),
            selected: selectTools.contains(tools.tool),
            onTap: () => tapSelect(ref),
          ),
        ),
      );
    }

    // Spot ışığı ve perde araç değil, açılıp kapanan örtü: tek düğme.
    final covering = ref.watch(stageCoverProvider.select((s) => s.mode));

    const gap = SizedBox.square(dimension: Space.s2);
    final session = widget.session;
    final history = ListenableBuilder(
      listenable: session ?? const AlwaysStoppedAnimation(0),
      // Kenardaki kutuda da yan yana: iki sütunun üstünde tek sıra.
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('undo'),
            tooltip: '${l10n.undo} (Ctrl+Z)',
            icon: const Icon(LucideIcons200.undo2),
            onPressed: session?.canUndo ?? false ? session!.undo : null,
          ),
          IconButton(
            key: const ValueKey('redo'),
            tooltip: '${l10n.redo} (Ctrl+Y)',
            icon: const Icon(LucideIcons200.redo2),
            onPressed: session?.canRedo ?? false ? session!.redo : null,
          ),
        ],
      ),
    );
    final selectFrame = ToolFrame(
      axis: axis,
      children: [tool(Tool.hand), selectButton()],
    );
    // Yazan araçlar tek çerçevede; hızlı renk yuvaları seçili olanın
    // (yuva sayısı eşit, kutu boyu araç değişince oynamaz).
    final inkFrame = ToolFrame(
      axis: axis,
      children: [
        tool(Tool.pen),
        tool(Tool.highlighter),
        tool(Tool.laser),
        QuickColors(
          key: ValueKey('quick-colors-${_inkTool.name}'),
          tool: _inkTool,
          axis: axis,
        ),
      ],
    );
    final eraserFrame = ToolFrame(axis: axis, children: [tool(Tool.eraser)]);
    final shapeFrame = ToolFrame(axis: axis, children: [tool(Tool.shape)]);
    final textFrame = ToolFrame(axis: axis, children: [tool(Tool.text)]);
    final coverFrame = ToolFrame(
      axis: axis,
      children: [_CoverButton(active: covering)],
    );
    final grip = _DockGrip(
      vertical: vertical,
      onDragStart: () {
        ref.read(toolOptionsProvider.notifier).close();
        setState(() => _dragging = true);
      },
      onDrag: (delta) => setState(() => _drag += delta),
      onDrop: (global) {
        final size = MediaQuery.sizeOf(context);
        setState(() {
          _drag = Offset.zero;
          _dragging = false;
        });
        ref.read(toolDockProvider.notifier).set(nearestEdge(global, size));
      },
      onPick: (e) {
        ref.read(toolOptionsProvider.notifier).close();
        ref.read(toolDockProvider.notifier).set(e);
      },
    );

    Widget column(List<Widget> items) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, w) in items.indexed) ...[if (i > 0) gap, w],
      ],
    );

    // Yatayda tek sıra. Kenarda sığıyorsa tek sütun (yataydaki sırayla);
    // sığmıyorsa iki sütun: kalem grubu ve silgi sayfaya bakan iç sütunda,
    // geri kalanı ekran kenarındaki dış sütunda.
    final order = [
      history,
      selectFrame,
      inkFrame,
      eraserFrame,
      shapeFrame,
      textFrame,
      coverFrame,
      grip,
    ];
    Widget contentFor(bool single) {
      if (!vertical) {
        return Row(
          key: _contentKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, w) in order.indexed) ...[if (i > 0) gap, w],
          ],
        );
      }
      if (single) {
        return Column(
          key: _contentKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, w) in order.indexed) ...[if (i > 0) gap, w],
          ],
        );
      }
      const columnGap = SizedBox(width: Space.s1);
      final outer = KeyedSubtree(
        key: _outerKey,
        child: column([selectFrame, shapeFrame, textFrame, coverFrame]),
      );
      final inner = KeyedSubtree(
        key: _innerKey,
        child: column([inkFrame, eraserFrame]),
      );
      // Üstte geri al / yinele, altında aynı hizadan başlayan iki sütun,
      // en altta tutamak.
      return Column(
        key: _contentKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          history,
          gap,
          Row(
            key: const ValueKey('tool-dock-columns'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            // Sütunlar arası dar: çerçevelerin kenar çizgisi zaten ayırır.
            children: edge == DockEdge.right
                ? [inner, columnGap, outer]
                : [outer, columnGap, inner],
          ),
          gap,
          grip,
        ],
      );
    }

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final t = ref.watch(toolOptionsProvider);
        if (t == null) return const SizedBox.shrink();
        MediaQuery.sizeOf(context); // pencere değişince yeniden hesapla
        final shift = vertical
            ? _panelShiftSide(t, edge)
            : _panelShift(context, t);
        // Panel ekranın içine doğru açılır: üstteki kutuda aşağı, alttakinde
        // yukarı, soldakinde sağa, sağdakinde sola.
        final (target, follower, offset) = switch (edge) {
          DockEdge.top => (
            Alignment.bottomLeft,
            Alignment.topLeft,
            Offset(-Space.s2 + shift, Space.s3),
          ),
          DockEdge.bottom => (
            Alignment.topLeft,
            Alignment.bottomLeft,
            Offset(-Space.s2 + shift, -Space.s3),
          ),
          DockEdge.left => (
            Alignment.topRight,
            Alignment.topLeft,
            Offset(Space.s3 + shift, -Space.s2),
          ),
          DockEdge.right => (
            Alignment.topLeft,
            Alignment.topRight,
            Offset(-Space.s3 + shift, -Space.s2),
          ),
        };
        return CompositedTransformFollower(
          link: _links[t]!,
          targetAnchor: target,
          followerAnchor: follower,
          offset: offset,
          child: Align(
            alignment: follower,
            child: TapRegion(
              groupId: _region,
              onTapOutside: (_) =>
                  ref.read(toolOptionsProvider.notifier).close(),
              child: _DropPanel(
                key: ValueKey('options-${t.name}'),
                label: l10n.toolOptions(toolLabel(l10n, t)),
                edge: edge,
                notchShift: vertical ? 0 : -shift,
                child: ToolOptions(tool: t),
              ),
            ),
          ),
        );
      },
      // Sürüklenirken kutu imleci izler; bırakınca en yakın kenara oturur.
      child: Transform.translate(
        offset: _drag,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final single =
                vertical &&
                dockFitsSingleColumn(
                  singleHeight: _singleHeight,
                  maxHeight: constraints.maxHeight,
                  padding: _dockPadding,
                );
            if (vertical) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _measureColumns(single),
              );
            }
            return _dockBox(c, axis, contentFor(single));
          },
        ),
      ),
    );
  }

  static const _dockPadding = Space.s1 + 2;

  Widget _dockBox(InkenColors c, Axis axis, Widget content) => AnimatedOpacity(
    key: const ValueKey('tool-dock'),
    opacity: _dragging ? 0.85 : 1,
    duration: Motion.fast,
    child: Container(
      key: _dockKey,
      padding: const EdgeInsets.all(_dockPadding),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: c.shadowDock,
      ),
      // Düğmeler GlobalKey'li: yön değişince durumları ve panelin bağlı
      // olduğu hedefler korunur. Ekrana sığmazsa kutu kaydırılır.
      child: SingleChildScrollView(scrollDirection: axis, child: content),
    ),
  );
}

/// Yüzen araç kutusunu [edge] kenarına yerleştirir (bir `Stack` içinde).
/// [top] / [bottom] / [left] / [right] o kenarlarda başka yüzen öğeler
/// için bırakılan boşluktur (tam ekran düğmesi, sayfa gezgini, sayfa
/// paneli sekmesi, kaydırma çubuğu); kutu kalan alanın ortasında durur.
Widget dockPositioned(
  DockEdge edge,
  Widget dock, {
  double top = Space.s3,
  double bottom = Space.s3,
  double left = Space.s3,
  double right = Space.s3,
}) => switch (edge) {
  DockEdge.top => Positioned(
    top: Space.s3,
    left: Space.s3,
    right: Space.s3,
    child: Center(child: dock),
  ),
  DockEdge.bottom => Positioned(
    bottom: bottom,
    left: Space.s3,
    right: Space.s3,
    child: Center(child: dock),
  ),
  DockEdge.left => Positioned(
    left: left,
    top: top,
    bottom: bottom,
    child: Center(child: dock),
  ),
  DockEdge.right => Positioned(
    right: right,
    top: top,
    bottom: bottom,
    child: Center(child: dock),
  ),
};

/// Bir aracı (ve hızlı renklerini) saran belirgin çerçeve: hangi rengin
/// hangi araca ait olduğu bir bakışta okunur.
class ToolFrame extends StatelessWidget {
  const ToolFrame({
    super.key,
    required this.children,
    this.axis = Axis.horizontal,
  });

  final List<Widget> children;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceWell,
        borderRadius: BorderRadius.circular(Radii.md + 2),
        border: Border.all(color: c.lineStrong.withValues(alpha: 0.45)),
      ),
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Radyo grubu üyesi araç düğmesi: seçiliyken `brand` blok + `on-brand`
/// ikon, hafifçe kalkık.
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.ink,
    this.size = Sizes.target,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.md)),
    this.toggle = false,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  /// İkonun altındaki kısa mürekkep çizgisinin rengi (kalem / fosforlu).
  final Color? ink;
  final double size;
  final BorderRadius borderRadius;

  /// Radyo grubu üyesi değil, tek başına açılıp kapanan düğme (örtüler).
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onBrand : c.ink;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: !toggle,
      selected: toggle ? null : selected,
      toggled: toggle ? selected : null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? c.brand : Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            hoverColor: selected ? c.brandHover : c.surfaceHover,
            focusColor: Colors.transparent,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: ink == null ? 0 : 6),
                    child: Icon(
                      selected ? selectedIcon(icon) : icon,
                      color: fg,
                    ),
                  ),
                  if (ink != null)
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 18,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(Radii.pill),
                          boxShadow: [
                            BoxShadow(
                              color: selected ? c.brand : c.surfaceWell,
                              spreadRadius: 1.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Araç paneli: 288 genişlik, çentik düğmeyi gösterir. Kutudan dışarı
/// 8px kayarak ve soluklaşarak açılır.
class _DropPanel extends StatelessWidget {
  const _DropPanel({
    super.key,
    required this.label,
    required this.child,
    this.edge = DockEdge.top,
    this.notchShift = 0,
  });

  /// Kutunun kenarı: çentik kutuya bakan kenarda (üstteki kutuda panelin
  /// üstünde, sağdakinde panelin sağında…).
  final DockEdge edge;

  /// Panel ekrana sığmak için kaydırıldıysa çentiğin ters yöndeki kayması
  /// (düğmeyi göstermeye devam etsin).
  final double notchShift;

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final panel = Semantics(
      container: true,
      label: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: Sizes.drop,
            padding: const EdgeInsets.all(Space.s3),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: c.shadowPop,
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
          Positioned(
            top: switch (edge) {
              DockEdge.top => -6,
              DockEdge.bottom => null,
              _ => 26,
            },
            bottom: edge == DockEdge.bottom ? -6 : null,
            left: switch (edge) {
              DockEdge.left => -6,
              DockEdge.right => null,
              _ => (30 + notchShift).clamp(
                Radii.lg,
                Sizes.drop - Radii.lg - 12,
              ),
            },
            right: edge == DockEdge.right ? -6 : null,
            child: Transform.rotate(
              // Kare 45° döner; görünen iki kenarı çerçeveli köşe kutuya bakar.
              angle: 0.785398,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  border: switch (edge) {
                    DockEdge.top => Border(
                      top: BorderSide(color: c.line),
                      left: BorderSide(color: c.line),
                    ),
                    DockEdge.bottom => Border(
                      bottom: BorderSide(color: c.line),
                      right: BorderSide(color: c.line),
                    ),
                    DockEdge.left => Border(
                      left: BorderSide(color: c.line),
                      bottom: BorderSide(color: c.line),
                    ),
                    DockEdge.right => Border(
                      top: BorderSide(color: c.line),
                      right: BorderSide(color: c.line),
                    ),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!animate) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.normal,
      curve: Motion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          // Kutudan dışarı doğru kayarak açılır.
          offset: switch (edge) {
            DockEdge.top => Offset(0, -8 * (1 - t)),
            DockEdge.bottom => Offset(0, 8 * (1 - t)),
            DockEdge.left => Offset(-8 * (1 - t), 0),
            DockEdge.right => Offset(8 * (1 - t), 0),
          },
          child: child,
        ),
      ),
      child: panel,
    );
  }
}

/// Sayfa gezgini: önceki · "3 / 12" · sonraki. Rakamlar sabit genişlikli;
/// sayfa değişince bar kaymaz.
class PageNav extends StatefulWidget {
  const PageNav({super.key, required this.viewer, this.compact = false});

  final InkenViewerController viewer;

  /// Dar ekranda oklar gizlenir, yalnızca sayı kalır.
  final bool compact;

  @override
  State<PageNav> createState() => _PageNavState();
}

/// Sayıya dokununca yerinde sayfa numarası yazılır; Enter gider, Esc ya
/// da dışarı dokunmak vazgeçer.
class _PageNavState extends State<PageNav> {
  /// "999 / 999" sığar; daha uzunu küçültülür, genişlik hiç değişmez.
  static const double _numberWidth = 104;

  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    final page = widget.viewer.currentPage;
    if (page == null) return;
    final value = '${page + 1}';
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection(baseOffset: 0, extentOffset: value.length),
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _submit() {
    final page = parsePageInput(_text.text, widget.viewer.pageCount);
    setState(() => _editing = false);
    if (page != null) widget.viewer.goToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final viewer = widget.viewer;
    final compact = widget.compact;
    return ListenableBuilder(
      listenable: viewer,
      builder: (context, _) {
        final count = viewer.pageCount;
        final page = viewer.currentPage;
        final pill = WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
        );
        final style = InkenText.numeric.copyWith(color: c.ink);
        final total = Text(
          ' / $count',
          style: InkenText.numeric.copyWith(color: c.inkMuted),
        );
        // Görüntü ve düzenleme aynı iskelette: sağa yaslı sabit yuva +
        // " / toplam". Düzenlemeye geçince hiçbir şey kaymaz.
        final Widget current = _editing
            ? CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      setState(() => _editing = false),
                },
                child: TextField(
                  key: const ValueKey('page-input'),
                  controller: _text,
                  focusNode: _focus,
                  style: style,
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration.collapsed(hintText: null),
                  onSubmitted: (_) => _submit(),
                  onTapOutside: (_) => setState(() => _editing = false),
                ),
              )
            : Text(
                page == null ? '–' : '${page + 1}',
                key: const ValueKey('page-number'),
                style: style,
                textAlign: TextAlign.end,
              );
        final Widget number = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 40, child: current),
            total,
          ],
        );
        // Belgenin altında süzülen sade kapsül. Sayı alanı sabit
        // genişlikte; oklar sayfa sayısına göre yer değiştirmez.
        return _FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact)
                IconButton(
                  key: const ValueKey('page-prev'),
                  tooltip: l10n.previousPage,
                  style: ButtonStyle(shape: pill),
                  icon: const Icon(LucideIcons200.chevronLeft),
                  onPressed: page != null && page > 0
                      ? () => viewer.goToPage(page - 1)
                      : null,
                ),
              Tooltip(
                message: l10n.goToPageTitle,
                child: InkWell(
                  key: const ValueKey('page-number-button'),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  hoverColor: c.surfaceHover,
                  onTap: _editing || page == null ? null : _startEditing,
                  child: SizedBox(
                    width: _numberWidth,
                    height: Sizes.target,
                    child: Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: number),
                    ),
                  ),
                ),
              ),
              if (!compact)
                IconButton(
                  key: const ValueKey('page-next'),
                  tooltip: l10n.nextPage,
                  style: ButtonStyle(shape: pill),
                  icon: const Icon(LucideIcons200.chevronRight),
                  onPressed: page != null && page < count - 1
                      ? () => viewer.goToPage(page + 1)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Belgenin üzerinde süzülen kapsül (sayfa gezgini, yakınlaştırma).
class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: c.surfaceRaised.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: c.shadowPop,
      ),
      child: child,
    );
  }
}

/// Sağ altta yakınlaştırma: − · kaydırma çubuğu · + · yüzde. Dar ekranda
/// kaydırma çubuğu gizlenir. Çubuk logaritmiktir (her konumda aynı his).
class ZoomControl extends StatelessWidget {
  const ZoomControl({super.key, required this.viewer, this.slider = true});

  final InkenViewerController viewer;
  final bool slider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final pill = ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
      ),
    );
    return ListenableBuilder(
      listenable: viewer,
      builder: (context, _) {
        final min = viewer.minZoom, max = viewer.maxZoom;
        final zoom = viewer.zoom.clamp(min, max);
        final usable = max > min;
        double toT(double z) =>
            usable ? math.log(z / min) / math.log(max / min) : 0;
        double fromT(double t) => min * math.pow(max / min, t);
        return _FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('zoom-out'),
                tooltip: '${l10n.zoomOut} (Ctrl+−)',
                style: pill,
                icon: const Icon(LucideIcons200.minus),
                onPressed: usable && zoom > min ? viewer.zoomOut : null,
              ),
              if (slider)
                SizedBox(
                  width: 140,
                  child: Slider(
                    key: const ValueKey('zoom-slider'),
                    value: toT(zoom).clamp(0.0, 1.0),
                    onChanged: usable ? (t) => viewer.setZoom(fromT(t)) : null,
                    semanticFormatterCallback: (_) =>
                        '${(zoom * 100).round()}%',
                  ),
                ),
              IconButton(
                key: const ValueKey('zoom-in'),
                tooltip: '${l10n.zoomIn} (Ctrl+=)',
                style: pill,
                icon: const Icon(LucideIcons200.plus),
                onPressed: usable && zoom < max ? viewer.zoomIn : null,
              ),
              // Yüzdeye dokunmak sığdırma seçeneklerini açar.
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('zoom-fit-page'),
                    leadingIcon: const Icon(LucideIcons200.scan),
                    onPressed: viewer.fitPage,
                    child: Text('${l10n.fitPage} (Ctrl+0)'),
                  ),
                  MenuItemButton(
                    key: const ValueKey('zoom-fit-width'),
                    leadingIcon: const Icon(LucideIcons200.moveHorizontal),
                    onPressed: viewer.fitWidth,
                    child: Text('${l10n.fitWidth} (Ctrl+2)'),
                  ),
                  MenuItemButton(
                    key: const ValueKey('zoom-actual-size'),
                    leadingIcon: const Icon(LucideIcons200.ratio),
                    onPressed: () => viewer.setZoom(1),
                    child: Text('${l10n.actualSize} (Ctrl+1)'),
                  ),
                ],
                builder: (context, menu, _) => Tooltip(
                  message: l10n.zoomOptions,
                  child: InkWell(
                    key: const ValueKey('zoom-menu'),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    onTap: () => menu.isOpen ? menu.close() : menu.open(),
                    child: SizedBox(
                      width: 56,
                      height: Sizes.target,
                      child: Center(
                        child: Text(
                          '${(zoom * 100).round()}%',
                          key: const ValueKey('zoom-value'),
                          textAlign: TextAlign.center,
                          style: InkenText.numeric.copyWith(
                            color: c.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Araç kutusunun tutamağı: sürükleyince kutu imleci izler, bırakınca en
/// yakın kenara oturur; dokununca kenar seçme menüsü açılır (sürüklemeyi
/// bilmeyen ya da klavye kullanan için).
class _DockGrip extends StatelessWidget {
  const _DockGrip({
    required this.vertical,
    required this.onDragStart,
    required this.onDrag,
    required this.onDrop,
    required this.onPick,
  });

  final bool vertical;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDrag;

  /// Bırakılan yer (ekran koordinatı).
  final ValueChanged<Offset> onDrop;
  final ValueChanged<DockEdge> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return MenuAnchor(
      menuChildren: [
        for (final (edge, icon, label) in dockEdgeChoices(l10n))
          MenuItemButton(
            key: ValueKey('dock-${edge.name}'),
            leadingIcon: Icon(icon),
            onPressed: () => onPick(edge),
            child: Text(label),
          ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: l10n.dockMove,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: GestureDetector(
            key: const ValueKey('dock-move'),
            behavior: HitTestBehavior.opaque,
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            onPanStart: (_) {
              menu.close();
              onDragStart();
            },
            onPanUpdate: (d) => onDrag(d.delta),
            onPanEnd: (d) => onDrop(d.globalPosition),
            child: Semantics(
              button: true,
              label: l10n.dockMove,
              child: SizedBox.square(
                dimension: Sizes.target,
                child: Icon(
                  vertical
                      ? LucideIcons200.gripHorizontal
                      : LucideIcons200.gripVertical,
                  size: 20,
                  color: c.inkMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Spot ışığı / perde düğmesi. Örtü kapalıyken dokunmak seçim menüsünü
/// açar; açıkken düğme o örtünün ikonuyla vurgulanır ve dokunmak kapatır.
class _CoverButton extends ConsumerWidget {
  const _CoverButton({required this.active});

  final StageCover active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = active != StageCover.none;
    void choose(StageCover mode) {
      ref.read(toolOptionsProvider.notifier).close();
      ref.read(stageCoverProvider.notifier).toggle(mode);
    }

    return MenuAnchor(
      menuChildren: [
        for (final mode in const [StageCover.spotlight, StageCover.curtain])
          MenuItemButton(
            key: ValueKey('cover-${mode.name}'),
            leadingIcon: Icon(stageCoverIcon(mode)),
            shortcut: SingleActivator(
              mode == StageCover.spotlight
                  ? LogicalKeyboardKey.keyS
                  : LogicalKeyboardKey.keyC,
            ),
            onPressed: () => choose(mode),
            child: Text(stageCoverLabel(l10n, mode)),
          ),
      ],
      builder: (context, menu, _) => ToolButton(
        key: const ValueKey('cover-button'),
        icon: stageCoverIcon(on ? active : StageCover.spotlight),
        tooltip: on
            ? (active == StageCover.spotlight
                  ? l10n.spotlightClose
                  : l10n.curtainClose)
            : '${l10n.stageCover} (S · C)',
        selected: on,
        toggle: true,
        onTap: () {
          ref.read(toolOptionsProvider.notifier).close();
          if (on) {
            ref.read(stageCoverProvider.notifier).close();
          } else if (menu.isOpen) {
            menu.close();
          } else {
            menu.open();
          }
        },
      ),
    );
  }
}

/// İki sütunlu kutunun ölçülerinden tek sütun yüksekliği: sütunlar yan
/// yana değil alt alta ([gap] arayla) dizilince içerik bu kadar uzar.
double singleColumnHeight({
  required double twoColumns,
  required double inner,
  required double outer,
  required double gap,
}) => twoColumns - math.max(inner, outer) + inner + gap + outer;

/// Yan kenardaki kutu tek sütun sığar mı? [maxHeight] kutuya ayrılan
/// yükseklik, [padding] kutunun iç boşluğu. Yükseklik henüz ölçülmediyse
/// hayır (iki sütun her ekrana sığar).
bool dockFitsSingleColumn({
  required double? singleHeight,
  required double maxHeight,
  required double padding,
}) => singleHeight != null && singleHeight + 2 * padding <= maxHeight;
