import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:inken_core/inken_core.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'ink_painter.dart';
import 'tool_options.dart';

/// Görsel düzenleyiciyi açar: kırp, döndür, boyutlandır, opaklık. Masaüstü
/// ve tablette diyalog, telefonda tam ekran. Uygulanırsa yeni öğe, yoksa
/// `null` döner. Düzenleme yıkıcı değildir: orijinal görsel baytları
/// değişmez ([applyImageEdit]).
Future<ImageItem?> showImageEditor(
  BuildContext context, {
  required ImageItem item,
  required ui.Image image,
}) {
  final phone = InkenLayout.of(context) == InkenLayout.phone;
  return showDialog<ImageItem>(
    context: context,
    builder: (context) {
      final editor = ImageEditor(item: item, image: image, phone: phone);
      if (phone) return Dialog.fullscreen(child: editor);
      return Dialog(
        insetPadding: const EdgeInsets.all(Space.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 904, maxHeight: 640),
          child: editor,
        ),
      );
    },
  );
}

/// Kırpma oranı seçenekleri.
enum CropPreset { free, original, square, fourThree, sixteenNine }

/// Kırpma çerçevesinin tutulan yeri.
enum _Grip {
  move,
  left,
  top,
  right,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

const double _ptPerCm = 72 / 2.54;

class ImageEditor extends StatefulWidget {
  const ImageEditor({
    super.key,
    required this.item,
    required this.image,
    this.phone = false,
  });

  final ImageItem item;
  final ui.Image image;
  final bool phone;

  @override
  State<ImageEditor> createState() => ImageEditorState();
}

@visibleForTesting
class ImageEditorState extends State<ImageEditor> {
  /// Saat yönünde çeyrek tur.
  late int _turns = normalizeTurns(widget.item.rotation);

  /// Kırpma, görünen (döndürülmüş) görselin oranlarıyla.
  late CropRect _crop = cropToView(clampCrop(cropOf(widget.item)), _turns);

  /// Görünen pikselin sayfadaki boyutu (pt), yatay ve dikey.
  late double _sx, _sy;

  late double _opacity = widget.item.opacity;
  bool _locked = true;
  CropPreset _preset = CropPreset.free;

  final _width = TextEditingController();
  final _height = TextEditingController();

  _Grip? _grip;
  CropRect? _dragStart;
  Offset _dragTotal = Offset.zero;

  @override
  void initState() {
    super.initState();
    final (w, h) = _cropPixels;
    _sx = widget.item.width / w;
    _sy = widget.item.height / h;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFields();
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  // ---- durum

  /// Görünen (döndürülmüş) görselin piksel boyutu.
  (double, double) get _viewPixels {
    final w = widget.image.width.toDouble();
    final h = widget.image.height.toDouble();
    return _turns.isOdd ? (h, w) : (w, h);
  }

  (double, double) get _cropPixels {
    final (w, h) = _viewPixels;
    return ((_crop.right - _crop.left) * w, (_crop.bottom - _crop.top) * h);
  }

  /// Sayfadaki boyut (pt).
  double get widthPt => _sx * _cropPixels.$1;
  double get heightPt => _sy * _cropPixels.$2;

  int get turns => _turns;
  CropRect get crop => _crop;
  bool get locked => _locked;
  int get opacityPercent => (_opacity * 100).round();

  /// Seçili orana göre kırpmanın görünen piksel oranı (en / boy).
  double? get _ratio {
    final (w, h) = _viewPixels;
    return switch (_preset) {
      CropPreset.free => null,
      CropPreset.original => w / h,
      CropPreset.square => 1,
      CropPreset.fourThree => 4 / 3,
      CropPreset.sixteenNine => 16 / 9,
    };
  }

  /// Uygulanacak öğe.
  ImageItem get result => applyImageEdit(
    widget.item,
    crop: cropToSource(_crop, _turns),
    turns: _turns,
    width: widthPt,
    height: heightPt,
    opacity: _opacity,
  );

  String _cm(double pt) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return NumberFormat('0.0', locale).format(pt / _ptPerCm);
  }

