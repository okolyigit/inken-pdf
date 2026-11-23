import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../settings/settings_store.dart';
import 'color_picker.dart';
import 'instruments.dart';
import 'tool_state.dart';

/// Seçenek paneli açık olan araç (yoksa `null`). Aynı anda tek panel açık
/// olur; başka araca geçmek, Esc ya da panelin dışına dokunmak kapatır.
class ToolOptionsNotifier extends Notifier<Tool?> {
  @override
  Tool? build() => null;

  void toggle(Tool tool) => state = state == tool ? null : tool;
  void close() => state = null;
}

final toolOptionsProvider = NotifierProvider<ToolOptionsNotifier, Tool?>(
  ToolOptionsNotifier.new,
);

/// Yüzen araç kutusunun oturduğu kenar. Üst / altta yatay, sol / sağda
/// dikeydir. Akıllı tahtada üst kenara uzanılamayabilir; kutu tutamağından
/// sürüklenip en yakın kenara bırakılır.
enum DockEdge {
  top,
  bottom,
  left,
  right;

  Axis get axis =>
      this == top || this == bottom ? Axis.horizontal : Axis.vertical;
}

/// [point]'e (ekran) en yakın kenar; [area] ekranın boyutu. Kenarlara
/// uzaklık oranla karşılaştırılır: geniş ekranda yatay kenarlar kayırılmaz.
DockEdge nearestEdge(Offset point, Size area) {
  final x = (point.dx / area.width).clamp(0.0, 1.0);
  final y = (point.dy / area.height).clamp(0.0, 1.0);
  final candidates = {
    DockEdge.top: y,
    DockEdge.bottom: 1 - y,
    DockEdge.left: x,
    DockEdge.right: 1 - x,
  };
  return candidates.entries.reduce((a, b) => b.value < a.value ? b : a).key;
}

class ToolDockNotifier extends Notifier<DockEdge> {
  @override
  DockEdge build() {
    final saved = ref.read(settingsStoreProvider).get<String>('toolDock');
    // Eski ayar yönü saklıyordu: yatay üstteydi, dikey solda.
    return switch (saved) {
      'horizontal' => DockEdge.top,
      'vertical' => DockEdge.left,
      _ => DockEdge.values.asNameMap()[saved] ?? DockEdge.top,
    };
  }

  void set(DockEdge edge) {
    state = edge;
    ref.read(settingsStoreProvider).put('toolDock', edge.name);
  }
}

final toolDockProvider = NotifierProvider<ToolDockNotifier, DockEdge>(
  ToolDockNotifier.new,
);

/// Kenarların adı ve ikonu (Görünüm menüsü, Ayarlar, tutamak menüsü).
List<(DockEdge, IconData, String)> dockEdgeChoices(AppLocalizations l10n) => [
  (DockEdge.top, LucideIcons.panelTop, l10n.dockTop),
  (DockEdge.bottom, LucideIcons.panelBottom, l10n.dockBottom),
  (DockEdge.left, LucideIcons.panelLeft, l10n.dockLeft),
  (DockEdge.right, LucideIcons.panelRight, l10n.dockRight),
];

/// Ayarı (seçenek paneli) olan araçlar.
bool hasOptions(Tool tool) =>
    tool != Tool.hand && tool != Tool.select && tool != Tool.textSelect;

/// Aracın seçimi: zaten seçili ve ayarı olan araca ikinci dokunuş paneli
/// açar / kapatır (tasarım ilkesi: "tek dokunuş, tek iş").
void tapTool(WidgetRef ref, Tool tool) {
  final tools = ref.read(toolProvider.notifier);
  final options = ref.read(toolOptionsProvider.notifier);
  if (ref.read(toolProvider).tool == tool && hasOptions(tool)) {
    options.toggle(tool);
  } else {
    tools.select(tool);
    options.close();
  }
}

