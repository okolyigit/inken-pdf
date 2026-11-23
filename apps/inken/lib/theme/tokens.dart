// Inken PDF tasarım sistemi token'ları.
//
// Kaynak: "Inken PDF" tasarım sistemi (claude.ai artifact), `tokens.json`.
// Değer değişirse önce tasarım sisteminde değiştirilir, sonra buraya taşınır.
import 'package:flutter/material.dart';

/// Arayüz renkleri; açık (kâğıt) ve koyu (gece sınıfı) tema.
///
/// Kalem / fosforlu renkleri burada değil, `tool_state.dart`'tadır: onlar
/// içerik rengidir ve temadan bağımsızdır (sayfa her zaman beyaz).
@immutable
class InkenColors extends ThemeExtension<InkenColors> {
  const InkenColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.surfaceWell,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.brand,
    required this.brandHover,
    required this.onBrand,
    required this.brandTint,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.scrim,
    required this.shadowBar,
    required this.shadowTool,
    required this.shadowPop,
    required this.shadowDock,
  });

  /// Belge alanının zemini: sayfaların arkasındaki masa.
  final Color canvas;

  /// Menü çubuğu, araç çubuğu, paneller.
  final Color surface;

  /// Açılır paneller, menüler, dock.
  final Color surfaceRaised;
  final Color surfaceHover;

  /// Oyuk zemin (sayfa gezgini, bölümlü seçim).
  final Color surfaceWell;

  /// Dekoratif ayırıcı; kontrol kenarı için [lineStrong].
  final Color line;
  final Color lineStrong;

  final Color ink;
  final Color inkMuted;

  /// Yalnızca devre dışı ikon ve metin.
  final Color inkFaint;

  /// Seçili araç, birincil düğme, odak halkası.
  final Color brand;
  final Color brandHover;
  final Color onBrand;

  /// Açık / kapalı düğmelerin "açık" zemini.
  final Color brandTint;

  /// Yalnızca canlı durumlar (sunum, lazer, kayıt); ekranda tek yerde.
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color success;

  /// Spot ışığının dışını karartan örtü: altındaki sayfa seçilmez.
  final Color scrim;

  final List<BoxShadow> shadowBar;
  final List<BoxShadow> shadowTool;
  final List<BoxShadow> shadowPop;
  final List<BoxShadow> shadowDock;

  Color get focus => brand;

  static const light = InkenColors(
    canvas: Color(0xFFE9E3D6),
    surface: Color(0xFFFBF8F2),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF1EBE0),
    surfaceWell: Color(0xFFECE5D7),
    line: Color(0xFFDDD4C4),
    lineStrong: Color(0xFF857D6E),
    ink: Color(0xFF1B2233),
    inkMuted: Color(0xFF5B6375),
    inkFaint: Color(0xFFA19C93),
    brand: Color(0xFF233F8F),
    brandHover: Color(0xFF1A3175),
    onBrand: Color(0xFFFFFFFF),
    brandTint: Color(0xFFE3E9F8),
    accent: Color(0xFFC4501C),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB4233C),
    success: Color(0xFF1D7048),
    scrim: Color(0xE6141A26),
    shadowBar: [
      BoxShadow(color: Color(0xFFDDD4C4), offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0F1B2233), offset: Offset(0, 2), blurRadius: 8),
    ],
    shadowTool: [
      BoxShadow(color: Color(0x591A3175), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadowPop: [
      BoxShadow(color: Color(0x241B2233), offset: Offset(0, 8), blurRadius: 24),
      BoxShadow(color: Color(0xFFDDD4C4), spreadRadius: 1),
    ],
    shadowDock: [
      BoxShadow(
        color: Color(0x331B2233),
        offset: Offset(0, 12),
        blurRadius: 32,
      ),
      BoxShadow(color: Color(0xFFDDD4C4), spreadRadius: 1),
    ],
  );

  static const dark = InkenColors(
    canvas: Color(0xFF111419),
    surface: Color(0xFF1C2027),
    surfaceRaised: Color(0xFF252A33),
    surfaceHover: Color(0xFF2B313B),
    surfaceWell: Color(0xFF151920),
    line: Color(0xFF353B46),
    lineStrong: Color(0xFF727A8A),
    ink: Color(0xFFEDF0F5),
    inkMuted: Color(0xFFA3ABBA),
    inkFaint: Color(0xFF5D6471),
    brand: Color(0xFF93ABF5),
    brandHover: Color(0xFFB0C3FA),
    onBrand: Color(0xFF10162B),
    brandTint: Color(0xFF26304F),
    accent: Color(0xFFF2905C),
    onAccent: Color(0xFF1A0F08),
    danger: Color(0xFFFF8A9B),
    success: Color(0xFF6FD39B),
    scrim: Color(0xEB000000),
    shadowBar: [
      BoxShadow(color: Color(0xFF353B46), offset: Offset(0, 1)),
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8),
    ],
    shadowTool: [
      BoxShadow(color: Color(0x80000000), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadowPop: [
      BoxShadow(color: Color(0x80000000), offset: Offset(0, 8), blurRadius: 24),
      BoxShadow(color: Color(0xFF353B46), spreadRadius: 1),
    ],
    shadowDock: [
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 12),
        blurRadius: 32,
      ),
      BoxShadow(color: Color(0xFF353B46), spreadRadius: 1),
    ],
  );

  @override
  InkenColors copyWith() => this;

  @override
  InkenColors lerp(InkenColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<BoxShadow> s(List<BoxShadow> a, List<BoxShadow> b) =>
        BoxShadow.lerpList(a, b, t)!;
    return InkenColors(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      surfaceWell: c(surfaceWell, other.surfaceWell),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      brand: c(brand, other.brand),
      brandHover: c(brandHover, other.brandHover),
      onBrand: c(onBrand, other.onBrand),
      brandTint: c(brandTint, other.brandTint),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      danger: c(danger, other.danger),
      success: c(success, other.success),
      scrim: c(scrim, other.scrim),
      shadowBar: s(shadowBar, other.shadowBar),
      shadowTool: s(shadowTool, other.shadowTool),
      shadowPop: s(shadowPop, other.shadowPop),
      shadowDock: s(shadowDock, other.shadowDock),
    );
  }
}