  void _syncFields() {
    _width.text = _cm(widthPt);
    _height.text = _cm(heightPt);
  }

  void _update(VoidCallback change) {
    setState(change);
    _syncFields();
  }

  void rotate(int dir) => _update(() {
    _crop = dir > 0 ? cropToView(_crop, 1) : cropToSource(_crop, 1);
    _turns = normalizeTurns(_turns + dir);
    final sx = _sx;
    _sx = _sy;
    _sy = sx;
    // Dikdörtgen oranlar dönünce ters çevrilir: serbeste geçilir.
    if (_preset == CropPreset.fourThree || _preset == CropPreset.sixteenNine) {
      _preset = CropPreset.free;
    }
  });

  void choosePreset(CropPreset preset) => _update(() {
    _preset = preset;
    final r = _ratio;
    if (preset == CropPreset.original) {
      _crop = fullCrop;
    } else if (r != null) {
      // Orana uyan en büyük çerçeve, görselin ortasında.
      final (vw, vh) = _viewPixels;
      final (w, h) = vw / vh > r ? (vh * r, vh) : (vw, vw / r);
      final nw = w / vw, nh = h / vh;
      _crop = (
        left: (1 - nw) / 2,
        top: (1 - nh) / 2,
        right: (1 + nw) / 2,
        bottom: (1 + nh) / 2,
      );
    }
  });

  void toggleLock() => setState(() => _locked = !_locked);

  void setOpacityPercent(int percent) =>
      setState(() => _opacity = percent / 100);

  void reset() => _update(() {
    final s = math.sqrt(_sx * _sy);
    _turns = 0;
    _crop = fullCrop;
    _sx = s;
    _sy = s;
    _opacity = 1;
    _preset = CropPreset.free;
    _locked = true;
  });

  /// Alana yazılan boyut (cm). Kilitliyken diğer boyut da aynı oranda.
  void _typed(String text, {required bool width}) {
    final cm = double.tryParse(text.trim().replaceAll(',', '.'));
    if (cm == null || cm <= 0) return;
    final pt = cm * _ptPerCm;
    final factor = pt / (width ? widthPt : heightPt);
    if (!factor.isFinite || factor <= 0) return;
    setState(() {
      if (width || _locked) _sx *= factor;
      if (!width || _locked) _sy *= factor;
    });
    if (_locked) {
      (width ? _height : _width).text = _cm(width ? heightPt : widthPt);
    }
  }

  // ---- kırpma çerçevesini sürükleme

  /// Önizlemede görselin kapladığı dikdörtgen.
  Rect imageRectIn(Size box) {
    const margin = Space.s4;
    final (vw, vh) = _viewPixels;
    final avail = Size(
      math.max(1, box.width - 2 * margin),
      math.max(1, box.height - 2 * margin),
    );
    final scale = math.min(avail.width / vw, avail.height / vh);
    return Rect.fromCenter(
      center: box.center(Offset.zero),
      width: vw * scale,
      height: vh * scale,
    );
  }

  Rect _cropRectIn(Rect img) => Rect.fromLTRB(
    img.left + _crop.left * img.width,
    img.top + _crop.top * img.height,
    img.left + _crop.right * img.width,
    img.top + _crop.bottom * img.height,
  );

  _Grip? _gripAt(Offset p, Rect img) {
    const reach = 24.0;
    final r = _cropRectIn(img);
    bool near(double a, double b) => (a - b).abs() <= reach;
    final inY = p.dy > r.top - reach && p.dy < r.bottom + reach;
    final inX = p.dx > r.left - reach && p.dx < r.right + reach;
    final l = near(p.dx, r.left) && inY, rt = near(p.dx, r.right) && inY;
    final t = near(p.dy, r.top) && inX, b = near(p.dy, r.bottom) && inX;
    if (t && l) return _Grip.topLeft;
    if (t && rt) return _Grip.topRight;
    if (b && l) return _Grip.bottomLeft;
    if (b && rt) return _Grip.bottomRight;
    if (l) return _Grip.left;
    if (rt) return _Grip.right;
    if (t) return _Grip.top;
    if (b) return _Grip.bottom;
    if (r.contains(p)) return _Grip.move;
    return null;
  }