/// Seçme araçları: araç kutusunda ve telefon rafında tek "Seç" düğmesi;
/// türü (çizimler / PDF metni) düğmenin seçenek panelinden seçilir.
const selectTools = {Tool.select, Tool.textSelect};

/// Birleşik "Seç" düğmesinin gösterdiği tür: en son kullanılan seçme aracı.
final selectKindProvider = NotifierProvider<SelectKindNotifier, Tool>(
  SelectKindNotifier.new,
);

class SelectKindNotifier extends Notifier<Tool> {
  @override
  Tool build() {
    ref.listen(toolProvider.select((s) => s.tool), (_, tool) {
      if (selectTools.contains(tool)) state = tool;
    });
    final tool = ref.read(toolProvider).tool;
    return selectTools.contains(tool) ? tool : Tool.select;
  }
}

/// Birleşik "Seç" düğmesi: seçme aracı seçili değilse son kullanılan tür
/// seçilir; seçiliyse tür paneli açılır / kapanır (panel [Tool.select]'e
/// bağlıdır).
void tapSelect(WidgetRef ref) {
  final options = ref.read(toolOptionsProvider.notifier);
  if (selectTools.contains(ref.read(toolProvider).tool)) {
    options.toggle(Tool.select);
  } else {
    ref.read(toolProvider.notifier).select(ref.read(selectKindProvider));
    options.close();
  }
}

/// Aracın ikonu; şekil aracında seçili şeklin ikonu ([shape]).
IconData toolIcon(Tool tool, [ShapeKind shape = ShapeKind.rectangle]) =>
    switch (tool) {
      Tool.hand => LucideIcons.hand,
      Tool.select => LucideIcons.mousePointer2,
      Tool.pen => LucideIcons.penLine,
      Tool.shape => shapeIcon(shape),
      Tool.text => LucideIcons.type,
      Tool.highlighter => LucideIcons.highlighter,
      Tool.eraser => LucideIcons.eraser,
      Tool.laser => LucideIcons.sparkles,
      Tool.textSelect => LucideIcons.textSelect,
    };

IconData shapeIcon(ShapeKind kind) => switch (kind) {
  ShapeKind.line => LucideIcons.slash,
  ShapeKind.arrow => LucideIcons.moveUpRight,
  ShapeKind.rectangle => LucideIcons.square,
  ShapeKind.ellipse => LucideIcons.circle,
  ShapeKind.coordinate => LucideIcons.chartScatter,
};

String shapeLabel(AppLocalizations l10n, ShapeKind kind) => switch (kind) {
  ShapeKind.line => l10n.shapeLine,
  ShapeKind.arrow => l10n.shapeArrow,
  ShapeKind.rectangle => l10n.shapeRectangle,
  ShapeKind.ellipse => l10n.shapeEllipse,
  ShapeKind.coordinate => l10n.shapeCoordinate,
};

String toolLabel(AppLocalizations l10n, Tool tool) => switch (tool) {
  Tool.hand => l10n.toolHand,
  Tool.select => l10n.toolSelect,
  Tool.shape => l10n.toolShape,
  Tool.text => l10n.toolText,
  Tool.pen => l10n.toolPen,
  Tool.highlighter => l10n.toolHighlighter,
  Tool.eraser => l10n.toolEraser,
  Tool.laser => l10n.toolLaser,
  Tool.textSelect => l10n.toolTextSelect,
};

/// Dar yerler (telefonun alt rafı) için kısa ad; tam ad ipucunda kalır.
String toolShortLabel(AppLocalizations l10n, Tool tool) => switch (tool) {
  Tool.highlighter => l10n.toolHighlighterShort,
  Tool.laser => l10n.toolLaserShort,
  _ => toolLabel(l10n, tool),
};

/// Tek harfli kısayol (ipuçlarında gösterilir).
String? toolShortcut(Tool tool) => switch (tool) {
  Tool.pen => 'P',
  Tool.highlighter => 'H',
  Tool.eraser => 'E',
  Tool.laser => 'L',
  Tool.select => 'V',
  Tool.shape => 'G',
  Tool.text => 'T',
  Tool.hand || Tool.textSelect => null,
};

