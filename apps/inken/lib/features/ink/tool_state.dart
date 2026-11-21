import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';

import '../settings/settings_store.dart';

/// Seçili araç. [hand] gezinme aracıdır: hiçbir girdi çizmez.
/// [select] öğeye dokunarak ya da dikdörtgen çizerek seçer, seçileni
/// sürükleyerek taşır. [shape] çizgi, ok, dikdörtgen ya da elips çizer.
/// [text] sayfaya dokunulan yere yazar ya da var olan metni düzenler.
/// [laser] geçici kalemdir: yazdığı birkaç saniye sonra kaybolur, modele
/// girmez (geri al / kayıt yok).
/// Sıra arayüzdeki sıradır (araç kutusu, telefon rafı, Araçlar menüsü):
/// yazan araçlar yan yana, ardından silgi.
enum Tool { hand, select, pen, highlighter, laser, eraser, shape, text, textSelect }

/// Silginin ne sildiği.
enum EraserMode {
  /// Dokunduğu çizginin tamamını.
  stroke,

  /// Yalnızca üzerinden geçtiği kısmı (çizgi bölünür).
  pixel,
}

/// Dokunmanın (parmak) ne yapacağı.
enum InputMode {
  /// Kalem görülene kadar dokunma çizer; kalem görülünce dokunma kaydırır.
  auto,

  /// Yalnızca kalem ve fare çizer; dokunma kaydırır / yakınlaştırır.
  pen,

  /// Dokunma da çizer (akıllı tahta); iki parmak kaydırır / yakınlaştırır.
  touch,
}

/// Kalem renkleri (`0xAARRGGBB`), tasarım sistemindeki `pen-*` token'ları:
/// siyah, mavi, kırmızı, yeşil, turuncu, mor. İçerik rengidir; temadan
/// bağımsızdır.
const List<int> penColors = [
  0xFF1A1A1A,
  0xFF1F5AD6,
  0xFFD42A3F,
  0xFF178A47,
  0xFFE07F00,
  0xFF7A3CC0,
];

/// Fosforlu kalem renkleri (`hl-*`): sarı, yeşil, pembe, mavi. Saydamlık
/// çizerken uygulanır.
const List<int> highlighterColors = [
  0xFFFFE34D,
  0xFF93F0A6,
  0xFFFF9FD6,
  0xFF92D6FF,
];

/// Fosforlu kalemin saydamlığı (0–255): %40.
const int highlighterAlpha = 0x66;

/// Kalınlıklar, sayfa birimi (pt). Kalem: ince, orta, kalın, çok kalın;
/// fosforlu: ince, orta, kalın.
const List<double> penWidths = [1.5, 3, 5, 8];
const List<double> highlighterWidths = [10, 16, 24];

/// Silginin ekrandaki yarıçapları (mantıksal piksel): küçük, orta, büyük.
const List<double> eraserRadii = [6, 12, 24];

/// Metin büyüklükleri (pt): küçük, orta, büyük. Akıllı tahtada uzaktan
/// okunsun diye kalem yazısıyla benzer boyda.
const List<double> textSizes = [16, 24, 36];

/// Geçici kalem renkleri: kiremit (varsayılan; tasarım sistemindeki
/// `accent`, canlı durum), kırmızı, mavi, yeşil, mor, siyah.
const List<int> laserColors = [
  0xFFC4501C,
  0xFFD42A3F,
  0xFF1F5AD6,
  0xFF178A47,
  0xFF7A3CC0,
  0xFF1A1A1A,
];

/// Saklanan son özel renk sayısı: + düğmesiyle birlikte panelde tek satır
/// (288 genişlikte 48'lik dokunma alanıyla en çok 5 düğme).
const int maxCustomColors = 4;

/// Sayfa üzerindeki imleçlerin renkleri (silgi halkası, kalem ikonu):
/// koyu çizgi ve açık hale, hem beyaz sayfada hem koyu görselde seçilsin.
const int cursorInk = 0xFF1B2233;
const int cursorHalo = 0xE6FFFFFF;

/// Ölçme araçları (cetvel, gönye, iletki, pergel): sayfanın üstünde
/// saydam gövde, koyu kenar ve işaretler; beyaz sayfada da koyu görselde de
/// seçilsin. Tutamaklar marka renginde.
const int instrumentBody = 0x8CE3E9F8;
const int instrumentEdge = 0xD91B2233;
const int instrumentInk = 0xFF1B2233;
const int instrumentHandle = 0xFF233F8F;
const int instrumentHalo = 0xF2FFFFFF;

/// Görsel henüz çözülmemişken yerinde çizilen soluk kutu.
const int imagePlaceholderColor = 0x1F7F7F7F;

/// Geçici kalem: kalınlık (pt), tam görünür kalma ve solma süreleri.
const double laserWidth = 3;
const Duration laserHold = Duration(milliseconds: 1500);
const Duration laserFade = Duration(milliseconds: 1000);