  void dragStart(Offset p, Size box) {
    _grip = _gripAt(p, imageRectIn(box));
    _dragStart = _crop;
    _dragTotal = Offset.zero;
  }

  void dragUpdate(Offset delta, Size box) {
    final grip = _grip, start = _dragStart;
    if (grip == null || start == null) return;
    _dragTotal += delta;
    final img = imageRectIn(box);
    final du = _dragTotal.dx / img.width, dv = _dragTotal.dy / img.height;
    final next = _dragged(start, grip, du, dv);
    if (next != null) _update(() => _crop = next);
  }

  void dragEnd() {
    _grip = null;
    _dragStart = null;
  }

  /// Sürüklenmiş kırpma; orana uyamıyor ya da taşıyorsa en yakın geçerli
  /// hâli, hiç yoksa `null`.
  CropRect? _dragged(CropRect s, _Grip grip, double du, double dv) {
    if (grip == _Grip.move) {
      final w = s.right - s.left, h = s.bottom - s.top;
      final l = (s.left + du).clamp(0.0, 1 - w);
      final t = (s.top + dv).clamp(0.0, 1 - h);
      return (left: l, top: t, right: l + w, bottom: t + h);
    }
    var l = s.left, t = s.top, r = s.right, b = s.bottom;
    final moveL =
        grip == _Grip.left || grip == _Grip.topLeft || grip == _Grip.bottomLeft;
    final moveR =
        grip == _Grip.right ||
        grip == _Grip.topRight ||
        grip == _Grip.bottomRight;
    final moveT =
        grip == _Grip.top || grip == _Grip.topLeft || grip == _Grip.topRight;
    final moveB =
        grip == _Grip.bottom ||
        grip == _Grip.bottomLeft ||
        grip == _Grip.bottomRight;
    if (moveL) l = (l + du).clamp(0.0, r - minCropSize);
    if (moveR) r = (r + du).clamp(l + minCropSize, 1.0);
    if (moveT) t = (t + dv).clamp(0.0, b - minCropSize);
    if (moveB) b = (b + dv).clamp(t + minCropSize, 1.0);
    final ratio = _ratio;
    if (ratio == null) return (left: l, top: t, right: r, bottom: b);
    // Oran normalize birimde: (w / vw) / (h / vh).
    final (vw, vh) = _viewPixels;
    final rn = ratio * vh / vw;
    final horizontalOnly = (moveL || moveR) && !(moveT || moveB);
    final verticalOnly = (moveT || moveB) && !(moveL || moveR);
    if (horizontalOnly) {
      final h = (r - l) / rn, cy = (s.top + s.bottom) / 2;
      t = cy - h / 2;
      b = cy + h / 2;
    } else if (verticalOnly) {
      final w = (b - t) * rn, cx = (s.left + s.right) / 2;
      l = cx - w / 2;
      r = cx + w / 2;
    } else {
      // Köşe: genişlik belirler, karşı köşe sabit.
      final h = (r - l) / rn;
      if (moveT) {
        t = b - h;
      } else {
        b = t + h;
      }
    }
    final valid = l >= -1e-9 && t >= -1e-9 && r <= 1 + 1e-9 && b <= 1 + 1e-9;
    if (!valid || r - l < minCropSize || b - t < minCropSize) return null;
    return (
      left: l.clamp(0.0, 1.0),
      top: t.clamp(0.0, 1.0),
      right: r.clamp(0.0, 1.0),
      bottom: b.clamp(0.0, 1.0),
    );
  }

  // ---- görünüm

