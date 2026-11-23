import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/presentation/stage_cover.dart';
import 'package:inken_core/inken_core.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

void main() {
  test('seçili araç ikonu aynı şeklin bir kademe kalını', () {
    final icons = [
      for (final tool in Tool.values) toolIcon(tool),
      for (final kind in ShapeKind.values) shapeIcon(kind),
      for (final mode in StageCover.values) stageCoverIcon(mode),
    ];
    for (final icon in icons) {
      final bold = selectedIcon(icon);
      expect(bold.codePoint, icon.codePoint, reason: '$icon aynı şekil');
      expect(bold.fontFamily, 'Lucide300', reason: '$icon kalınlaşır');
    }
  });

  test('listede olmayan ikon değişmez', () {
    expect(selectedIcon(LucideIcons200.undo2), LucideIcons200.undo2);
  });
}