String toolTooltip(AppLocalizations l10n, Tool tool) {
  final key = toolShortcut(tool);
  final label = toolLabel(l10n, tool);
  return key == null ? label : '$label ($key)';
}

/// Araç göstergesindeki mürekkep rengi (kalem / fosforlu), yoksa `null`.
Color? toolInkColor(ToolState s, Tool tool) => switch (tool) {
  Tool.pen => Color(s.penColor),
  Tool.highlighter => Color(s.highlighterColor),
  Tool.laser => Color(s.laserColor),
  Tool.shape => Color(s.shapeColor),
  Tool.text => Color(s.textColor),
  _ => null,
};

/// [tool]'un seçili rengi (`0xAARRGGBB`); rengi olmayan araçta kalemin.
int toolColor(ToolState s, Tool tool) => switch (tool) {
  Tool.highlighter => s.highlighterColor,
  Tool.laser => s.laserColor,
  Tool.shape => s.shapeColor,
  Tool.text => s.textColor,
  _ => s.penColor,
};

/// [tool]'un sabit paleti.
List<int> toolPalette(Tool tool) => switch (tool) {
  Tool.highlighter => highlighterColors,
  Tool.laser => laserColors,
  _ => penColors,
};

/// Yazan araçların (kalem, fosforlu, geçici kalem) ortak hızlı renk
/// yuvaları (paletteki sıraları): kalemde siyah, mavi, kırmızı; fosforluda
/// sarı, yeşil, pembe; geçici kalemde kiremit, kırmızı, mavi. Sayıları eşit:
/// hangi araç seçilirse seçilsin kutunun genişliği değişmez.
const quickPenColors = [0, 1, 2];
const quickHighlighterColors = [0, 1, 2];
const quickLaserColors = [0, 1, 2];

/// Hızlı renk yuvaları olan araçlar.
const inkTools = [Tool.pen, Tool.highlighter, Tool.laser];

/// Hızlı renk düğmeleri: dokununca araç da seçilir.
class QuickColors extends ConsumerWidget {
  const QuickColors({
    super.key,
    required this.tool,
    this.small = true,
    this.axis = Axis.horizontal,
  });

  final Tool tool;
  final bool small;
  final Axis axis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final indices = switch (tool) {
      Tool.highlighter => quickHighlighterColors,
      Tool.laser => quickLaserColors,
      _ => quickPenColors,
    };
    final names = colorNames(l10n, tool);
    final palette = toolPalette(tool);
    final current = toolColor(s, tool);
    return Flex(
      direction: axis,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in indices)
          ColorSwatchButton(
            key: ValueKey('quick-${tool.name}-$i'),
            color: Color(palette[i]),
            label: '${toolLabel(l10n, tool)}: ${names[i]}',
            selected: s.tool == tool && current == palette[i],
            small: small,
            onTap: () {
              n.select(tool);
              n.setColor(tool, palette[i]);
              ref.read(toolOptionsProvider.notifier).close();
            },
          ),
      ],
    );
  }
}

/// [toolPalette] sırasıyla renk adları.
List<String> colorNames(AppLocalizations l10n, Tool tool) => switch (tool) {
  Tool.highlighter => [
    l10n.colorYellow,
    l10n.colorGreen,
    l10n.colorPink,
    l10n.colorBlue,
  ],
  Tool.laser => [
    l10n.colorBrick,
    l10n.colorRed,
    l10n.colorBlue,
    l10n.colorGreen,
    l10n.colorPurple,
    l10n.colorBlack,
  ],
  _ => [
    l10n.colorBlack,
    l10n.colorBlue,
    l10n.colorRed,
    l10n.colorGreen,
    l10n.colorOrange,
    l10n.colorPurple,
  ],
};

