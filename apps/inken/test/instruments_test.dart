import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/ink_session.dart';
import 'package:inken/features/ink/instruments.dart';
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// Tek sayfa: 300×400 pt, ölçek 2; ekranda (40,20)'den başlar.
class _FakeGeometry extends ChangeNotifier implements PageGeometry {
  static const scale = 2.0;
  static const origin = Offset(40, 20);

  PageViewport get _page => PageViewport(
    index: 0,
    rect: origin & const Size(300 * scale, 400 * scale),
    scale: scale,
  );

  @override
  bool get isReady => true;

  @override
  List<PageViewport> get visiblePages => [_page];

  @override
  PageViewport? pageAt(Offset local) =>
      _page.rect.contains(local) ? _page : null;

  @override
  PageViewport? viewportOf(int index) => index == 0 ? _page : null;
}

/// Sayfa noktasının ekrandaki yeri.
Offset _screen(double x, double y) =>
    _FakeGeometry.origin + Offset(x, y) * _FakeGeometry.scale;

void main() {
  late InkSession session;
  late ProviderContainer container;

  Future<void> pump(WidgetTester t, {bool panel = false}) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final geometry = _FakeGeometry();
    session = InkSession(InkenDocument.forPdf([(width: 300, height: 400)]));
    container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(session.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: InkLayer(
                    geometry: geometry,
                    session: session,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                Positioned.fill(
                  child: InstrumentLayer(geometry: geometry, session: session),
                ),
                if (panel)
                  const Positioned(
                    right: 0,
                    top: 0,
                    width: 288,
                    child: Material(child: ToolOptions(tool: Tool.shape)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    container.read(toolProvider.notifier).select(Tool.pen);
    await t.pump();
  }

  InstrumentsNotifier instruments() =>
      container.read(instrumentsProvider.notifier);

  InstrumentPose? poseOf(InstrumentKind kind) =>
      container.read(instrumentsProvider)[kind];

  /// Aracı açar ve sayfada (x, y)'ye koyar.
  Future<void> place(
    WidgetTester t,
    InstrumentKind kind, {
    double x = 150,
    double y = 200,
    double angle = 0,
    double radius = compassDefaultRadius,
  }) async {
    instruments().open(kind);
    instruments().update(
      InstrumentPose(
        kind: kind,
        page: 0,
        x: x,
        y: y,
        angle: angle,
        radius: radius,
      ),
    );
    await t.pump();
  }

  Future<void> drag(
    WidgetTester t,
    List<Offset> path, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    final g = await t.startGesture(path.first, kind: kind);
    for (final (i, p) in path.skip(1).indexed) {
      await g.moveTo(p, timeStamp: Duration(milliseconds: 16 * (i + 1)));
    }
    await g.up();
    await t.pump();
  }

  List<InkItem> items() => session.document.pages[0].items;

  const top = 200 - rulerHeight / 2;

  group('kenara yaslama', () {
    testWidgets('cetvelin üst kenarı boyunca titrek çizgi düz çıkar', (
      t,
    ) async {
      await pump(t);
      await place(t, InstrumentKind.ruler);
      final width = container.read(toolProvider).strokeWidth;
      // Kenarın 4 pt dışından, inip çıkarak.
      await drag(t, [
        for (var i = 0; i <= 10; i++)
          _screen(100 + i * 10.0, top - 4 + (i.isEven ? 2 : -2)),
      ]);
      final stroke = items().single as Stroke;
      for (final p in stroke.points) {
        expect(p.y, closeTo(top - width / 2, 1e-6));
      }
      expect(stroke.points.first.x, closeTo(100, 0.5));
      expect(stroke.points.last.x, closeTo(200, 0.5));
    });

    testWidgets('gövdenin içinden, kenara yakın başlayan da yaslanır', (
      t,
    ) async {
      await pump(t);
      await place(t, InstrumentKind.ruler);
      final before = poseOf(InstrumentKind.ruler);
      await drag(t, [_screen(100, top + 3), _screen(150, top + 5)]);
      expect(poseOf(InstrumentKind.ruler), before, reason: 'cetvel kımıldamaz');
      final stroke = items().single as Stroke;
      final width = container.read(toolProvider).strokeWidth;
      expect(stroke.points.last.y, closeTo(top - width / 2, 1e-6));
    });

    testWidgets('uzaktan başlayan çizgi yaslanmaz', (t) async {
      await pump(t);
      await place(t, InstrumentKind.ruler);
      await drag(t, [_screen(100, 40), _screen(150, 60)]);
      final stroke = items().single as Stroke;
      expect(stroke.points.last.y, closeTo(60, 0.5));
    });

    testWidgets('iletkinin yayı boyunca çizgi yarıçapta kalır', (t) async {
      await pump(t);
      await place(t, InstrumentKind.protractor, y: 300);
      const r = protractorRadius;
      final width = container.read(toolProvider).strokeWidth;
      await drag(t, [
        for (var a = -120.0; a <= -60; a += 5)
          _screen(
            150 + (r + 3) * math.cos(a * math.pi / 180),
            300 + (r + 3) * math.sin(a * math.pi / 180),
          ),
      ]);
      final stroke = items().single as Stroke;
      for (final p in stroke.points) {
        final d = math.sqrt(math.pow(p.x - 150, 2) + math.pow(p.y - 300, 2));
        expect(d, closeTo(r + width / 2, 1e-6));
      }
    });
  });

  group('taşıma ve döndürme', () {
    testWidgets('gövdenin ortasından sürüklemek taşır, çizmez', (t) async {
      await pump(t);
      await place(t, InstrumentKind.ruler);
      await drag(t, [_screen(150, 200), _screen(160, 210), _screen(170, 220)]);
      final pose = poseOf(InstrumentKind.ruler)!;
      expect(pose.x, closeTo(170, 0.01));
      expect(pose.y, closeTo(220, 0.01));
      expect(items(), isEmpty);
    });

    testWidgets('döndürme tutamağı döndürür, 15° katlarına oturur', (t) async {
      await pump(t);
      await place(t, InstrumentKind.ruler, x: 250);
      // Tutamak sağ ucun 26 px dışında.
      final handle = _screen(250 + rulerLength / 2, 200) + const Offset(26, 0);
      // Merkez etrafında ~44° döndür.
      final c = _screen(250, 200);
      final r = (handle - c).distance;
      const a = 44 * math.pi / 180;
      await drag(t, [
        handle,
        c + Offset(math.cos(a / 2), math.sin(a / 2)) * r,
        c + Offset(math.cos(a), math.sin(a)) * r,
      ]);
      expect(poseOf(InstrumentKind.ruler)!.angle, closeTo(math.pi / 4, 1e-9));
      expect(items(), isEmpty);
    });

    testWidgets('kapat düğmesi aracı kaldırır', (t) async {
      await pump(t);
      await place(t, InstrumentKind.ruler, x: 250);
      const w = rulerLength / 2, h = rulerHeight / 2;
      final close = _screen(250 - w, 200 + h) + const Offset(20, -20);
      expect(close.dx, greaterThan(0), reason: 'kapat düğmesi ekranda');
      await t.tapAt(close);
      await t.pump();
      expect(poseOf(InstrumentKind.ruler), isNull);
      expect(items(), isEmpty);
    });

    testWidgets('aracın dışı alttaki katmana kalır', (t) async {
      await pump(t);
      await place(t, InstrumentKind.setSquare);
      container.read(toolProvider.notifier).select(Tool.pen);
      await drag(t, [_screen(20, 20), _screen(40, 30)]);
      expect(items(), hasLength(1));
    });
  });

  group('pergel', () {
    testWidgets('tutamağı çevirmek iğnenin çevresinde yay çizer', (t) async {
      await pump(t);
      const r = 3 * ptPerCm;
      await place(t, InstrumentKind.compass, x: 150, y: 380, radius: r);
      final needle = _screen(150, 380);
      final knob0 = compassKnob(poseOf(InstrumentKind.compass)!);
      final k = _screen(knob0.x, knob0.y);
      final arm = (k - needle).distance;
      final a0 = (k - needle).direction;
      await drag(t, [
        for (var i = 0; i <= 12; i++)
          needle +
              Offset(
                    math.cos(a0 + i * math.pi / 12),
                    math.sin(a0 + i * math.pi / 12),
                  ) *
                  arm,
      ]);
      final stroke = items().single as Stroke;
      for (final p in stroke.points) {
        final d = math.sqrt(math.pow(p.x - 150, 2) + math.pow(p.y - 380, 2));
        expect(d, closeTo(r, 1e-6));
      }
      // Yarım tur: kalem ucu başladığı yerin karşısında.
      expect(stroke.points.first.x, closeTo(150 + r, 1e-6));
      expect(stroke.points.last.x, closeTo(150 - r, 0.5));
      expect(
        stroke.color,
        container.read(toolProvider).strokeColorFor(Tool.pen),
      );
      expect(poseOf(InstrumentKind.compass)!.angle, closeTo(math.pi, 1e-6));
    });

    testWidgets('kalem ucunu çekmek açıklığı milimetreyle değiştirir', (
      t,
    ) async {
      await pump(t);
      await place(
        t,
        InstrumentKind.compass,
        x: 100,
        y: 250,
        radius: 2 * ptPerCm,
      );
      final pencil = _screen(100 + 2 * ptPerCm, 250);
      await drag(t, [pencil, _screen(100 + 3.52 * ptPerCm, 250)]);
      final pose = poseOf(InstrumentKind.compass)!;
      expect(pose.radius, closeTo(3.5 * ptPerCm, 1e-9));
      expect(pose.angle, 0);
      expect(items(), isEmpty);
    });

    testWidgets('iğneden sürüklemek pergeli taşır', (t) async {
      await pump(t);
      await place(t, InstrumentKind.compass, x: 100, y: 250);
      await drag(t, [_screen(100, 250), _screen(110, 255), _screen(120, 260)]);
      final pose = poseOf(InstrumentKind.compass)!;
      expect(pose.x, closeTo(120, 0.01));
      expect(pose.y, closeTo(260, 0.01));
      expect(items(), isEmpty);
    });
  });

  group('şekil paneli', () {
    testWidgets('koordinat düzlemi şekli ve ölçme araçları', (t) async {
      await pump(t, panel: true);
      container.read(toolProvider.notifier).select(Tool.shape);
      await t.pump();
      expect(find.text('Ölçme araçları'), findsOneWidget);
      expect(find.bySemanticsLabel('Koordinat düzlemi'), findsOneWidget);

      // Cetvel açılır, ekranın ortasındaki sayfaya konur; kalem seçilir.
      await t.tap(find.byKey(const ValueKey('instrument-toggle-ruler')));
      await t.pump();
      await t.pump();
      final pose = poseOf(InstrumentKind.ruler)!;
      expect(pose.page, 0);
      expect(container.read(toolProvider).tool, Tool.pen);

      // Pergel aracı değiştirmez; ikinci dokunuş kapatır.
      container.read(toolProvider.notifier).select(Tool.shape);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('instrument-toggle-compass')));
      await t.pump();
      expect(container.read(toolProvider).tool, Tool.shape);
      expect(poseOf(InstrumentKind.compass), isNotNull);
      await t.tap(find.byKey(const ValueKey('instrument-toggle-compass')));
      await t.pump();
      expect(poseOf(InstrumentKind.compass), isNull);
      expect(poseOf(InstrumentKind.ruler), isNotNull);
    });

    testWidgets('koordinat düzlemi sürükleyerek çizilir', (t) async {
      await pump(t);
      container.read(toolProvider.notifier)
        ..setShapeKind(ShapeKind.coordinate)
        ..select(Tool.shape);
      await t.pump();
      await drag(t, [_screen(50, 50), _screen(150, 100), _screen(250, 150)]);
      final shape = items().single as Shape;
      expect(shape.kind, ShapeKind.coordinate);
      expect((shape.x1, shape.y1, shape.x2, shape.y2), (50, 50, 250, 150));
    });
  });
}