extension InkenThemeContext on BuildContext {
  /// Etkin temanın Inken renkleri.
  InkenColors get colors =>
      Theme.of(this).extension<InkenColors>() ?? InkenColors.light;
}

/// 4px ızgara.
abstract final class Space {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
}

abstract final class Radii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;
}

/// Ölçüler: hiçbir dokunma hedefi [target]'ın altına inmez (bilinçli
/// istisnalar: masaüstü menü çubuğu, pencerelerdeki sıkı form satırları).
/// Sıkı ölçek (kullanıcı kararı, 23 Kasım 2026): dokunma hedefi 48 → 40,
/// araç düğmesi 52 → 44, menü satırı 40 → 36, renk yuvarlağı 32 → 28;
/// büyük ekranda arayüz daha az yer kaplasın. Telefonun üst çubuğu ve alt
/// rafı değişmedi.
abstract final class Sizes {
  static const double menubar = 44;

  /// Menü çubuğunun altındaki hızlı erişim çubuğu; düğmeler tam dokunma
  /// hedefi ([target]).
  static const double quickbar = 40;
  static const double menubarItem = 34;
  static const double menuRow = 36;
  static const double bar = 64;
  static const double drop = 288;
  static const double tool = 44;
  static const double target = 40;
  static const double swatch = 28;
  static const double icon = 24;

  /// Bölünmüş araç düğmesinin ok parçası.
  static const double caret = 26;

  /// Mobil: üst uygulama çubuğu ve alt araç rafı.
  static const double appbarM = 56;
  static const double dockM = 72;
  static const double drawer = 300;

  /// Telefon üst çubuğundaki ⋮ menüsünün genişliği.
  static const double overflowMenu = 240;
}

/// Yerleşim eşikleri (en kısa kenar / genişlik, dp).
enum InkenLayout {
  /// < 600: üst uygulama çubuğu + alt araç rafı, alt sayfa, yan menü.
  phone,

  /// 600–1024: menü çubuğu yok, logo düğmesi menüleri açar.
  tablet,

  /// > 1024: menü çubuğu + tam araç çubuğu.
  desktop;

  static InkenLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 600) return phone;
    return size.width <= 1024 ? tablet : desktop;
  }
}

abstract final class Fonts {
  static const ui = 'Figtree';
  static const display = 'Fraunces';
  static const mono = 'JetBrainsMono';
}

/// Tasarım sistemindeki yazı stilleri (renksiz; renk bağlamdan gelir).
abstract final class InkenText {
  static const display = TextStyle(
    fontFamily: Fonts.display,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w600,
  );
  static const heading = TextStyle(
    fontFamily: Fonts.display,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );
  static const fileName = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
  );
  static const button = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const menu = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
  static const label = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w500,
  );
  static const caption = TextStyle(
    fontFamily: Fonts.ui,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
  static const numeric = TextStyle(
    fontFamily: Fonts.mono,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Arayüz geçişleri: 120–180 ms, ease-out. Kalem çizgisinde animasyon yok.
abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 150);
  static const curve = Curves.easeOut;

  /// Yüzen kutular: kullanılmayınca bu süreden sonra soluklaşır; geçiş
  /// yavaş ve yumuşaktır (dikkat çekmesin), belirme hızlıdır.
  static const idleAfter = Duration(milliseconds: 2500);
  static const fadeOut = Duration(milliseconds: 400);
}

/// Saydamlıklar.
abstract final class Opacities {
  /// Kullanılmayan yüzen kutu (araç kutusu, sayfa gezgini, yakınlaştırma).
  static const idleFloating = 0.45;

  /// Pasif (henüz kullanılamayan) arayüz: açılış ekranındaki araç kutusu.
  static const passive = 0.5;
}

/// Gece / okuma modu.
abstract final class NightMode {
  /// Sayfaların arkasındaki zemin (açık temada da koyu: sayfalar koyu).
  static const Color desk = Color(0xFF111419);

  /// Sayfa görüntüsünün süzgeci: açıklık ters çevrilir, ton korunur
  /// (ters çevirip tonu 180° döndürmek; kırmızı kırmızı kalır). Aralık
  /// sıkıştırılır: beyaz kâğıt ≈ #1E1E1E, siyah yazı ≈ #E6E6E6 olur
  /// (tam siyah zeminde beyaz yazı göz yorar).
  static const ColorFilter pageFilter = ColorFilter.matrix([
    0.45019, -1.12157, -0.11294, 0, 230, //
    -0.33412, -0.33725, -0.11294, 0, 230,
    -0.33412, -1.12157, 0.67137, 0, 230,
    0, 0, 0, 1, 0,
  ]);
}