  void _apply() => Navigator.pop(context, result);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final preview = _Preview(state: this);
    final settings = _Settings(state: this);
    if (widget.phone) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          backgroundColor: c.surface,
          leading: IconButton(
            key: const ValueKey('image-edit-cancel'),
            tooltip: l10n.cancel,
            icon: const Icon(LucideIcons200.x),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(l10n.editImage),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Space.s2),
              child: FilledButton(
                key: const ValueKey('image-edit-apply'),
                onPressed: _apply,
                child: Text(l10n.applyEdits),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: preview),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.s4,
                    Space.s2,
                    Space.s4,
                    Space.s4,
                  ),
                  child: settings,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(Space.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons200.crop, color: c.inkMuted),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Text(
                  l10n.editImage,
                  style: InkenText.heading.copyWith(color: c.ink),
                ),
              ),
              IconButton(
                key: const ValueKey('image-edit-close'),
                tooltip: l10n.cancel,
                icon: const Icon(LucideIcons200.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Space.s4),
          // Önizleme pencerenin kalan yüksekliğini alır (en çok 640'lık
          // diyalogda); ayarlar sığmazsa kendi içinde kayar.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.lg),
                          child: ColoredBox(
                            color: c.surfaceWell,
                            child: preview,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.s2),
                      Text(
                        l10n.imageEditHint,
                        style: InkenText.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s6),
                Expanded(
                  flex: 9,
                  child: SingleChildScrollView(child: settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s4),
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('image-edit-reset'),
                icon: const Icon(LucideIcons200.rotateCcw, size: 18),
                label: Text(l10n.resetEdits),
                onPressed: reset,
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('image-edit-cancel'),
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: Space.s2),
              FilledButton(
                key: const ValueKey('image-edit-apply'),
                onPressed: _apply,
                child: Text(l10n.applyEdits),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Görsel ve kırpma çerçevesi; çerçeve köşe ve kenarlardan boyutlanır,
/// içinden kayar.
class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final ImageEditorState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final box = constraints.biggest;
      return GestureDetector(
        key: const ValueKey('image-edit-preview'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => state.dragStart(d.localPosition, box),
        onPanUpdate: (d) => state.dragUpdate(d.delta, box),
        onPanEnd: (_) => state.dragEnd(),
        onPanCancel: state.dragEnd,
        child: CustomPaint(
          size: box,
          painter: _CropPainter(
            image: state.widget.image,
            imageRect: state.imageRectIn(box),
            crop: state.crop,
            turns: state.turns,
            opacity: state._opacity,
          ),
        ),
      );
    },
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.imageRect,
    required this.crop,
    required this.turns,
    required this.opacity,
  });

  final ui.Image image;
  final Rect imageRect;
  final CropRect crop;
  final int turns;
  final double opacity;

  static const _shade = Color(0xAD111419);
  static const _frame = Color(0xFFFFFFFF);
  static const _guide = Color(0x73FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    // Önizleme: döndürülmüş görselin tamamı; kırpılan dışı karartılır.
    paintEditedImage(canvas, image, imageRect, turns: turns, opacity: opacity);
    final r = Rect.fromLTRB(
      imageRect.left + crop.left * imageRect.width,
      imageRect.top + crop.top * imageRect.height,
      imageRect.left + crop.right * imageRect.width,
      imageRect.top + crop.bottom * imageRect.height,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(imageRect),
        Path()..addRect(r),
      ),
      Paint()..color = _shade,
    );
    final guide = Paint()
      ..color = _guide
      ..strokeWidth = 1;
    for (final f in const [1 / 3, 2 / 3]) {
      final x = r.left + r.width * f, y = r.top + r.height * f;
      canvas
        ..drawLine(Offset(x, r.top), Offset(x, r.bottom), guide)
        ..drawLine(Offset(r.left, y), Offset(r.right, y), guide);
    }
    canvas.drawRect(
      r,
      Paint()
        ..color = _frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final grip = Paint()
      ..color = _frame
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    const arm = 16.0;
    for (final (corner, sx, sy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + sy * arm)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + sx * arm, corner.dy),
        grip,
      );
    }
    final bar = Paint()
      ..color = _frame
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const half = 12.0;
    final c = r.center;
    canvas
      ..drawLine(Offset(c.dx - half, r.top), Offset(c.dx + half, r.top), bar)
      ..drawLine(
        Offset(c.dx - half, r.bottom),
        Offset(c.dx + half, r.bottom),
        bar,
      )
      ..drawLine(Offset(r.left, c.dy - half), Offset(r.left, c.dy + half), bar)
      ..drawLine(
        Offset(r.right, c.dy - half),
        Offset(r.right, c.dy + half),
        bar,
      );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.imageRect != imageRect ||
      old.crop != crop ||
      old.turns != turns ||
      old.opacity != opacity;
}

