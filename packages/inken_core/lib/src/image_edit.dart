import 'dart:math' as math;
import 'dart:typed_data';

import 'model.dart';

// ---- opaklık

/// Opaklığı ayarlanabilen öğe: metin (renginin alfası) ve görsel.
bool hasOpacity(InkItem item) => item is TextItem || item is ImageItem;

/// Öğenin opaklığı (0–1); opaklığı olmayan öğede 1.
double itemOpacity(InkItem item) => switch (item) {
  TextItem(:final color) => (color >>> 24) / 255,
  ImageItem(:final opacity) => opacity,
  _ => 1,
};

/// [opacity] (0–1) uygulanmış öğe; opaklığı olmayan öğe olduğu gibi döner.
/// Metinde rengin alfası değişir (PDF'e `/GS` ile yazılır).
InkItem withOpacity(InkItem item, double opacity) {
  final o = opacity.clamp(0.0, 1.0);
  return switch (item) {
    TextItem(:final color) => item.copyWith(
      color: ((o * 255).round() << 24) | (color & 0x00FFFFFF),
    ),
    ImageItem() => item.copyWith(opacity: o),
    _ => item,
  };
}

// ---- kırpma ve döndürme

/// Görselin 0–1 oranlarıyla bir dikdörtgeni (sol, üst, sağ, alt).
typedef CropRect = ({double left, double top, double right, double bottom});

const CropRect fullCrop = (left: 0, top: 0, right: 1, bottom: 1);

/// Öğenin kırpması (orijinal görselin oranlarıyla).
CropRect cropOf(ImageItem g) => (
  left: g.cropLeft,
  top: g.cropTop,
  right: g.cropRight,
  bottom: g.cropBottom,
);

/// Kırpmanın en küçük kenarı (oran): görsel hiçbir zaman sıfıra inmez.
const double minCropSize = 0.02;

/// [c]'yi 0–1 içine alır ve en az [minCropSize] genişlikte tutar.
CropRect clampCrop(CropRect c) {
  var l = c.left.clamp(0.0, 1.0 - minCropSize);
  var t = c.top.clamp(0.0, 1.0 - minCropSize);
  var r = c.right.clamp(l + minCropSize, 1.0);
  var b = c.bottom.clamp(t + minCropSize, 1.0);
  return (left: l, top: t, right: r, bottom: b);
}

/// Çeyrek tur sayısını 0–3'e indirger (eksi değer saat yönünün tersi).
int normalizeTurns(int turns) => ((turns % 4) + 4) % 4;

/// Orijinal görsel oranlarındaki [c]'yi, görsel saat yönünde [turns]
/// çeyrek tur döndürülünce görünen oranlara çevirir.
CropRect cropToView(CropRect c, int turns) {
  var r = c;
  for (var i = 0; i < normalizeTurns(turns); i++) {
    // Saat yönünde: (u, v) → (1 − v, u).
    r = (left: 1 - r.bottom, top: r.left, right: 1 - r.top, bottom: r.right);
  }
  return r;
}

/// [cropToView]'in tersi: görünen oranlardan orijinal görsel oranlarına.
CropRect cropToSource(CropRect c, int turns) {
  var r = c;
  for (var i = 0; i < normalizeTurns(turns); i++) {
    // Saat yönünün tersi: (u, v) → (v, 1 − u).
    r = (left: r.top, top: 1 - r.right, right: r.bottom, bottom: 1 - r.left);
  }
  return r;
}

/// [width]×[height] pikselli görselin kırpılıp döndürülmüş hâlinin piksel
/// boyutu (kesirli; oran hesabı için).
({double width, double height}) croppedSize(
  int width,
  int height,
  CropRect crop,
  int turns,
) {
  final w = (crop.right - crop.left) * width;
  final h = (crop.bottom - crop.top) * height;
  return normalizeTurns(turns).isOdd
      ? (width: h, height: w)
      : (width: w, height: h);
}

/// Kırpma ve döndürmede kullanılacak piksel dikdörtgeni: en az 1 piksel.
({int x, int y, int w, int h}) cropPixels(int width, int height, CropRect c) {
  final x0 = (c.left * width).floor().clamp(0, width - 1);
  final y0 = (c.top * height).floor().clamp(0, height - 1);
  final x1 = (c.right * width).ceil().clamp(x0 + 1, width);
  final y1 = (c.bottom * height).ceil().clamp(y0 + 1, height);
  return (x: x0, y: y0, w: x1 - x0, h: y1 - y0);
}

/// Satır satır RGBA pikseller.
typedef RgbaPixels = ({Uint8List rgba, int width, int height});

/// Görseli PDF'e yazmadan önce hazırlar: [crop] ile kırpar, saat yönünde
/// [turns] çeyrek tur döndürür, alfayı [opacity] ile çarpar. Hiçbiri
/// gerekmiyorsa aynı pikselleri döndürür (kopyalamaz).
RgbaPixels transformImagePixels(
  Uint8List rgba,
  int width,
  int height, {
  CropRect crop = fullCrop,
  int turns = 0,
  double opacity = 1,
}) {
  final q = normalizeTurns(turns);
  final o = opacity.clamp(0.0, 1.0);
  final px = cropPixels(width, height, clampCrop(crop));
  final whole = px.x == 0 && px.y == 0 && px.w == width && px.h == height;
  if (whole && q == 0 && o >= 1) {
    return (rgba: rgba, width: width, height: height);
  }
  final outW = q.isOdd ? px.h : px.w;
  final outH = q.isOdd ? px.w : px.h;
  final out = Uint8List(outW * outH * 4);
  final alpha = (o * 256).round(); // 256 = değişmez
  for (var y = 0; y < px.h; y++) {
    for (var x = 0; x < px.w; x++) {
      // Kırpılmış görselde (x, y) → döndürülmüşte (dx, dy).
      final (dx, dy) = switch (q) {
        1 => (px.h - 1 - y, x),
        2 => (px.w - 1 - x, px.h - 1 - y),
        3 => (y, px.w - 1 - x),
        _ => (x, y),
      };
      final s = ((px.y + y) * width + px.x + x) * 4;
      final d = (dy * outW + dx) * 4;
      out[d] = rgba[s];
      out[d + 1] = rgba[s + 1];
      out[d + 2] = rgba[s + 2];
      out[d + 3] = alpha >= 256 ? rgba[s + 3] : (rgba[s + 3] * alpha) >> 8;
    }
  }
  return (rgba: out, width: outW, height: outH);
}

/// Görsel düzenleyicinin sonucu öğeye uygulanır: kutu sol üst köşeden
/// sabit, en az 1 pt.
ImageItem applyImageEdit(
  ImageItem g, {
  required CropRect crop,
  required int turns,
  required double width,
  required double height,
  required double opacity,
}) {
  final c = clampCrop(crop);
  return g.copyWith(
    cropLeft: c.left,
    cropTop: c.top,
    cropRight: c.right,
    cropBottom: c.bottom,
    rotation: normalizeTurns(turns),
    width: math.max(1, width),
    height: math.max(1, height),
    opacity: opacity.clamp(0.0, 1.0),
  );
}