class ToolState {
  const ToolState({
    this.tool = Tool.pen,
    this.penColor = defaultPenColor,
    this.penWidth = 1,
    this.highlighterColor = defaultHighlighterColor,
    this.highlighterWidth = 1,
    this.inputMode = InputMode.auto,
    this.stylusSeen = false,
    this.eraserMode = EraserMode.stroke,
    this.eraserSize = 1,
    this.laserColor = defaultLaserColor,
    this.shapeKind = ShapeKind.rectangle,
    this.shapeColor = defaultPenColor,
    this.shapeWidth = 1,
    this.textColor = defaultPenColor,
    this.textSize = 1,
    this.customColors = const [],
  });

  static const defaultPenColor = 0xFF1A1A1A;
  static const defaultHighlighterColor = 0xFFFFE34D;
  static const defaultLaserColor = 0xFFC4501C;

  final Tool tool;

  /// Renkler `0xAARRGGBB` değeridir (paletten ya da özel renk); kalınlıklar
  /// paletteki sıra numarası.
  final int penColor;
  final int penWidth;

  /// Saydamlıksız; saydamlık çizerken eklenir.
  final int highlighterColor;
  final int highlighterWidth;

  /// Son seçilen özel renkler, en yenisi başta; tüm araçlarda ortak.
  final List<int> customColors;

  final InputMode inputMode;

  final EraserMode eraserMode;

  /// [eraserRadii] içindeki sıra.
  final int eraserSize;

  double get eraserRadius => eraserRadii[eraserSize];

  final int laserColor;

  /// Şekil aracının türü; rengi ve kalınlığı ([penWidths] içindeki sıra)
  /// kalemden ayrıdır.
  final ShapeKind shapeKind;
  final int shapeColor;
  final int shapeWidth;

  /// Metnin rengi ve büyüklüğü ([textSizes] içindeki sıra).
  final int textColor;
  final int textSize;

  /// Bu oturumda en az bir kalem girdisi görüldü mü ([InputMode.auto] için).
  final bool stylusSeen;

  /// Dokunma (parmak) çiziyor mu?
  bool get touchDraws => switch (inputMode) {
    InputMode.touch => true,
    InputMode.pen => false,
    InputMode.auto => !stylusSeen,
  };

  /// Çizilecek çizginin rengi (fosforluda saydamlık dahil).
  int get strokeColor => tool == Tool.highlighter
      ? (highlighterColor & 0x00FFFFFF) | (highlighterAlpha << 24)
      : penColor;

  /// [tool]'un çizgi rengi ve kalınlığı (o araç seçili olmasa da).
  int strokeColorFor(Tool tool) => copyWith(tool: tool).strokeColor;
  double strokeWidthFor(Tool tool) => copyWith(tool: tool).strokeWidth;

  double get strokeWidth => tool == Tool.highlighter
      ? highlighterWidths[highlighterWidth]
      : penWidths[penWidth];

  ToolState copyWith({
    Tool? tool,
    int? penColor,
    int? penWidth,
    int? highlighterColor,
    int? highlighterWidth,
    InputMode? inputMode,
    bool? stylusSeen,
    EraserMode? eraserMode,
    int? eraserSize,
    int? laserColor,
    ShapeKind? shapeKind,
    int? shapeColor,
    int? shapeWidth,
    int? textColor,
    int? textSize,
    List<int>? customColors,
  }) => ToolState(
    tool: tool ?? this.tool,
    penColor: penColor ?? this.penColor,
    penWidth: penWidth ?? this.penWidth,
    highlighterColor: highlighterColor ?? this.highlighterColor,
    highlighterWidth: highlighterWidth ?? this.highlighterWidth,
    inputMode: inputMode ?? this.inputMode,
    stylusSeen: stylusSeen ?? this.stylusSeen,
    eraserMode: eraserMode ?? this.eraserMode,
    eraserSize: eraserSize ?? this.eraserSize,
    laserColor: laserColor ?? this.laserColor,
    shapeKind: shapeKind ?? this.shapeKind,
    shapeColor: shapeColor ?? this.shapeColor,
    shapeWidth: shapeWidth ?? this.shapeWidth,
    textColor: textColor ?? this.textColor,
    textSize: textSize ?? this.textSize,
    customColors: customColors ?? this.customColors,
  );
}

/// Araçların kalıcı ayarları (renk, kalınlık, silgi, şekil, metin): seçili
/// araç ve dokunma davranışı hariç. `settings.json` → `tools`. Renkler
/// `#RRGGBB`, kalınlık ve boyutlar paletteki sıra.
Map<String, Object> toolStyleOf(ToolState s) => {
  'penColor': formatHexColor(s.penColor),
  'penWidth': s.penWidth,
  'highlighterColor': formatHexColor(s.highlighterColor),
  'highlighterWidth': s.highlighterWidth,
  'eraserMode': s.eraserMode.name,
  'eraserSize': s.eraserSize,
  'laserColor': formatHexColor(s.laserColor),
  'shapeKind': s.shapeKind.name,
  'shapeColor': formatHexColor(s.shapeColor),
  'shapeWidth': s.shapeWidth,
  'textColor': formatHexColor(s.textColor),
  'textSize': s.textSize,
};