/// Ayarlar: kırpma oranı, sayfadaki boyut ve kilit, döndür, opaklık.
/// Telefonda "Sıfırla" kırpma oranının yanında.
class _Settings extends StatelessWidget {
  const _Settings({required this.state});

  final ImageEditorState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final phone = state.widget.phone;

    Widget label(String text) => Text(
      text,
      style: InkenText.label.copyWith(
        color: c.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s3),
      child: Divider(height: 1, color: c.line),
    );

    final presets = [
      (CropPreset.free, l10n.cropFree),
      (CropPreset.original, l10n.cropOriginal),
      (CropPreset.square, '1:1'),
      (CropPreset.fourThree, '4:3'),
      (CropPreset.sixteenNine, '16:9'),
    ];

    Widget sizeField(
      TextEditingController controller,
      String name,
      bool width,
    ) => Expanded(
      child: TextField(
        key: ValueKey(width ? 'image-edit-width' : 'image-edit-height'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: InkenText.numeric.copyWith(color: c.ink, fontSize: 15),
        decoration: InputDecoration(
          labelText: name,
          suffixText: l10n.unitCm,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (t) => state._typed(t, width: width),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: label(l10n.cropRatio)),
            if (phone)
              TextButton.icon(
                key: const ValueKey('image-edit-reset'),
                icon: const Icon(LucideIcons200.rotateCcw, size: 16),
                label: Text(l10n.resetEdits),
                onPressed: state.reset,
              ),
          ],
        ),
        const SizedBox(height: Space.s2),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (p, name) in presets)
              ChoiceChip(
                key: ValueKey('crop-${p.name}'),
                label: Text(name),
                selected: state._preset == p,
                showCheckmark: false,
                onSelected: (_) => state.choosePreset(p),
              ),
          ],
        ),
        divider(),
        label(l10n.imageSizeOnPage),
        const SizedBox(height: Space.s3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            sizeField(state._width, l10n.imageWidth, true),
            const SizedBox(width: Space.s2),
            sizeField(state._height, l10n.imageHeight, false),
            const SizedBox(width: Space.s2),
            IconButton(
              key: const ValueKey('image-edit-lock'),
              tooltip: state.locked ? l10n.aspectLocked : l10n.aspectUnlocked,
              isSelected: state.locked,
              icon: const Icon(LucideIcons200.lockOpen),
              selectedIcon: const Icon(LucideIcons200.lock),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(Sizes.target),
                foregroundColor: c.inkMuted,
                backgroundColor: state.locked ? c.brandTint : null,
                side: BorderSide(color: state.locked ? c.brand : c.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              onPressed: state.toggleLock,
            ),
          ],
        ),
        const SizedBox(height: Space.s1),
        Text(
          l10n.aspectHint,
          style: InkenText.caption.copyWith(color: c.inkMuted),
        ),
        divider(),
        Row(
          children: [
            Expanded(child: label(l10n.rotate)),
            OutlinedButton.icon(
              key: const ValueKey('image-edit-rotate-left'),
              icon: const Icon(LucideIcons200.rotateCcwSquare, size: 18),
              label: Tooltip(
                message: l10n.rotateLeft,
                child: Text(l10n.rotateLeftShort),
              ),
              onPressed: () => state.rotate(-1),
            ),
            const SizedBox(width: Space.s2),
            OutlinedButton.icon(
              key: const ValueKey('image-edit-rotate-right'),
              icon: const Icon(LucideIcons200.rotateCwSquare, size: 18),
              label: Tooltip(
                message: l10n.rotateRight,
                child: Text(l10n.rotateRightShort),
              ),
              onPressed: () => state.rotate(1),
            ),
          ],
        ),
        divider(),
        label(l10n.opacity),
        OpacitySlider(
          key: const ValueKey('image-edit-opacity'),
          percent: state.opacityPercent,
          onChanged: state.setOpacityPercent,
        ),
      ],
    );
  }
}
