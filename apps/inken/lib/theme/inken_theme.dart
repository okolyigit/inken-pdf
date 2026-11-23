import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tasarım sistemi token'larından Material teması.
ThemeData inkenTheme(Brightness brightness) {
  final c = brightness == Brightness.light
      ? InkenColors.light
      : InkenColors.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.brandTint,
    onPrimaryContainer: c.brand,
    secondary: c.brand,
    onSecondary: c.onBrand,
    tertiary: c.accent,
    onTertiary: c.onAccent,
    error: c.danger,
    onError: c.surfaceRaised,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerLowest: c.surfaceRaised,
    surfaceContainerLow: c.surfaceRaised,
    surfaceContainer: c.surfaceRaised,
    surfaceContainerHigh: c.surfaceRaised,
    surfaceContainerHighest: c.surfaceWell,
    outline: c.lineStrong,
    outlineVariant: c.line,
    inverseSurface: c.ink,
    onInverseSurface: c.surface,
    inversePrimary: c.brandTint,
    shadow: Colors.black,
    surfaceTint: Colors.transparent,
  );

  TextStyle ink(TextStyle s, [Color? color]) =>
      s.copyWith(color: color ?? c.ink);

  final textTheme = TextTheme(
    displayLarge: ink(InkenText.display),
    displayMedium: ink(InkenText.display),
    displaySmall: ink(InkenText.display),
    headlineLarge: ink(InkenText.heading),
    headlineMedium: ink(InkenText.heading),
    headlineSmall: ink(InkenText.heading),
    titleLarge: ink(InkenText.heading),
    titleMedium: ink(InkenText.fileName),
    titleSmall: ink(InkenText.button),
    bodyLarge: ink(InkenText.body),
    bodyMedium: ink(InkenText.body),
    bodySmall: ink(InkenText.caption, c.inkMuted),
    labelLarge: ink(InkenText.button),
    labelMedium: ink(InkenText.label),
    labelSmall: ink(InkenText.caption),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  const buttonSize = Size(64, Sizes.target);
  const buttonPadding = EdgeInsets.symmetric(horizontal: Space.s4);
  WidgetStateProperty<Color?> hover(Color color) =>
      WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed)
            ? color
            : null,
      );
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: c.focus, width: 2)
        : null,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: Fonts.ui,
    textTheme: textTheme,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.surface,
    dividerColor: c.line,
    hoverColor: c.surfaceHover,
    focusColor: c.brandTint,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    // Düğmeler kendi boyunda (Sizes.target); Material'in görünmez 48 px
    // dokunma payı sıkı ölçeği geri büyütmesin.
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    extensions: [c],
    iconTheme: IconThemeData(color: c.ink, size: Sizes.icon),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      textStyle: InkenText.caption.copyWith(color: c.surface),
      padding: const EdgeInsets.symmetric(horizontal: Space.s2, vertical: 6),
      waitDuration: const Duration(milliseconds: 500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: ink(InkenText.heading),
      contentTextStyle: ink(InkenText.body),
      actionsPadding: const EdgeInsets.fromLTRB(
        Space.s6,
        0,
        Space.s6,
        Space.s6,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: InkenText.body.copyWith(color: c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      width: 560,
    ),
    // Birincil: ekrandaki tek ana eylem.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(InkenText.button),
        iconSize: const WidgetStatePropertyAll(20),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? Colors.transparent
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.pressed)
              ? c.brandHover
              : c.brand,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.inkFaint : c.onBrand,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: focusRing,
      ),
    ),
    // İkincil: kenarlıklı.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(InkenText.button),
        iconSize: const WidgetStatePropertyAll(20),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.inkFaint : c.ink,
        ),
        backgroundColor: hover(c.surfaceHover),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.focused)
                ? c.focus
                : s.contains(WidgetState.disabled)
                ? c.line
                : c.lineStrong,
            width: s.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
      ),
    ),
    // Hayalet: düşük öncelikli eylemler ("Sonra", "Vazgeç").
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(buttonSize),
        padding: const WidgetStatePropertyAll(buttonPadding),
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: const WidgetStatePropertyAll(InkenText.button),
        iconSize: const WidgetStatePropertyAll(20),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.inkFaint : c.ink,
        ),
        backgroundColor: hover(c.surfaceHover),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: focusRing,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(Sizes.target)),
        iconSize: const WidgetStatePropertyAll(Sizes.icon),
        shape: WidgetStatePropertyAll(buttonShape),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.inkFaint
              : s.contains(WidgetState.selected)
              ? c.brand
              : c.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? null
              : s.contains(WidgetState.selected)
              ? c.brandTint
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.pressed)
              ? c.surfaceHover
              : null,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: focusRing,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(c.ink.withValues(alpha: 0.5)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: c.line),
          ),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(Space.s1)),
        minimumSize: const WidgetStatePropertyAll(Size(268, 0)),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        // Odaklı satır arka planıyla belli olur; ayrıca çerçeve yok.
        side: const WidgetStatePropertyAll(BorderSide.none),
        minimumSize: const WidgetStatePropertyAll(Size(0, Sizes.menuRow)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Space.s3),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        textStyle: WidgetStatePropertyAll(
          InkenText.menu.copyWith(fontWeight: FontWeight.w400),
        ),
        iconSize: const WidgetStatePropertyAll(18),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? c.inkFaint : c.ink,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? c.inkFaint
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
              ? c.ink
              : c.inkMuted,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? null
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
              ? c.surfaceHover
              : null,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.brand : c.lineStrong,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.brand,
      inactiveTrackColor: c.line,
      thumbColor: c.brand,
      overlayColor: c.brandTint,
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.never,
      // Küçük düğme, ölçülü üzerine gelme halkası (varsayılan 24 px çok büyük).
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
  );
}
