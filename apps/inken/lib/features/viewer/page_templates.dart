import 'package:flutter/material.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'app_menus.dart';

/// Araya eklenen sayfanın zemini: ad ve ikon (menü, hızlı erişim çubuğu).
String pageTemplateLabel(AppLocalizations l10n, PageTemplate t) => switch (t) {
  PageTemplate.blank => l10n.templateBlank,
  PageTemplate.grid => l10n.templateGrid,
  PageTemplate.dotted => l10n.templateDotted,
  PageTemplate.lined => l10n.templateLined,
  PageTemplate.coordinate => l10n.templateCoordinate,
};

IconData pageTemplateIcon(PageTemplate t) => switch (t) {
  PageTemplate.blank => LucideIcons.file,
  PageTemplate.grid => LucideIcons.grid3x3,
  PageTemplate.dotted => LucideIcons.gripHorizontal,
  PageTemplate.lined => LucideIcons.alignJustify,
  PageTemplate.coordinate => LucideIcons.chartScatter,
};

/// Kâğıt rengi adı.
String pageColorLabel(AppLocalizations l10n, PageColor c) => switch (c) {
  PageColor.white => l10n.pageColorWhite,
  PageColor.black => l10n.pageColorBlack,
  PageColor.straw => l10n.pageColorStraw,
};

/// "Sayfa ekle" menüsünün içi (menü çubuğu, hızlı erişim çubuğu, sayfa
/// paneli): üstte yön (dikey / yatay) ve kâğıt rengi (beyaz / siyah /
/// saman kâğıdı) seçimi (menüyü kapatmaz), altta zeminler. Zemine
/// dokunmak [onInsert]'i seçili yön ve renkle çağırır.
/// [onInsert] `null` ise hepsi pasif. [keyPrefix] testlerin öğeleri
/// bulması için.
List<Widget> pageInsertMenuChildren(
  AppLocalizations l10n, {
  required PageOrientation orientation,
  required ValueChanged<PageOrientation>? onOrientation,
  required PageColor color,
  required ValueChanged<PageColor>? onColor,
  required ValueChanged<PageTemplate>? onInsert,
  String keyPrefix = 'insert',
}) => [
  for (final o in PageOrientation.values)
    RadioMenuButton<PageOrientation>(
      key: ValueKey('$keyPrefix-${o.name}'),
      value: o,
      groupValue: orientation,
      closeOnActivate: false,
      onChanged: onInsert == null || onOrientation == null
          ? null
          : (v) => onOrientation(v!),
      trailingIcon: Icon(switch (o) {
        PageOrientation.portrait => LucideIcons.rectangleVertical,
        PageOrientation.landscape => LucideIcons.rectangleHorizontal,
      }, size: 18),
      child: Text(switch (o) {
        PageOrientation.portrait => l10n.orientationPortrait,
        PageOrientation.landscape => l10n.orientationLandscape,
      }),
    ),
  menuSeparator,
  for (final c in PageColor.values)
    RadioMenuButton<PageColor>(
      key: ValueKey('$keyPrefix-color-${c.name}'),
      value: c,
      groupValue: color,
      closeOnActivate: false,
      onChanged: onInsert == null || onColor == null
          ? null
          : (v) => onColor(v!),
      trailingIcon: _Swatch(pageColorArgb(c)),
      child: Text(pageColorLabel(l10n, c)),
    ),
  menuSeparator,
  for (final t in PageTemplate.values)
    MenuItemButton(
      key: ValueKey('$keyPrefix-${t.name}'),
      leadingIcon: Icon(pageTemplateIcon(t)),
      onPressed: onInsert == null ? null : () => onInsert(t),
      child: Text(pageTemplateLabel(l10n, t)),
    ),
];

/// Kâğıt renginin küçük örneği (ince çerçeveli kare).
class _Swatch extends StatelessWidget {
  const _Swatch(this.argb);
  final int argb;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: Color(argb),
      borderRadius: BorderRadius.circular(Radii.sm / 2),
      border: Border.all(color: context.colors.line),
    ),
  );
}