/// [toolStyleOf]'un tersi: okunamayan ya da aralık dışı değer [base]'deki
/// varsayılanda kalır (bozuk ayar dosyası uygulamayı bozmasın).
ToolState toolStyleFrom(ToolState base, Map<String, Object?>? json) {
  if (json == null) return base;
  int? color(String key) {
    final v = json[key];
    final c = v is String ? parseHexColor(v) : null;
    return c == null ? null : c | 0xFF000000;
  }

  int? index(String key, int length) {
    final v = json[key];
    return v is int && v >= 0 && v < length ? v : null;
  }

  T? named<T extends Enum>(String key, List<T> values) {
    final v = json[key];
    for (final e in values) {
      if (e.name == v) return e;
    }
    return null;
  }

  return base.copyWith(
    penColor: color('penColor'),
    penWidth: index('penWidth', penWidths.length),
    highlighterColor: color('highlighterColor'),
    highlighterWidth: index('highlighterWidth', highlighterWidths.length),
    eraserMode: named('eraserMode', EraserMode.values),
    eraserSize: index('eraserSize', eraserRadii.length),
    laserColor: color('laserColor'),
    shapeKind: named('shapeKind', ShapeKind.values),
    shapeColor: color('shapeColor'),
    shapeWidth: index('shapeWidth', penWidths.length),
    textColor: color('textColor'),
    textSize: index('textSize', textSizes.length),
  );
}

class ToolNotifier extends Notifier<ToolState> {
  @override
  ToolState build() {
    final store = ref.read(settingsStoreProvider);
    final saved = store.get<List<Object?>>(_customKey);
    final initial = toolStyleFrom(
      ToolState(
        inputMode: store.getEnum('inputMode', InputMode.values, InputMode.auto),
        customColors: [
          for (final c in saved ?? const <Object?>[])
            if (c is String && parseHexColor(c) != null) parseHexColor(c)!,
        ].take(maxCustomColors).toList(),
      ),
      store.get<Map<String, Object?>>(_styleKey),
    );
    // Renk / kalınlık değişince kalıcı yazılır (araç seçimi yazdırmaz).
    listenSelf((previous, next) {
      final style = toolStyleOf(next);
      if (previous == null || mapEquals(toolStyleOf(previous), style)) return;
      store.put(_styleKey, style);
    });
    return initial;
  }

  static const _customKey = 'customColors';
  static const _styleKey = 'tools';

  void select(Tool tool) => state = state.copyWith(tool: tool);

  /// Renk ayarlayıcıları `0xAARRGGBB` alır; araç değişmez.
  void setPenColor(int color) => state = state.copyWith(penColor: color);
  void setPenWidth(int index) => state = state.copyWith(penWidth: index);
  void setHighlighterColor(int color) =>
      state = state.copyWith(highlighterColor: color | 0xFF000000);
  void setEraserMode(EraserMode mode) =>
      state = state.copyWith(eraserMode: mode);
  void setEraserSize(int index) => state = state.copyWith(eraserSize: index);
  void setLaserColor(int color) => state = state.copyWith(laserColor: color);

  /// Şeklin türü; araç da şekle geçer.
  void setShapeKind(ShapeKind kind) =>
      state = state.copyWith(tool: Tool.shape, shapeKind: kind);
  void setShapeColor(int color) => state = state.copyWith(shapeColor: color);
  void setShapeWidth(int index) => state = state.copyWith(shapeWidth: index);
  void setTextColor(int color) => state = state.copyWith(textColor: color);
  void setTextSize(int index) => state = state.copyWith(textSize: index);
  void setHighlighterWidth(int index) =>
      state = state.copyWith(highlighterWidth: index);

  /// [tool]'un rengini ayarlar.
  void setColor(Tool tool, int color) => switch (tool) {
    Tool.highlighter => setHighlighterColor(color),
    Tool.laser => setLaserColor(color),
    Tool.shape => setShapeColor(color),
    Tool.text => setTextColor(color),
    _ => setPenColor(color),
  };

  /// Seçiciden gelen özel rengi son renklerin başına ekler (kalıcı).
  void addCustomColor(int color) {
    final list = pushRecentColor(
      state.customColors,
      color | 0xFF000000,
      max: maxCustomColors,
    );
    state = state.copyWith(customColors: list);
    ref.read(settingsStoreProvider).put(_customKey, [
      for (final c in list) formatHexColor(c),
    ]);
  }

  /// Dokunma davranışı; kalıcıdır.
  void setInputMode(InputMode mode) {
    state = state.copyWith(inputMode: mode);
    ref.read(settingsStoreProvider).put('inputMode', mode.name);
  }

  void noteStylus() {
    if (!state.stylusSeen) state = state.copyWith(stylusSeen: true);
  }
}

final toolProvider = NotifierProvider<ToolNotifier, ToolState>(
  ToolNotifier.new,
);
