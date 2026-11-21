import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken_core/inken_core.dart';

void main() {
  ProviderContainer containerWith(SettingsStore store) => ProviderContainer(
    overrides: [settingsStoreProvider.overrideWithValue(store)],
  );

  test('renk ve kalınlık kalıcı; araç seçimi yazdırmaz', () {
    final store = SettingsStore.memory();
    final a = containerWith(store);
    final n = a.read(toolProvider.notifier);
    a.read(toolProvider);
    expect(store.get<Object>('tools'), isNull, reason: 'açılışta yazılmaz');
    n.select(Tool.eraser);
    expect(
      store.get<Object>('tools'),
      isNull,
      reason: 'araç seçimi ayar değil',
    );
    n.setPenColor(penColors[2]);
    n.setPenWidth(3);
    n.setHighlighterColor(highlighterColors[1]);
    n.setEraserMode(EraserMode.pixel);
    n.setEraserSize(2);
    n.setLaserColor(laserColors[3]);
    n.setShapeKind(ShapeKind.ellipse);
    n.setShapeWidth(0);
    n.setTextSize(2);
    a.dispose();

    final b = containerWith(store);
    final s = b.read(toolProvider);
    expect(s.tool, Tool.pen, reason: 'her açılış kalemle başlar');
    expect(s.penColor, penColors[2]);
    expect(s.penWidth, 3);
    expect(s.highlighterColor, highlighterColors[1]);
    expect(s.eraserMode, EraserMode.pixel);
    expect(s.eraserSize, 2);
    expect(s.laserColor, laserColors[3]);
    expect(s.shapeKind, ShapeKind.ellipse);
    expect(s.shapeWidth, 0);
    expect(s.textSize, 2);
    b.dispose();
  });

  test('bozuk ya da aralık dışı değerler varsayılanda kalır', () {
    final store = SettingsStore.memory({
      'tools': {
        'penColor': 'kırmızı',
        'penWidth': 99,
        'eraserMode': 'yok',
        'textSize': -1,
        'shapeColor': '#123456',
      },
    });
    final c = containerWith(store);
    final s = c.read(toolProvider);
    const d = ToolState();
    expect(s.penColor, d.penColor);
    expect(s.penWidth, d.penWidth);
    expect(s.eraserMode, d.eraserMode);
    expect(s.textSize, d.textSize);
    expect(s.shapeColor, 0xFF123456, reason: 'geçerli olan okunur');
    c.dispose();
  });

  test('ayar dosyası tamamen bozuksa varsayılanlar', () {
    final c = containerWith(SettingsStore.memory({'tools': 'bozuk'}));
    expect(c.read(toolProvider).penColor, const ToolState().penColor);
    c.dispose();
  });
}