/// Bir aracın seçenekleri. Kalem / fosforlu: Renk → Kalınlık; silgi:
/// Tür → Boyut. Seçim yapmak paneli kapatmaz.
class ToolOptions extends ConsumerWidget {
  const ToolOptions({super.key, required this.tool});

  final Tool tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tool == Tool.eraser) return const _EraserOptions();
    if (tool == Tool.laser) return const _LaserOptions();
    if (tool == Tool.shape) return const _ShapeOptions();
    if (tool == Tool.text) return const _TextOptions();
    if (selectTools.contains(tool)) return const _SelectOptions();
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final isPen = tool == Tool.pen;
    final width = isPen ? s.penWidth : s.highlighterWidth;
    // Kalınlık, sayıyla değil gerçek boyutta noktayla gösterilir.
    final dots = isPen ? const [4.0, 7.0, 11.0, 16.0] : const [8.0, 12.0, 16.0];
    final widthNames = [
      l10n.thicknessThin,
      l10n.thicknessMedium,
      l10n.thicknessThick,
      l10n.thicknessVeryThick,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: l10n.sectionColor,
          child: ColorPalette(tool: tool),
        ),
        _Section(
          label: l10n.sectionThickness,
          divided: true,
          child: Wrap(
            spacing: Space.s2,
            children: [
              for (final (i, d) in dots.indexed)
                ThicknessButton(
                  key: ValueKey('width-$i'),
                  diameter: d,
                  label: widthNames[i],
                  selected: width == i,
                  onTap: () =>
                      isPen ? n.setPenWidth(i) : n.setHighlighterWidth(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Şekil: Şekil → Renk → Kalınlık (kalemin paletleri, ayrı seçim).
/// "Seç" düğmesinin paneli: çizimleri mi, PDF metnini mi seçeceği.
class _SelectOptions extends ConsumerWidget {
  const _SelectOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _Section(
      label: l10n.sectionSelect,
      child: Segmented<Tool>(
        value: ref.watch(selectKindProvider),
        // Tek seçim, iş biter: panel (telefonda alt sayfa) kapanır.
        onChanged: (tool) {
          ref.read(toolProvider.notifier).select(tool);
          ref.read(toolOptionsProvider.notifier).close();
          if (ModalRoute.of(context) is ModalBottomSheetRoute) {
            Navigator.pop(context);
          }
        },
        options: [
          (Tool.select, toolIcon(Tool.select), l10n.selectDrawings),
          (Tool.textSelect, toolIcon(Tool.textSelect), l10n.selectText),
        ],
      ),
    );
  }
}

class _ShapeOptions extends ConsumerWidget {
  const _ShapeOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final widthNames = [
      l10n.thicknessThin,
      l10n.thicknessMedium,
      l10n.thicknessThick,
      l10n.thicknessVeryThick,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: l10n.sectionShape,
          child: Segmented<ShapeKind>(
            value: s.shapeKind,
            onChanged: n.setShapeKind,
            iconOnly: true,
            options: [
              for (final k in ShapeKind.values)
                (k, shapeIcon(k), shapeLabel(l10n, k)),
            ],
          ),
        ),
        _Section(
          label: l10n.sectionColor,
          divided: true,
          child: const ColorPalette(tool: Tool.shape),
        ),
        _Section(
          label: l10n.sectionThickness,
          divided: true,
          child: Wrap(
            spacing: Space.s2,
            children: [
              for (final (i, d) in const [4.0, 7.0, 11.0, 16.0].indexed)
                ThicknessButton(
                  key: ValueKey('shape-width-$i'),
                  diameter: d,
                  label: widthNames[i],
                  selected: s.shapeWidth == i,
                  onTap: () => n.setShapeWidth(i),
                ),
            ],
          ),
        ),
        _Section(
          label: l10n.sectionInstruments,
          divided: true,
          child: const _InstrumentToggles(),
        ),
      ],
    );
  }
}

/// Ölçme araçlarını açıp kapatan düğmeler (birden çoğu birlikte açık
/// olabilir). Cetvel, gönye ya da iletki açılınca kalem seçilir: kenarı
/// boyunca hemen çizilsin.
class _InstrumentToggles extends ConsumerWidget {
  const _InstrumentToggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final open = ref.watch(instrumentsProvider);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceWell,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          for (final kind in InstrumentKind.values)
            Expanded(
              child: _MaybeTooltip(
                message: instrumentLabel(l10n, kind),
                child: Semantics(
                  button: true,
                  toggled: open.containsKey(kind),
                  label: instrumentLabel(l10n, kind),
                  excludeSemantics: true,
                  child: Material(
                    key: ValueKey('instrument-toggle-${kind.name}'),
                    color: open.containsKey(kind)
                        ? c.surfaceRaised
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: open.containsKey(kind)
                          ? BorderSide(color: c.line)
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: c.surfaceHover,
                      onTap: () {
                        final instruments = ref.read(
                          instrumentsProvider.notifier,
                        );
                        final opening = !instruments.isOpen(kind);
                        instruments.toggle(kind);
                        if (opening &&
                            kind != InstrumentKind.compass &&
                            !snapsToInstruments(ref.read(toolProvider).tool)) {
                          ref.read(toolProvider.notifier).select(Tool.pen);
                        }
                      },
                      child: SizedBox(
                        height: 44,
                        child: Icon(
                          instrumentIcon(kind),
                          size: 20,
                          color: open.containsKey(kind) ? c.brand : c.ink,
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
  }
}

/// Metin: Renk → Büyüklük ("A" harfi gerçek oranında).
class _TextOptions extends ConsumerWidget {
  const _TextOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final sizeNames = [l10n.sizeSmall, l10n.sizeMedium, l10n.sizeLarge];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: l10n.sectionColor,
          child: const ColorPalette(tool: Tool.text),
        ),
        _Section(
          label: l10n.sectionSize,
          divided: true,
          child: Wrap(
            spacing: Space.s2,
            children: [
              for (final (i, size) in const [14.0, 20.0, 28.0].indexed)
                Semantics(
                  button: true,
                  inMutuallyExclusiveGroup: true,
                  selected: s.textSize == i,
                  label: sizeNames[i],
                  excludeSemantics: true,
                  child: Material(
                    key: ValueKey('text-size-$i'),
                    color: s.textSize == i ? c.brandTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: InkWell(
                      onTap: () => n.setTextSize(i),
                      borderRadius: BorderRadius.circular(Radii.md),
                      hoverColor: c.surfaceHover,
                      child: SizedBox.square(
                        dimension: Sizes.target,
                        child: Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontFamily: 'DejaVuSans',
                              fontSize: size,
                              height: 1,
                              color: s.textSize == i ? c.brand : c.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          label: l10n.opacity,
          divided: true,
          child: OpacitySlider(
            key: const ValueKey('text-opacity'),
            percent: s.textOpacity,
            onChanged: n.setTextOpacity,
          ),
        ),
      ],
    );
  }
}

/// Opaklık kaydırıcısı: %10–100, 10'ar adım; sağda değer. [onChangeEnd]
/// bırakınca bir kez (geri alma adımı tek olsun diye).
class OpacitySlider extends StatelessWidget {
  const OpacitySlider({
    super.key,
    required this.percent,
    this.onChanged,
    this.onChangeEnd,
  });

  final int percent;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: percent.clamp(10, 100).toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: l10n.percent(percent),
            semanticFormatterCallback: (v) => l10n.percent(v.round()),
            onChanged: onChanged == null ? null : (v) => onChanged!(v.round()),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(v.round()),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            l10n.percent(percent),
            textAlign: TextAlign.end,
            style: InkenText.numeric.copyWith(color: c.ink),
          ),
        ),
      ],
    );
  }
}

/// Geçici kalem: yalnızca renk (kalınlık sabit, iz kısa sürede kaybolur).
class _LaserOptions extends StatelessWidget {
  const _LaserOptions();

  @override
  Widget build(BuildContext context) => _Section(
    label: AppLocalizations.of(context).sectionColor,
    child: const ColorPalette(tool: Tool.laser),
  );
}

/// Bir aracın renkleri: sabit palet, altında son özel renkler ve "Yeni
/// renk" (+) düğmesi. Özel renkler tüm araçlarda ortaktır.
class ColorPalette extends ConsumerWidget {
  const ColorPalette({super.key, required this.tool});

  final Tool tool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final palette = toolPalette(tool);
    final names = colorNames(l10n, tool);
    final current = toolColor(s, tool);
    // Testlerin ve eski panellerin anahtarları: kalem / fosforlu `color-i`,
    // diğerleri `<araç>-color-i`.
    final prefix = tool == Tool.pen || tool == Tool.highlighter
        ? ''
        : '${tool.name}-';

    Future<void> pickNew() async {
      // Panel dışarı dokunuşla kapanır; seçici açılmadan kapatılır, böylece
      // pencere kapanınca panel arkada açık kalmaz.
      final options = ref.read(toolOptionsProvider.notifier);
      if (ref.read(toolOptionsProvider) != null) options.close();
      final picked = await showColorPicker(context, initial: current);
      if (picked == null) return;
      n
        ..addCustomColor(picked)
        ..setColor(tool, picked);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          children: [
            for (final (i, color) in palette.indexed)
              ColorSwatchButton(
                key: ValueKey('${prefix}color-$i'),
                color: Color(color),
                label: names[i],
                selected: current == color,
                onTap: () => n.setColor(tool, color),
              ),
          ],
        ),
        Wrap(
          children: [
            for (final (i, color) in s.customColors.indexed)
              ColorSwatchButton(
                key: ValueKey('custom-color-$i'),
                color: Color(color),
                label: '${l10n.customColor} ${formatHexColor(color)}',
                selected: current == color,
                onTap: () => n.setColor(tool, color),
              ),
            Semantics(
              button: true,
              label: l10n.customColorNew,
              excludeSemantics: true,
              child: InkResponse(
                key: const ValueKey('custom-color-new'),
                onTap: pickNew,
                radius: Sizes.target / 2,
                highlightShape: BoxShape.circle,
                hoverColor: c.surfaceHover,
                child: SizedBox.square(
                  dimension: Sizes.target,
                  child: Center(
                    child: Container(
                      width: Sizes.swatch,
                      height: Sizes.swatch,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.lineStrong),
                      ),
                      child: Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: c.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EraserOptions extends ConsumerWidget {
  const _EraserOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(toolProvider);
    final n = ref.read(toolProvider.notifier);
    final sizeNames = [l10n.sizeSmall, l10n.sizeMedium, l10n.sizeLarge];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          label: l10n.sectionEraserMode,
          child: Segmented<EraserMode>(
            value: s.eraserMode,
            onChanged: n.setEraserMode,
            options: [
              (EraserMode.stroke, LucideIcons.spline, l10n.eraserStroke),
              (EraserMode.pixel, LucideIcons.eraser, l10n.eraserPixel),
            ],
          ),
        ),
        _Section(
          label: l10n.sectionSize,
          divided: true,
          child: Wrap(
            spacing: Space.s2,
            children: [
              for (final (i, d) in const [8.0, 14.0, 22.0].indexed)
                ThicknessButton(
                  key: ValueKey('eraser-size-$i'),
                  diameter: d,
                  label: sizeNames[i],
                  selected: s.eraserSize == i,
                  outlined: true,
                  onTap: () => n.setEraserSize(i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bölümlü seçim (iki–dört seçenek): seçili parça kalkık + `brand` metin.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
    this.iconOnly = false,
    this.dense = false,
  });

  /// Sıkı boy (32 px): pencerelerdeki form satırları için.
  final bool dense;

  /// Yalnızca ikon gösterilir (dar yerde çok seçenek); etiket erişilebilirlik
  /// için kalır.
  final bool iconOnly;

  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, IconData?, String)> options;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceWell,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          for (final (v, icon, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: v == value,
                label: iconOnly ? label : null,
                child: Material(
                  key: ValueKey('seg-$v'),
                  color: v == value ? c.surfaceRaised : Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: v == value
                        ? BorderSide(color: c.line)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: c.surfaceHover,
                    onTap: () => onChanged(v),
                    child: SizedBox(
                      height: dense ? 32 : 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null)
                            Icon(
                              icon,
                              size: iconOnly ? 20 : 18,
                              color: v == value ? c.brand : c.ink,
                            ),
                          if (!iconOnly) ...[
                            if (icon != null) const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: InkenText.menu.copyWith(
                                  color: v == value ? c.brand : c.ink,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    this.divided = false,
  });

  final String label;
  final Widget child;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Space.s1, bottom: Space.s1),
          child: Text(
            label,
            style: InkenText.label.copyWith(color: c.inkMuted),
          ),
        ),
        child,
      ],
    );
    if (!divided) return body;
    return Container(
      margin: const EdgeInsets.only(top: Space.s3),
      padding: const EdgeInsets.only(top: Space.s3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: body,
    );
  }
}

/// Renk yuvarlağı: görünen çap 32, dokunma alanı 48. Seçim yalnızca renkle
/// değil halkayla da gösterilir.
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Dar yerler için (araç çubuğu): 24 daire, 40×48 dokunma alanı.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      // Panel içindeki düğmelerde ipucu yok: panel kapanınca açık kalan
      // ipucu, kaybolan panele bağlı kalıp çöküyordu.
      child: _MaybeTooltip(
        message: small ? label : null,
        child: InkResponse(
          onTap: onTap,
          radius: Sizes.target / 2,
          highlightShape: BoxShape.circle,
          hoverColor: c.surfaceHover,
          child: SizedBox(
            width: small ? 40 : Sizes.target,
            height: Sizes.target,
            child: Center(
              child: Container(
                width: small ? 24 : Sizes.swatch,
                height: small ? 24 : Sizes.swatch,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x73808080)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: small ? c.surfaceWell : c.surfaceRaised,
                            spreadRadius: small ? 2 : 3,
                          ),
                          BoxShadow(color: c.ink, spreadRadius: small ? 4 : 5),
                        ].reversed.toList()
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kalınlık seçeneği: gerçek boyutta nokta.
class ThicknessButton extends StatelessWidget {
  const ThicknessButton({
    super.key,
    required this.diameter,
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  /// Silgi boyutu gibi: dolu nokta yerine halka.
  final bool outlined;

  final double diameter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: _MaybeTooltip(
        message: null,
        child: Material(
          color: selected ? c.brandTint : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            hoverColor: c.surfaceHover,
            child: SizedBox.square(
              dimension: Sizes.target,
              child: Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    color: outlined
                        ? null
                        : selected
                        ? c.brand
                        : c.ink,
                    border: outlined
                        ? Border.all(
                            color: selected ? c.brand : c.ink,
                            width: 2,
                          )
                        : null,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Telefonda aşağı açılan panelin karşılığı: alt sayfa.
Future<void> showToolOptionsSheet(BuildContext context, Tool tool) {
  final l10n = AppLocalizations.of(context);
  final c = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surfaceRaised,
    barrierColor: const Color(0x52000000),
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.s4,
          Space.s2,
          Space.s4,
          Space.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    toolLabel(l10n, tool),
                    style: InkenText.button.copyWith(color: c.ink),
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            ToolOptions(tool: tool),
          ],
        ),
      ),
    ),
  );
}

class _MaybeTooltip extends StatelessWidget {
  const _MaybeTooltip({required this.message, required this.child});

  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return m == null ? child : Tooltip(message: m, child: child);
  }
}
