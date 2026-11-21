import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/viewer/idle_fade.dart';
import 'package:inken/theme/tokens.dart';

void main() {
  late ProviderContainer container;
  late int taps;

  Future<void> pump(
    WidgetTester t, {
    bool keepAwake = false,
    Object? wakeKey,
  }) async {
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Center(
            child: IdleFade(
              keepAwake: keepAwake,
              wakeKey: wakeKey,
              child: TextButton(
                key: const ValueKey('btn'),
                onPressed: () => taps++,
                child: const Text('x'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacity(WidgetTester t) =>
      t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  Future<void> idle(WidgetTester t) async {
    await t.pump(Motion.idleAfter + const Duration(milliseconds: 10));
    await t.pumpAndSettle();
  }

  setUp(() {
    container = ProviderContainer();
    taps = 0;
  });
  tearDown(() => container.dispose());

  testWidgets('kullanılmayınca soluklaşır, dokununca belirir ve çalışır', (
    t,
  ) async {
    await pump(t);
    expect(opacity(t), 1);
    await idle(t);
    expect(opacity(t), Opacities.idleFloating);

    // Soluk düğme ilk dokunuşta çalışır.
    await t.tap(find.byKey(const ValueKey('btn')));
    await t.pump();
    expect(taps, 1);
    expect(opacity(t), 1);
    await idle(t);
    expect(opacity(t), Opacities.idleFloating);
  });

  testWidgets('fare üzerindeyken soluklaşmaz', (t) async {
    await pump(t);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(find.byKey(const ValueKey('btn'))));
    await idle(t);
    expect(opacity(t), 1);
    await mouse.moveTo(Offset.zero);
    await idle(t);
    expect(opacity(t), Opacities.idleFloating);
  });

  testWidgets('panel açıkken soluklaşmaz; wakeKey değişince belirir', (
    t,
  ) async {
    await pump(t, keepAwake: true);
    await idle(t);
    expect(opacity(t), 1);
    await pump(t, wakeKey: 'kalem');
    await idle(t);
    expect(opacity(t), Opacities.idleFloating);
    await pump(t, wakeKey: 'silgi');
    await t.pumpAndSettle();
    expect(opacity(t), 1);
  });

  testWidgets('ayar kapalıysa hep tam görünür', (t) async {
    container.read(floatingFadeProvider.notifier).set(false);
    await pump(t);
    await idle(t);
    expect(opacity(t), 1);
  });
}
