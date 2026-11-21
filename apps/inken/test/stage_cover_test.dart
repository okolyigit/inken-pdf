import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/presentation/stage_cover.dart';
import 'package:inken/l10n/app_localizations.dart';

void main() {
  const size = Size(800, 600);

  group('örtü geometrisi', () {
    test('ışık kaydırılır; merkez alanın dışına çıkmaz', () {
      const s = StageCoverState(spotCenter: Offset(0.5, 0.5));
      final moved = s.movedSpot(const Offset(80, -60), size);
      expect(moved.spotCenterIn(size), const Offset(480, 240));
      final far = s.movedSpot(const Offset(5000, 5000), size);
      expect(far.spotCenter, const Offset(1, 1));
      final back = s.movedSpot(const Offset(-5000, -5000), size);
      expect(back.spotCenter, Offset.zero);
    });

    test('ışığın yarıçapı en az 40 px, en çok kısa kenar', () {
      const s = StageCoverState();
      expect(s.resizedSpot(150, size).spotRadiusIn(size), closeTo(150, 1e-9));
      expect(s.resizedSpot(5, size).spotRadiusIn(size), minSpotRadius);
      expect(s.resizedSpot(5000, size).spotRadiusIn(size), 600);
    });

    test('oransal konum pencere değişince yerinde kalır', () {
      final s = const StageCoverState().movedSpot(Offset.zero, size);
      const big = Size(1600, 1200);
      expect(s.spotCenterIn(big), s.spotCenterIn(size) * 2);
      expect(s.spotRadiusIn(big), closeTo(s.spotRadiusIn(size) * 2, 1e-9));
    });

    test('perde indirilir, kaldırılır; tutamak çubuğu hep görünür', () {
      const s = StageCoverState();
      expect(s.curtainTopIn(size), 0);
      expect(s.movedCurtain(200, size).curtainTopIn(size), 200);
      expect(s.movedCurtain(-50, size).curtainTopIn(size), 0);
      expect(
        s.movedCurtain(5000, size).curtainTopIn(size),
        size.height - curtainBarHeight,
      );
      // Pencere küçülünce de çubuk alanın içinde kalır.
      final low = s.movedCurtain(5000, size);
      expect(low.curtainTopIn(const Size(800, 300)), 300 - curtainBarHeight);
    });

    test('boş alanda değişmez', () {
      const s = StageCoverState();
      expect(identical(s.movedSpot(const Offset(9, 9), Size.zero), s), isTrue);
      expect(identical(s.movedCurtain(9, Size.zero), s), isTrue);
    });
  });

  group('örtü durumu', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    StageCoverState state() => container.read(stageCoverProvider);
    StageCoverNotifier notifier() =>
        container.read(stageCoverProvider.notifier);

    test('aç / kapat; ikisi aynı anda açık olmaz', () {
      notifier().toggle(StageCover.spotlight);
      expect(state().mode, StageCover.spotlight);
      notifier().toggle(StageCover.curtain);
      expect(state().mode, StageCover.curtain);
      notifier().toggle(StageCover.curtain);
      expect(state().mode, StageCover.none);
    });

    test('ışığın yeri hatırlanır; perde her açılışta tamamen örter', () {
      notifier().toggle(StageCover.spotlight);
      notifier().update(state().movedSpot(const Offset(100, 0), size));
      final center = state().spotCenter;
      notifier().toggle(StageCover.curtain);
      notifier().update(state().movedCurtain(300, size));
      notifier().close();
      notifier().toggle(StageCover.spotlight);
      expect(state().spotCenter, center);
      notifier().toggle(StageCover.curtain);
      expect(state().curtainTop, 0);
    });
  });

  group('örtü katmanı', () {
    late ProviderContainer container;
    late List<Offset> below;

    setUp(() {
      container = ProviderContainer();
      below = [];
    });
    tearDown(() => container.dispose());

    StageCoverState state() => container.read(stageCoverProvider);

    /// Alttaki "belge" dokunulan yerleri kaydeder.
    Future<void> pump(WidgetTester t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => below.add(d.localPosition),
                    child: const SizedBox.expand(),
                  ),
                ),
                const Positioned.fill(child: StageCoverLayer()),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('kapalıyken dokunuşlar belgeye geçer', (t) async {
      await pump(t);
      await t.tapAt(const Offset(10, 10));
      expect(below, hasLength(1));
    });

    testWidgets('ışığın içi belgeye geçer; karartı geçirmez, sürükleyince '
        'ışık taşınır', (t) async {
      await pump(t);
      container.read(stageCoverProvider.notifier).toggle(StageCover.spotlight);
      await t.pumpAndSettle();
      final center = state().spotCenterIn(size);
      final radius = state().spotRadiusIn(size);

      await t.tapAt(center);
      expect(below, [center]);

      await t.tapAt(const Offset(5, 590));
      expect(below, hasLength(1), reason: 'karartı dokunuşu tutar');

      await t.dragFrom(const Offset(5, 590), const Offset(100, -50));
      await t.pump();
      final moved = state().spotCenterIn(size);
      expect(moved.dx, closeTo(center.dx + 100, 20));
      expect(moved.dy, closeTo(center.dy - 50, 20));
      expect(state().spotRadiusIn(size), radius);
    });

    testWidgets('fare tekerleği ve tutamak ışığı boyutlandırır', (t) async {
      await pump(t);
      container.read(stageCoverProvider.notifier).toggle(StageCover.spotlight);
      await t.pumpAndSettle();
      final radius = state().spotRadiusIn(size);

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(mouse.hover(const Offset(5, 590)));
      await t.sendEventToBinding(mouse.scroll(const Offset(0, -80)));
      await t.pump();
      expect(state().spotRadiusIn(size), closeTo(radius + 20, 1e-6));

      final handle = find.byKey(const ValueKey('spotlight-resize'));
      final grow = state().spotRadiusIn(size);
      await t.drag(handle, const Offset(30, 30));
      await t.pump();
      expect(state().spotRadiusIn(size), greaterThan(grow + 20));
    });

    testWidgets('ışığın kapat düğmesi örtüyü kaldırır', (t) async {
      await pump(t);
      container.read(stageCoverProvider.notifier).toggle(StageCover.spotlight);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('spotlight-close')));
      await t.pumpAndSettle();
      expect(state().mode, StageCover.none);
      await t.tapAt(const Offset(5, 590));
      expect(below, hasLength(1));
    });

    testWidgets('perde: sürükleyince iner; üstü belgeye geçer, perde '
        'geçirmez', (t) async {
      await pump(t);
      container.read(stageCoverProvider.notifier).toggle(StageCover.curtain);
      await t.pumpAndSettle();

      await t.tapAt(const Offset(400, 300));
      expect(below, isEmpty, reason: 'tamamen örtülü');

      await t.dragFrom(const Offset(400, 300), const Offset(0, 200));
      await t.pump();
      final top = state().curtainTopIn(size);
      expect(top, closeTo(200, 20));

      await t.tapAt(Offset(400, top - 20));
      expect(below, hasLength(1));
      await t.tapAt(Offset(400, top + 100));
      expect(below, hasLength(1));

      // Tekerlek de indirir.
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await t.sendEventToBinding(mouse.hover(Offset(400, top + 100)));
      await t.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
      await t.pump();
      expect(state().curtainTopIn(size), closeTo(top + 60, 1e-6));

      await t.tap(find.byKey(const ValueKey('curtain-close')));
      await t.pumpAndSettle();
      expect(state().mode, StageCover.none);
    });
  });
}
