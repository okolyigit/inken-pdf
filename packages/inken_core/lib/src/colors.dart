import 'dart:math' as math;

/// Renk yardımcıları: özel renk seçimi için. Renkler `0xAARRGGBB`; özel
/// renkler her zaman opaktır (fosforlunun saydamlığı çizerken eklenir).

/// `#RRGGBB`, `RRGGBB`, `#RGB` ya da `RGB` biçimindeki kodu okur; büyük /
/// küçük harf ve baştaki / sondaki boşluk önemsizdir. Geçersizse `null`.
int? parseHexColor(String text) {
  var s = text.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return null;
  if (s.length == 3) {
    s = s.split('').map((c) => '$c$c').join();
  }
  if (s.length != 6) return null;
  return 0xFF000000 | int.parse(s, radix: 16);
}

/// `#RRGGBB` (büyük harf; saydamlık yazılmaz).
String formatHexColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Ton (0–360), doygunluk ve parlaklık (0–1) → opak `0xAARRGGBB`.
int hsvToArgb(double hue, double saturation, double value) {
  final h = (hue % 360 + 360) % 360;
  final s = saturation.clamp(0.0, 1.0);
  final v = value.clamp(0.0, 1.0);
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;
  final (r, g, b) = switch (h ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int byte(double f) => ((f + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | byte(r) << 16 | byte(g) << 8 | byte(b);
}

/// `0xAARRGGBB` → (ton 0–360, doygunluk 0–1, parlaklık 0–1). Gri renklerde
/// ton 0'dır.
(double, double, double) argbToHsv(int argb) {
  final r = (argb >> 16 & 0xFF) / 255;
  final g = (argb >> 8 & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final max = math.max(r, math.max(g, b));
  final min = math.min(r, math.min(g, b));
  final d = max - min;
  double h;
  if (d == 0) {
    h = 0;
  } else if (max == r) {
    h = 60 * (((g - b) / d) % 6);
  } else if (max == g) {
    h = 60 * ((b - r) / d + 2);
  } else {
    h = 60 * ((r - g) / d + 4);
  }
  if (h < 0) h += 360;
  return (h, max == 0 ? 0 : d / max, max);
}

/// Son kullanılan özel renkler listesine [color]'ı en başa ekler: varsa
/// yerinden alınır, liste [max] öğeyi geçmez (en eskisi düşer).
List<int> pushRecentColor(List<int> recent, int color, {int max = 5}) =>
    [color, ...recent.where((c) => c != color)].take(max).toList();

/// Gece modunda çizim rengi: koyu sayfada okunsun diye açık tona çevrilir.
/// Gri tonlar (siyah kalem, beyaz) ters çevrilir; renkliler tonunu ve
/// doygunluğunu korur, koyuysa aynı oranda açılır (koyu mavi → açık mavi),
/// açıksa olduğu gibi kalır (fosforlu sarı). Saydamlık korunur.
///
/// Yalnızca ekranda; kaydedilen renk değişmez.
int nightInkColor(int argb) {
  final r = (argb >> 16 & 0xFF) / 255;
  final g = (argb >> 8 & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final hi = math.max(r, math.max(g, b));
  final lo = math.min(r, math.min(g, b));
  final l = (hi + lo) / 2;
  final d = hi - lo;
  final s = d == 0 ? 0.0 : d / (1 - (2 * l - 1).abs());
  final nl = s < 0.2 || l < 0.5 ? 1 - l : l;
  if (nl == l) return argb;
  double h;
  if (d == 0) {
    h = 0;
  } else if (hi == r) {
    h = ((g - b) / d) % 6;
  } else if (hi == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  // HSL → RGB.
  final c = (1 - (2 * nl - 1).abs()) * s;
  final x = c * (1 - (h % 2 - 1).abs());
  final m = nl - c / 2;
  final (r1, g1, b1) = switch (h.floor()) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int ch(double v) => ((v + m) * 255).round().clamp(0, 255);
  return (argb & 0xFF000000) | ch(r1) << 16 | ch(g1) << 8 | ch(b1);
}
