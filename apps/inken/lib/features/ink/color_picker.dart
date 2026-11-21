import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inken_core/inken_core.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Özel renk seçici: doygunluk / parlaklık alanı, ton çubuğu ve onaltılık
/// kod. Seçilen opak rengi (`0xAARRGGBB`) döndürür; vazgeçilirse `null`.
Future<int?> showColorPicker(BuildContext context, {required int initial}) =>
    showDialog<int>(
      context: context,
      builder: (context) => _ColorPickerDialog(initial: initial),
    );

/// Seçicinin ölçüleri.
const double _planeWidth = Sizes.drop - 2 * Space.s4;
const double _planeHeight = 160;
const double _hueBar = 16;
const double _thumb = 22;

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final int initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _h, _s, _v;
  late final TextEditingController _hex;
  bool _hexValid = true;

  int get _color => hsvToArgb(_h, _s, _v);

  @override
  void initState() {
    super.initState();
    final (h, s, v) = argbToHsv(widget.initial);
    _h = h;
    _s = s;
    _v = v;
    _hex = TextEditingController(text: formatHexColor(widget.initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _setHsv({double? h, double? s, double? v}) {
    setState(() {
      _h = h ?? _h;
      _s = s ?? _s;
      _v = v ?? _v;
      _hex.text = formatHexColor(_color);
      _hexValid = true;
    });
  }

  void _onHex(String text) {
    final c = parseHexColor(text);
    setState(() {
      _hexValid = c != null;
      if (c == null) return;
      final (h, s, v) = argbToHsv(c);
      // Gri renkte ton belirsizdir; çubuktaki ton korunur.
      if (s > 0) _h = h;
      _s = s;
      _v = v;
    });
  }

  void _submit() {
    if (_hexValid) Navigator.pop(context, _color);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return Dialog(
      backgroundColor: c.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: SizedBox(
        width: Sizes.drop,
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.customColor,
                style: InkenText.button.copyWith(color: c.ink),
              ),
              const SizedBox(height: Space.s3),
              _SvPlane(
                hue: _h,
                saturation: _s,
                value: _v,
                label: l10n.colorSaturationValue,
                onChanged: (s, v) => _setHsv(s: s, v: v),
              ),
              const SizedBox(height: Space.s2),
              _HueBar(
                hue: _h,
                label: l10n.colorHue,
                onChanged: (h) => _setHsv(h: h),
              ),
              const SizedBox(height: Space.s2),
              Row(
                children: [
                  Container(
                    key: const ValueKey('picker-preview'),
                    width: Sizes.swatch,
                    height: Sizes.swatch,
                    decoration: BoxDecoration(
                      color: Color(_color),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.lineStrong),
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('picker-hex'),
                      controller: _hex,
                      onChanged: _onHex,
                      onSubmitted: (_) => _submit(),
                      maxLength: 7,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                      ],
                      style: InkenText.numeric.copyWith(color: c.ink),
                      decoration: InputDecoration(
                        labelText: l10n.colorHex,
                        errorText: _hexValid ? null : l10n.colorHexInvalid,
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: Space.s2),
                  FilledButton(
                    key: const ValueKey('picker-ok'),
                    onPressed: _hexValid ? _submit : null,
                    child: Text(l10n.colorChoose),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçicideki tutamak: içi seçili renk, çevresi yüzey ve mürekkep halkası
/// (her zeminde görünür).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: Container(
        width: _thumb,
        height: _thumb,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: c.surfaceRaised, width: 3),
          boxShadow: [BoxShadow(color: c.ink, spreadRadius: 1)],
        ),
      ),
    );
  }
}

/// Doygunluk (yatay) ve parlaklık (dikey) alanı.
class _SvPlane extends StatelessWidget {
  const _SvPlane({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final double hue, saturation, value;
  final String label;
  final void Function(double s, double v) onChanged;

  void _at(Offset p) => onChanged(
    (p.dx / _planeWidth).clamp(0.0, 1.0),
    1 - (p.dy / _planeHeight).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    final white = Color(hsvToArgb(hue, 0, 1));
    final black = Color(hsvToArgb(hue, 0, 0));
    final pure = Color(hsvToArgb(hue, 1, 1));
    return Semantics(
      label: label,
      child: GestureDetector(
        key: const ValueKey('picker-plane'),
        // Köşeler yuvarlak çizilir ama köşeye dokunuş da sayılır (tam doygun
        // ve siyah oradadır).
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _at(d.localPosition),
        onPanUpdate: (d) => _at(d.localPosition),
        child: SizedBox(
          width: _planeWidth,
          height: _planeHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.md),
                    gradient: LinearGradient(colors: [white, pure]),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [black.withAlpha(0), black],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: saturation * _planeWidth - _thumb / 2,
                top: (1 - value) * _planeHeight - _thumb / 2,
                child: _Thumb(color: Color(hsvToArgb(hue, saturation, value))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ton çubuğu: görünür kalınlık 16, dokunma alanı 48.
class _HueBar extends StatelessWidget {
  const _HueBar({
    required this.hue,
    required this.label,
    required this.onChanged,
  });

  final double hue;
  final String label;
  final ValueChanged<double> onChanged;

  void _at(Offset p) => onChanged((p.dx / _planeWidth).clamp(0.0, 1.0) * 359.9);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      slider: true,
      value: '${hue.round()}°',
      child: GestureDetector(
        key: const ValueKey('picker-hue'),
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _at(d.localPosition),
        onPanUpdate: (d) => _at(d.localPosition),
        child: SizedBox(
          width: _planeWidth,
          height: Sizes.target,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _hueBar,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  gradient: LinearGradient(
                    colors: [
                      for (var h = 0; h <= 360; h += 60)
                        Color(hsvToArgb(h.toDouble(), 1, 1)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: hue / 360 * _planeWidth - _thumb / 2,
                child: _Thumb(color: Color(hsvToArgb(hue, 1, 1))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
