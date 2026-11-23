import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/image_editor.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken/features/ink/ink_session.dart';
import 'package:inken/features/ink/ink_toolbar.dart';
import 'package:inken/features/ink/item_clipboard.dart';
import 'package:inken/features/ink/text_font_provider.dart';
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// İki sayfalı sahte görüntüleyici yerleşimi: 200×300 pt sayfalar, ölçek 2.
/// Sayfa 0 ekranda (50,20)–(450,620), sayfa 1 hemen altında.
class _FakeGeometry extends ChangeNotifier implements PageGeometry {
  double scale = 2;
  Offset origin = const Offset(50, 20);

  @override
  bool get isReady => true;

  @override
  List<PageViewport> get visiblePages => [
    for (var i = 0; i < 2; i++)
      PageViewport(
        index: i,
        rect:
            origin.translate(0, i * (300 * scale + 10)) &
            Size(200 * scale, 300 * scale),
        scale: scale,
      ),
  ];

  @override
  PageViewport? pageAt(Offset local) {
    for (final v in visiblePages) {
      if (v.rect.contains(local)) return v;
    }
    return null;
  }

  @override
  PageViewport? viewportOf(int index) => visiblePages[index];

  void zoomTo(double s) {
    scale = s;
    notifyListeners();
  }
}

final _textFont = InkenTextFont(
  File('assets/fonts/DejaVuSans.ttf').readAsBytesSync(),
);

void main() {
  late _FakeGeometry geometry;
  late InkSession session;
  late int viewerPans;
  late ProviderContainer container;
  late SettingsStore settings;

  Future<void> pump(
    WidgetTester t, {
    bool toolbar = false,
    Map<String, Object?>? savedSettings,
  }) async {
    settings = SettingsStore.memory(savedSettings);
    geometry = _FakeGeometry();
    session = InkSession(
      InkenDocument.forPdf([
        (width: 200, height: 300),
        (width: 200, height: 300),
      ]),
    );
    viewerPans = 0;
    container = ProviderContainer(
      overrides: [
        textFontProvider.overrideWithValue(_textFont),
        settingsStoreProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(session.dispose);
    final layer = InkLayer(
      geometry: geometry,
      session: session,
      // Görüntüleyici taklidi: kaydırma / yakınlaştırma hareketini sayar.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) => viewerPans++,
        child: const ColoredBox(color: Colors.white),
      ),
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: toolbar
              ? Scaffold(
                  body: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(child: layer),
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Center(child: ToolDock(session: session)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : layer,
        ),
      ),
    );
  }

  Future<void> drag(
    WidgetTester t,
    Offset from,
    Offset to, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
    int buttons = kPrimaryButton,
  }) async {
    final g = await t.startGesture(from, kind: kind, buttons: buttons);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(
        Offset.lerp(from, to, i / 10)!,
        timeStamp: Duration(milliseconds: 16 * i),
      );
    }
    await g.up(timeStamp: const Duration(milliseconds: 200));
    await t.pump();
  }

  List<InkItem> items(int page) => session.document.pages[page].items;
  ToolNotifier tools() => container.read(toolProvider.notifier);

  testWidgets('fareyle sürükleme doğru sayfa koordinatlarında çizgi çizer', (
    t,
  ) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(200, 150));
    expect(items(0).length, 1);
    expect(viewerPans, 0);
    final s = items(0).single as Stroke;
    expect(s.tool, InkTool.pen);
    expect(s.color, penColors[0]);
    expect(s.width, penWidths[1]);
    // (ekran - sayfa köşesi) / ölçek
    expect(s.points.first.x, closeTo(25, 1e-6));
    expect(s.points.first.y, closeTo(40, 1e-6));
    expect(s.points.last.x, closeTo(75, 1e-6));
    expect(s.points.last.y, closeTo(65, 1e-6));
    expect(session.canUndo, isTrue);
  });

  testWidgets('çizgi başladığı sayfaya aittir', (t) async {
    await pump(t);
    // Sayfa 1 ekranda y=630'dan başlar; test yüzeyi 800×600 olduğundan
    // yerleşimi yukarı kaydır.
    geometry.origin = const Offset(50, -400);
    geometry.zoomTo(2);
    await drag(t, const Offset(100, 300), const Offset(150, 320));
    expect(items(0), isEmpty);
    expect(items(1).length, 1);
    expect((items(1).single as Stroke).points.first.y, closeTo(45, 1e-6));
  });

  testWidgets('gezinme aracında çizilmez, hareket görüntüleyiciye gider', (
    t,
  ) async {
    await pump(t);
    tools().select(Tool.hand);
    await t.pump();
    await drag(t, const Offset(100, 100), const Offset(200, 250));
    expect(items(0), isEmpty);
    expect(viewerPans, 1);
  });

  testWidgets('sayfa dışında başlayan hareket görüntüleyiciye gider', (
    t,
  ) async {
    await pump(t);
    await drag(t, const Offset(10, 100), const Offset(30, 300));
    expect(items(0), isEmpty);
    expect(viewerPans, 1);
  });

  testWidgets('otomatik mod: kalem görülene kadar parmak çizer', (t) async {
    await pump(t);
    await drag(
      t,
      const Offset(100, 100),
      const Offset(200, 150),
      kind: PointerDeviceKind.touch,
    );
    expect(items(0).length, 1);
    expect(viewerPans, 0);
  });

  testWidgets('otomatik mod: kalem görüldükten sonra parmak kaydırır', (
    t,
  ) async {
    await pump(t);
    await drag(
      t,
      const Offset(100, 100),
      const Offset(200, 150),
      kind: PointerDeviceKind.stylus,
    );
    expect(items(0).length, 1);
    expect(container.read(toolProvider).stylusSeen, isTrue);
    await drag(
      t,
      const Offset(100, 200),
      const Offset(200, 400),
      kind: PointerDeviceKind.touch,
    );
    expect(items(0).length, 1, reason: 'parmak çizmedi');
    expect(viewerPans, 1);
  });

  testWidgets('dokunma modunda iki parmak çizmez, görüntüleyiciye kalır', (
    t,
  ) async {
    await pump(t);
    tools().setInputMode(InputMode.touch);
    final a = await t.startGesture(
      const Offset(150, 200),
      kind: PointerDeviceKind.touch,
    );
    final b = await t.startGesture(
      const Offset(300, 200),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 1; i <= 10; i++) {
      await a.moveBy(const Offset(-8, 0));
      await b.moveBy(const Offset(8, 0));
    }
    await a.up();
    await b.up();
    await t.pump();
    expect(items(0), isEmpty);
    expect(session.isDrawing, isFalse);
    expect(viewerPans, 1);
  });

  testWidgets('parmakla tek dokunuş nokta koyar', (t) async {
    await pump(t);
    final g = await t.startGesture(
      const Offset(150, 220),
      kind: PointerDeviceKind.touch,
    );
    await g.up();
    await t.pump();
    final s = items(0).single as Stroke;
    expect(s.points.length, 1);
    expect(s.points.single.x, closeTo(50, 1e-6));
  });

  testWidgets('çizim sürerken gelen ikinci dokunuş (avuç) yutulur', (t) async {
    await pump(t);
    final pen = await t.startGesture(
      const Offset(100, 100),
      kind: PointerDeviceKind.stylus,
    );
    await pen.moveTo(const Offset(140, 120));
    final palm = await t.startGesture(
      const Offset(300, 400),
      kind: PointerDeviceKind.touch,
    );
    await palm.moveBy(const Offset(40, 40));
    await pen.moveTo(const Offset(180, 140));
    await palm.up();
    await pen.up();
    await t.pump();
    expect(items(0).length, 1);
    expect(viewerPans, 0);
    expect((items(0).single as Stroke).points.last.x, closeTo(65, 1e-6));
  });

  testWidgets('fosforlu kalem yarı saydam ve sabit kalınlıkta çizer', (
    t,
  ) async {
    await pump(t);
    tools().select(Tool.highlighter);
    await t.pump();
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    final s = items(0).single as Stroke;
    expect(s.tool, InkTool.highlighter);
    expect(s.color >> 24, highlighterAlpha);
    expect(s.width, highlighterWidths[1]);
    expect(s.points.every((p) => p.p == 0.5), isTrue);
  });

  testWidgets('silgi çizgiyi siler; geri al ve yinele çalışır', (t) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    await drag(t, const Offset(100, 300), const Offset(300, 300));
    expect(items(0).length, 2);
    final keptId = items(0)[1].id;

    tools().select(Tool.eraser);
    await t.pump();
    // İlk çizgiyi dikine kes.
    await drag(t, const Offset(200, 60), const Offset(200, 140));
    expect(items(0).map((i) => i.id), [keptId]);

    session.undo();
    expect(items(0).length, 2);
    expect(items(0)[1].id, keptId, reason: 'silinen eski sırasına döndü');
    session.redo();
    expect(items(0).length, 1);
    session.undo();
    session.undo();
    expect(items(0).length, 1);
    session.undo();
    expect(items(0), isEmpty);
    expect(session.canUndo, isFalse);
  });

  testWidgets('piksel silgisi çizgiyi böler; tek adımda geri alınır', (
    t,
  ) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    final original = items(0).single;

    tools()
      ..select(Tool.eraser)
      ..setEraserMode(EraserMode.pixel);
    await t.pump();
    // Ortadan dikine geç: iki parça kalır.
    await drag(t, const Offset(200, 60), const Offset(200, 140));
    final pieces = items(0).cast<Stroke>();
    expect(pieces, hasLength(2));
    expect(pieces.map((s) => s.id), isNot(contains(original.id)));
    expect(pieces.every((s) => s.color == (original as Stroke).color), isTrue);
    // Sayfa uzayında kesim (ölçek 2): x=75 civarı, silgi yarıçapı 12 px.
    expect(pieces[0].points.last.x, lessThan(75));
    expect(pieces[1].points.first.x, greaterThan(75));

    session.undo();
    expect(items(0), [original]);
    session.redo();
    expect(items(0), hasLength(2));
  });

  testWidgets('silgi boyutu dokunma alanını değiştirir', (t) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    tools()
      ..select(Tool.eraser)
      ..setEraserSize(0); // 6 px
    await t.pump();
    // Çizginin 15 px uzağından geçer: küçük silgi değmez.
    await drag(t, const Offset(80, 115), const Offset(320, 115));
    expect(items(0), hasLength(1));
    tools().setEraserSize(2); // 24 px
    await t.pump();
    await drag(t, const Offset(80, 115), const Offset(320, 115));
    expect(items(0), isEmpty);
  });

  testWidgets('geçici kalem modele girmez ve birkaç saniyede kaybolur', (
    t,
  ) async {
    await pump(t);
    tools().select(Tool.laser);
    await t.pump();
    await drag(t, const Offset(100, 100), const Offset(300, 200));
    expect(items(0), isEmpty);
    expect(session.canUndo, isFalse);
    // Ticker çalışır; süre dolunca durur (bekleyen kare kalmaz).
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.runAsync(
      () => Future<void>.delayed(
        laserHold + laserFade + const Duration(milliseconds: 100),
      ),
    );
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 16));
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('silgi boşa giderse geri alma adımı oluşmaz', (t) async {
    await pump(t);
    tools().select(Tool.eraser);
    await t.pump();
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    expect(session.canUndo, isFalse);
  });

  testWidgets('kalemin yan düğmesi silgi gibi davranır', (t) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    await drag(
      t,
      const Offset(200, 60),
      const Offset(200, 140),
      kind: PointerDeviceKind.stylus,
      buttons: kPrimaryButton | kPrimaryStylusButton,
    );
    expect(items(0), isEmpty);
  });

  testWidgets('kalem düğmesi temas sırasında basılıp bırakılır', (t) async {
    await pump(t);
    // Silinecek yatay çizgi (y = 100).
    await drag(t, const Offset(100, 100), const Offset(300, 100));
    expect(items(0), hasLength(1));

    final pen = TestPointer(7, PointerDeviceKind.stylus, null, kPrimaryButton);
    Future<void> send(PointerEvent e) async {
      await t.sendEventToBinding(e);
      await t.pump();
    }

    const button = kPrimaryButton | kPrimaryStylusButton;
    // 1) Düğmesiz yaz: çizgi başlar (y 180 → 150).
    await send(pen.down(const Offset(200, 180)));
    for (final y in [170.0, 160.0, 150.0]) {
      await send(pen.move(Offset(200, y)));
    }
    // 2) Düğmeye bas: o ana kadar yazılan kalır, silgiye geçer; çizginin
    //    üzerinden geçince siler.
    for (final y in [130.0, 110.0, 95.0, 80.0]) {
      await send(pen.move(Offset(200, y), buttons: button));
    }
    // 3) Düğmeyi bırak: silme durur, kalem kalkana kadar yazmaz.
    for (final y in [70.0, 60.0, 50.0]) {
      await send(pen.move(Offset(200, y)));
    }
    await send(pen.up());

    final left = items(0);
    expect(left, hasLength(1), reason: 'eski çizgi silindi, yeni kısım kaldı');
    final kept = left.single as Stroke;
    // Sahte görüntüleyici: sayfa y = (ekran y − 20) / 2.
    double page(double y) => (y - 20) / 2;
    expect(kept.points.first.y, closeTo(page(180), 1e-6));
    expect(
      kept.points.map((p) => p.y).reduce((a, b) => a < b ? a : b),
      greaterThanOrEqualTo(page(150) - 1e-6),
      reason: 'düğmeden sonrası çizilmedi',
    );
    expect(tools().state.tool, Tool.pen, reason: 'araç değişmedi');

    // Düğme baştan basılıysa temas baştan sona siler.
    await send(pen.down(const Offset(150, 190), buttons: button));
    await send(pen.move(const Offset(250, 190), buttons: button));
    await send(pen.move(const Offset(250, 170), buttons: button));
    await send(pen.up());
    expect(items(0), isEmpty);
  });

  group('seçim eksikleri', () {
    const img = ImageItem(
      id: 'g',
      imageId: 'x',
      x: 20,
      y: 20,
      width: 40,
      height: 20,
    );
    const rect = Shape(
      id: 'r',
      kind: ShapeKind.rectangle,
      color: 0xFF1A1A1A,
      width: 2,
      x1: 20,
      y1: 60,
      x2: 80,
      y2: 90,
    );

    testWidgets('kenar tutamağı tek eksende boyutlandırır', (t) async {
      await pump(t);
      tools().select(Tool.select);
      session.insertImage(0, img);
      await t.pump();
      // Sağ kenarın ortası: kutu (90,60)–(170,100), 4 px pay.
      await drag(t, const Offset(174, 80), const Offset(214, 80));
      final g = items(0).single as ImageItem;
      expect(g.x, closeTo(20, 1e-6));
      // Tutulan nokta (kutudan 2 pt dışarıda, x = 62) imleci izler:
      // 20 pt sağa → ölçek (82 − 20) / (62 − 20).
      expect(g.width, closeTo(40 * 62 / 42, 1e-6));
      expect(g.height, closeTo(20, 1e-6), reason: 'yükseklik değişmez');
    });

    testWidgets('seçimde metin varsa kenar tutamağı yok', (t) async {
      await pump(t);
      tools().select(Tool.select);
      session.pasteItems(0, const [
        TextItem(
          id: 't',
          text: 'a',
          color: 0xFF000000,
          fontSize: 20,
          x: 20,
          y: 20,
          width: 40,
          height: 20,
        ),
      ]);
      await t.pump();
      expect(session.selectionCanStretch, isFalse);
      final before = items(0).single;
      // Sağ kenar ortasından sürüklemek boyutlandırmaz (kutunun içinden
      // başladığı için taşır).
      await drag(t, const Offset(174, 80), const Offset(214, 80));
      final after = items(0).single as TextItem;
      expect(after.fontSize, (before as TextItem).fontSize);
    });

    testWidgets('seçim çubuğu: renk, kopyala, sil; çizim başlatmaz', (t) async {
      await pump(t);
      tools().select(Tool.select);
      session.pasteItems(0, const [rect]);
      await t.pump();
      final bar = find.byKey(const ValueKey('selection-bar'));
      expect(bar, findsOneWidget);
      final undoSteps = session.canUndo;

      await t.tap(find.byKey(const ValueKey('selection-color-2')));
      await t.pump();
      expect((items(0).single as Shape).color, penColors[2]);
      expect(session.selection, hasLength(1), reason: 'seçim kalır');

      await t.tap(find.byKey(const ValueKey('selection-copy')));
      await t.pump();
      final clip = container.read(itemClipboardProvider)!;
      expect(clip.items.single.id, items(0).single.id);
      pasteClip(session, clip, 0);
      await t.pump();
      expect(items(0), hasLength(2));
      final copy = items(0).last as Shape;
      expect(copy.x1, closeTo(rect.x1 + pasteOffset, 1e-6));
      expect(session.selection, {copy.id}, reason: 'yapıştırılan seçili');

      await t.tap(find.byKey(const ValueKey('selection-delete')));
      await t.pump();
      expect(items(0), hasLength(1));
      expect(undoSteps, isTrue);
    });

    testWidgets('görselde renk düğmesi yok', (t) async {
      await pump(t);
      tools().select(Tool.select);
      session.insertImage(0, img);
      await t.pump();
      expect(find.byKey(const ValueKey('selection-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('selection-color-0')), findsNothing);
    });

    testWidgets('tümünü seç', (t) async {
      await pump(t);
      session.pasteItems(0, const [rect, img]);
      session.clearSelection();
      session.selectAll(0);
      expect(session.selection, hasLength(2));
      session.selectAll(1);
      expect(session.hasSelection, isFalse, reason: 'boş sayfa');
    });

    testWidgets('seçim başka sayfaya sürüklenir; tek adımda geri alınır', (
      t,
    ) async {
      await pump(t);
      geometry.zoomTo(1); // sayfa 0: y 20–320, sayfa 1: y 330–630
      await t.pump();
      tools().select(Tool.select);
      session.insertImage(
        0,
        img.copyWith(x: 50, y: 100),
      ); // ekranda (100,120)–(140,140)
      await t.pump();
      await drag(t, const Offset(120, 130), const Offset(120, 440));
      expect(items(0), isEmpty);
      final moved = items(1).single as ImageItem;
      expect(moved.x, closeTo(50, 1e-6));
      expect(moved.y, closeTo(100, 1e-6));
      expect(session.selectionPage, 1);
      session.undo();
      expect(items(0).single, isA<ImageItem>());
      expect(items(1), isEmpty);
    });
  });

  testWidgets('yakınlaştırma modeli değiştirmez', (t) async {
    await pump(t);
    await drag(t, const Offset(100, 100), const Offset(200, 150));
    final before = session.document;
    geometry.zoomTo(4);
    await t.pump();
    expect(session.document, before);
    // Yeni ölçekte aynı ekran hareketi yarı uzunlukta bir çizgi verir.
    await drag(t, const Offset(100, 100), const Offset(200, 150));
    final s = items(0)[1] as Stroke;
    expect(s.points.last.x - s.points.first.x, closeTo(25, 1e-6));
  });

  testWidgets('araç çubuğu: araç seçimi ve geri al düğmesi', (t) async {
    // Araç kutusu geniş: dar ekranda kaydırılır, burada hepsi görünsün.
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pump(t, toolbar: true);
    IconButton button(String key) =>
        t.widget<IconButton>(find.byKey(ValueKey(key)));
    expect(button('undo').onPressed, isNull);

    await drag(t, const Offset(100, 150), const Offset(200, 200));
    await t.pump();
    expect(items(0).length, 1);
    expect(button('undo').onPressed, isNotNull);
    expect(button('redo').onPressed, isNull);

    await t.tap(find.byKey(const ValueKey('undo')));
    await t.pump();
    expect(items(0), isEmpty);
    expect(button('redo').onPressed, isNotNull);

    await t.tap(find.byKey(const ValueKey('tool-highlighter')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.highlighter);
    expect(find.byKey(const ValueKey('color-2')), findsNothing);

    // Seçili araca ikinci dokunuş seçenek panelini açar.
    await t.tap(find.byKey(const ValueKey('tool-highlighter')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('color-2')));
    await t.tap(find.byKey(const ValueKey('width-2')));
    await t.pumpAndSettle();
    final state = container.read(toolProvider);
    expect(state.highlighterColor, highlighterColors[2]);
    expect(state.highlighterWidth, 2);
    expect(state.penColor, penColors[0], reason: 'kalemin rengi ayrı tutulur');
    expect(
      find.byKey(const ValueKey('color-2')),
      findsOneWidget,
      reason: 'seçim yapmak paneli kapatmaz',
    );
    expect(find.byTooltip('Fosforlu (H)'), findsOneWidget);

    // Sayfaya dokunmak (çizmeye başlamak) paneli kapatır.
    await t.tapAt(const Offset(300, 400));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('color-2')), findsNothing);

    // Araç seçili değilken ilk dokunuş yalnızca seçer, ikincisi paneli açar.
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('options-pen')), findsNothing);
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.pen);
    expect(find.byKey(const ValueKey('options-pen')), findsOneWidget);
    expect(find.byKey(const ValueKey('width-3')), findsOneWidget);
    await t.tapAt(const Offset(300, 400));
    await t.pumpAndSettle();

    // Hızlı renk yuvaları seçili mürekkep aracının: kalemdeyken kalemin
    // renkleri; fosforluya geçince fosforlununki. Kutu genişliği değişmez.
    final dock = find.byKey(const ValueKey('tool-dock'));
    final width = t.getSize(dock).width;
    expect(find.byKey(const ValueKey('quick-pen-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-highlighter-1')), findsNothing);
    await t.tap(find.byKey(const ValueKey('tool-highlighter')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-pen-2')), findsNothing);
    expect(t.getSize(dock).width, width);
    await t.tap(find.byKey(const ValueKey('quick-highlighter-1')));
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.highlighter);
    expect(container.read(toolProvider).highlighterColor, highlighterColors[1]);
    // Geçici kalem de aynı yuvaları kullanır.
    await t.tap(find.byKey(const ValueKey('tool-laser')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-laser-2')), findsOneWidget);
    expect(t.getSize(dock).width, width);
    await t.tap(find.byKey(const ValueKey('tool-highlighter')));
    await t.pumpAndSettle();
    // Başka araçta son seçilen mürekkep aracının renkleri kalır.
    await t.tap(find.byKey(const ValueKey('tool-shape')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-highlighter-2')), findsOneWidget);
    expect(t.getSize(dock).width, width);
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('quick-pen-2')));
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.pen);
    expect(container.read(toolProvider).penColor, penColors[2]);

    // Silgi paneli: tür ve boyut.
    await t.tap(find.byKey(const ValueKey('tool-eraser')));
    await t.tap(find.byKey(const ValueKey('tool-eraser')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('seg-EraserMode.pixel')));
    await t.tap(find.byKey(const ValueKey('eraser-size-2')));
    await t.pump();
    final s2 = container.read(toolProvider);
    expect(s2.tool, Tool.eraser);
    expect(s2.eraserMode, EraserMode.pixel);
    expect(s2.eraserSize, 2);
    expect(container.read(toolOptionsProvider), Tool.eraser);

    // Geçici kalemin rengi.
    await t.tap(find.byKey(const ValueKey('tool-laser')));
    await t.tap(find.byKey(const ValueKey('tool-laser')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('laser-color-2')));
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.laser);
    expect(container.read(toolProvider).laserColor, laserColors[2]);

    // Tutamağa dokun → menüden "Solda": araçlar ve panel çalışmaya devam
    // eder.
    await t.tap(find.byKey(const ValueKey('dock-move')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('dock-left')));
    await t.pumpAndSettle();
    expect(container.read(toolDockProvider), DockEdge.left);
    expect(container.read(toolOptionsProvider), isNull);
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('options-pen')), findsOneWidget);
  });

  group('seçim aracı', () {
    // Sayfa 0: ekran = (50, 20) + 2 × sayfa.
    testWidgets(
      'dikdörtgenle seçip sürükleyerek taşır; tek adımda geri alınır',
      (t) async {
        await pump(t);
        await drag(t, const Offset(100, 100), const Offset(140, 120));
        await drag(t, const Offset(300, 400), const Offset(340, 420));
        final a = items(0)[0] as Stroke, b = items(0)[1];

        tools().select(Tool.select);
        await t.pump();
        await drag(t, const Offset(80, 80), const Offset(200, 200));
        expect(session.selection, {a.id});
        expect(viewerPans, 0);

        // Seçimin içinden sürükle: 100 px = 50 pt.
        await drag(t, const Offset(120, 110), const Offset(220, 210));
        final moved = items(0)[0] as Stroke;
        expect(moved.id, a.id);
        expect(moved.points.first.x, closeTo(a.points.first.x + 50, 1e-6));
        expect(moved.points.first.y, closeTo(a.points.first.y + 50, 1e-6));
        expect(items(0)[1], b);
        expect(session.selection, {
          a.id,
        }, reason: 'taşıdıktan sonra seçili kalır');

        session.undo();
        expect(items(0)[0], a);
        session.redo();
        expect(items(0)[0], moved);
      },
    );

    testWidgets('öğeye dokunup doğrudan sürükler; boş yere dokunmak bırakır', (
      t,
    ) async {
      await pump(t);
      await drag(t, const Offset(100, 100), const Offset(140, 100));
      final a = items(0).single as Stroke;
      tools().select(Tool.select);
      await t.pump();

      await drag(t, const Offset(120, 100), const Offset(120, 140));
      expect(session.selection, {a.id});
      expect(
        (items(0).single as Stroke).points.first.y,
        closeTo(a.points.first.y + 20, 1e-6),
      );

      await drag(t, const Offset(400, 500), const Offset(400, 500));
      expect(session.hasSelection, isFalse);
    });

    testWidgets('köşe tutamağından orantılı büyütür; tek adımda geri alınır', (
      t,
    ) async {
      await pump(t);
      tools().setPenWidth(2); // 3 pt: aşağıdaki sınırlar buna göre
      await drag(t, const Offset(100, 100), const Offset(140, 120));
      final a = items(0).single as Stroke;
      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(80, 80), const Offset(200, 200));
      // Sınır (kalınlık dahil) sayfada (23.5, 38.5)–(46.5, 51.5); ekranda
      // 4 px payla sağ alt köşe (147, 127). Sol üst sabit, 2 kat büyüt.
      await drag(t, const Offset(147, 127), const Offset(197, 157));
      final s = items(0).single as Stroke;
      expect(s.width, closeTo(a.width * 2, 1e-6));
      expect(s.points.first.x, closeTo(23.5 + (25 - 23.5) * 2, 1e-6));
      expect(s.points.last.x, closeTo(23.5 + (45 - 23.5) * 2, 1e-6));
      expect(s.points.last.y, closeTo(38.5 + (50 - 38.5) * 2, 1e-6));
      expect(session.selection, {a.id});

      session.undo();
      expect(items(0).single, a);
    });

    testWidgets('küçültme sınırı ve sayfa kenarı aşılmaz', (t) async {
      await pump(t);
      tools().setPenWidth(2); // 3 pt: aşağıdaki sınırlar buna göre
      await drag(t, const Offset(100, 100), const Offset(140, 120));
      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(80, 80), const Offset(200, 200));
      // Sağ alt köşeyi sol üst köşenin ötesine çek: en küçük boyutta kalır.
      await drag(t, const Offset(147, 127), const Offset(60, 60));
      var b = selectionBounds(session.document.pages[0], session.selection)!;
      expect(b.right - b.left, closeTo(InkSession.minSelectionSize, 1e-6));
      session.undo();
      // Sayfanın çok dışına çek: sayfa genişliğinde (200 pt) durur.
      await drag(t, const Offset(147, 127), const Offset(790, 590));
      b = selectionBounds(session.document.pages[0], session.selection)!;
      expect(b.right, lessThanOrEqualTo(200 + 1e-6));
      expect(b.bottom, lessThanOrEqualTo(300 + 1e-6));
      expect(b.left, closeTo(23.5, 1e-6));
    });

    testWidgets('seçileni siler; geri al geri getirir', (t) async {
      await pump(t);
      await drag(t, const Offset(100, 100), const Offset(140, 100));
      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(60, 60), const Offset(200, 200));
      expect(session.hasSelection, isTrue);
      session.deleteSelection();
      expect(items(0), isEmpty);
      expect(session.hasSelection, isFalse);
      session.undo();
      expect(items(0).length, 1);
    });

    testWidgets('seçim sayfanın dışına taşınamaz', (t) async {
      await pump(t);
      await drag(t, const Offset(100, 100), const Offset(140, 100));
      final width = (items(0).single as Stroke).width;
      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(120, 100), const Offset(-300, 100));
      final s = items(0).single as Stroke;
      expect(s.points.first.x, closeTo(width / 2, 1e-6));
    });

    testWidgets('başka araca geçince ve geri alınca seçim temizlenir', (
      t,
    ) async {
      await pump(t);
      await drag(t, const Offset(100, 100), const Offset(140, 100));
      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(60, 60), const Offset(200, 200));
      expect(session.hasSelection, isTrue);
      tools().select(Tool.pen);
      await t.pump();
      expect(session.hasSelection, isFalse);

      tools().select(Tool.select);
      await t.pump();
      await drag(t, const Offset(60, 60), const Offset(200, 200));
      session.undo(); // çizgi geri alınır
      expect(session.hasSelection, isFalse);
    });
  });

  group('şekil aracı', () {
    // Sayfa 0: ekran = (50, 20) + 2 × sayfa.
    testWidgets('sürükleyerek dikdörtgen çizer; tek adımda geri alınır', (
      t,
    ) async {
      await pump(t);
      tools().select(Tool.shape);
      await t.pump();
      await drag(t, const Offset(100, 100), const Offset(200, 160));
      final s = items(0).single as Shape;
      expect(s.kind, ShapeKind.rectangle);
      expect((s.x1, s.y1, s.x2, s.y2), (25.0, 40.0, 75.0, 70.0));
      expect(s.color, penColors[0]);
      expect(s.width, penWidths[1]);
      expect(s.id, isNotEmpty);
      session.undo();
      expect(items(0), isEmpty);
    });

    testWidgets('tür, renk ve kalınlık şekle ait; kalemi etkilemez', (t) async {
      await pump(t);
      tools()
        ..setShapeKind(ShapeKind.arrow)
        ..setShapeColor(penColors[2])
        ..setShapeWidth(3);
      await t.pump();
      expect(container.read(toolProvider).tool, Tool.shape);
      await drag(t, const Offset(100, 100), const Offset(300, 250));
      final s = items(0).single as Shape;
      expect(s.kind, ShapeKind.arrow);
      expect(s.color, penColors[2]);
      expect(s.width, penWidths[3]);
      expect(container.read(toolProvider).penColor, penColors[0]);
    });

    testWidgets('yataya yakın çizgi yataya oturur', (t) async {
      await pump(t);
      tools().setShapeKind(ShapeKind.line);
      await t.pump();
      await drag(t, const Offset(100, 100), const Offset(300, 106));
      final s = items(0).single as Shape;
      expect(s.y2, s.y1);
    });

    testWidgets('Shift ile dikdörtgen kare olur', (t) async {
      await pump(t);
      tools().setShapeKind(ShapeKind.rectangle);
      await t.pump();
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await drag(t, const Offset(100, 100), const Offset(200, 140));
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      final s = items(0).single as Shape;
      expect((s.x2 - s.x1).abs(), (s.y2 - s.y1).abs());
      expect(s.x2 - s.x1, 50);
    });

    testWidgets('dokunuş ve sayfa dışı: boş şekil eklenmez, kenarda kalır', (
      t,
    ) async {
      await pump(t);
      tools().select(Tool.shape);
      await t.pump();
      await drag(t, const Offset(100, 100), const Offset(101, 101));
      expect(items(0), isEmpty);
      expect(session.canUndo, isFalse);
      // Sayfanın sağ dışına (sayfa 0: x ≤ 450 ekranda) taşan çizim.
      await drag(t, const Offset(300, 100), const Offset(700, 200));
      final s = items(0).single as Shape;
      expect(s.x2, 200);
    });

    testWidgets('panelden tür seçilir; araç ikonu şekli gösterir', (t) async {
      await pump(t, toolbar: true);
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('seg-ShapeKind.ellipse')));
      await t.tap(find.byKey(const ValueKey('shape-color-1')));
      await t.pump();
      final st = container.read(toolProvider);
      expect(st.shapeKind, ShapeKind.ellipse);
      expect(st.shapeColor, penColors[1]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tool-shape')),
          matching: find.byIcon(selectedIcon(shapeIcon(ShapeKind.ellipse))),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('seç ve metin seç tek düğmede; son tür hatırlanır', (t) async {
    await pump(t, toolbar: true);
    final button = find.byKey(const ValueKey('tool-select'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: find.byType(ToolDock), matching: button),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tool-textSelect')), findsNothing);
    await t.tap(button);
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.select);
    expect(container.read(toolOptionsProvider), isNull);

    // Seçiliyken dokunmak tür panelini açar; Metin seçilir, ikon değişir.
    await t.tap(button);
    await t.pumpAndSettle();
    expect(container.read(toolOptionsProvider), Tool.select);
    await t.tap(find.byKey(const ValueKey('seg-Tool.textSelect')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.textSelect);
    expect(container.read(toolOptionsProvider), isNull, reason: 'kapanır');
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(selectedIcon(toolIcon(Tool.textSelect))),
      ),
      findsOneWidget,
    );

    // Başka araçtan dönünce son kullanılan tür seçilir.
    await t.tap(find.byKey(const ValueKey('tool-hand')));
    await t.pumpAndSettle();
    await t.tap(button);
    await t.pump();
    expect(container.read(toolProvider).tool, Tool.textSelect);
  });

  for (final side in ['left', 'right']) {
    testWidgets('kenarda iki sütun: kalem ve silgi içte ($side)', (t) async {
      await pump(t, toolbar: true, savedSettings: {'toolDock': side});
      expect(find.byKey(const ValueKey('tool-dock-columns')), findsOneWidget);
      Rect at(String tool) => t.getRect(find.byKey(ValueKey('tool-$tool')));
      final outerX = at('hand').center.dx;
      // Dış sütun: seç, şekil, metin aynı hizada.
      for (final k in ['select', 'shape', 'text']) {
        expect(at(k).center.dx, moreOrLessEquals(outerX), reason: k);
      }
      // Geri al / yinele yan yana, iki sütunun üstünde; sütunlar aynı
      // yükseklikten başlar.
      final undo = t.getRect(find.byKey(const ValueKey('undo')));
      final redo = t.getRect(find.byKey(const ValueKey('redo')));
      expect(redo.center.dy, moreOrLessEquals(undo.center.dy));
      expect(undo.bottom, lessThanOrEqualTo(at('hand').top));
      expect(undo.bottom, lessThanOrEqualTo(at('pen').top));
      expect(at('pen').top, moreOrLessEquals(at('hand').top, epsilon: 1));
      // İç sütun sayfaya bakar: solda sağda, sağda solda.
      for (final k in ['pen', 'highlighter', 'laser', 'eraser']) {
        final x = at(k).center.dx;
        expect(side == 'left' ? x > outerX : x < outerX, isTrue, reason: k);
      }

      // Dış sütundaki şeklin paneli kutunun dışında açılır (iç sütunu
      // örtmez).
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.tap(find.byKey(const ValueKey('tool-shape')));
      await t.pumpAndSettle();
      final dock = t.getRect(find.byKey(const ValueKey('tool-dock')));
      final panel = t.getRect(find.byKey(const ValueKey('options-shape')));
      if (side == 'left') {
        expect(panel.left, greaterThanOrEqualTo(dock.right));
      } else {
        expect(panel.right, lessThanOrEqualTo(dock.left));
      }
    });
  }

  testWidgets('en sağdaki aracın paneli ekrandan taşmaz', (t) async {
    await pump(t, toolbar: true);
    await t.tap(find.byKey(const ValueKey('tool-laser')));
    await t.tap(find.byKey(const ValueKey('tool-laser')));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byKey(const ValueKey('options-laser')));
    expect(panel.right, lessThanOrEqualTo(800));
    expect(panel.left, greaterThanOrEqualTo(0));
  });

  group('metin aracı', () {
    // Sayfa 0: ekran = (50, 20) + 2 × sayfa.
    Finder editor() => find.byKey(const ValueKey('text-editor'));

    Future<void> tapAt(WidgetTester t, Offset at) async {
      await t.tapAt(at, kind: PointerDeviceKind.mouse);
      await t.pump();
    }

    testWidgets('dokun, yaz, dışarı dokun: ölçülmüş metin eklenir', (t) async {
      await pump(t);
      tools()
        ..select(Tool.text)
        ..setTextColor(penColors[2])
        ..setTextSize(2);
      await t.pump();
      await tapAt(t, const Offset(150, 200));
      expect(editor(), findsOneWidget);
      await t.enterText(editor(), 'x² + √2\nİkinci satır');
      await tapAt(t, const Offset(300, 500)); // dışarı: tamamla (+ yeni kutu)
      final item = items(0).whereType<TextItem>().single;
      expect(item.text, 'x² + √2\nİkinci satır');
      expect(item.color, penColors[2]);
      expect(item.fontSize, textSizes[2]);
      expect(item.x, closeTo(50, 1e-6));
      final measured = measureTextItem(_textFont.font, item);
      expect(item.width, closeTo(measured.width, 1e-9));
      expect(item.height, closeTo(2 * measured.height / 2, 1e-9));
      expect(item.width, greaterThan(0));
      // İkinci dokunuş yeni (boş) kutu açtı; boş bırakılırsa eklenmez.
      expect(editor(), findsOneWidget);
      tools().select(Tool.pen); // araç değiştirmek de tamamlar
      await t.pump();
      expect(editor(), findsNothing);
      expect(items(0), hasLength(1));
      session.undo();
      expect(items(0), isEmpty);
    });

    testWidgets('var olan metne dokunmak düzenler; boşaltmak siler', (t) async {
      await pump(t);
      tools().select(Tool.text);
      await t.pump();
      await tapAt(t, const Offset(150, 200));
      await t.enterText(editor(), 'eski');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(editor(), findsNothing);
      final old = items(0).whereType<TextItem>().single;

      // Metnin üstüne dokun: aynı öğe düzenlenir.
      await tapAt(
        t,
        Offset(50 + 2 * (old.x + 5), 20 + 2 * (old.y + old.height / 2)),
      );
      expect(editor(), findsOneWidget);
      expect(find.text('eski'), findsOneWidget);
      await t.enterText(editor(), 'yeni metin');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      final edited = items(0).whereType<TextItem>().single;
      expect(edited.id, old.id);
      expect(edited.text, 'yeni metin');
      expect(edited.width, greaterThan(old.width));
      session.undo();
      expect(items(0).single, old);
      session.redo();

      await tapAt(
        t,
        Offset(50 + 2 * (old.x + 5), 20 + 2 * (old.y + old.height / 2)),
      );
      await t.enterText(editor(), '   ');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(items(0), isEmpty);
    });

    testWidgets('boş dokunuş metin eklemez, geri alma adımı oluşmaz', (
      t,
    ) async {
      await pump(t);
      tools().select(Tool.text);
      await t.pump();
      await tapAt(t, const Offset(150, 200));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(items(0), isEmpty);
      expect(session.canUndo, isFalse);
    });

    testWidgets('metin seç aracıyla taşınır ve büyütülür', (t) async {
      await pump(t);
      tools().select(Tool.text);
      await t.pump();
      await tapAt(t, const Offset(150, 200));
      await t.enterText(editor(), 'Ab');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      final before = items(0).whereType<TextItem>().single;
      tools().select(Tool.select);
      await t.pump();
      final c = Offset(
        50 + 2 * (before.x + before.width / 2),
        20 + 2 * (before.y + before.height / 2),
      );
      await drag(t, c, c + const Offset(40, 0));
      final moved = items(0).whereType<TextItem>().single;
      expect(moved.x, closeTo(before.x + 20, 1e-6));
      expect(moved.fontSize, before.fontSize);
    });
  });

  group('özel renk', () {
    Future<void> openPanel(WidgetTester t, String tool) async {
      await t.tap(find.byKey(ValueKey('tool-$tool')));
      await t.pumpAndSettle();
      if (find.byKey(ValueKey('options-$tool')).evaluate().isEmpty) {
        await t.tap(find.byKey(ValueKey('tool-$tool')));
        await t.pumpAndSettle();
      }
    }

    testWidgets('+ seçiciyi açar; kodla seçilen renk araca ve listeye girer', (
      t,
    ) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pump(t, toolbar: true);
      await openPanel(t, 'pen');
      expect(find.byKey(const ValueKey('custom-color-0')), findsNothing);

      await t.tap(find.byKey(const ValueKey('custom-color-new')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('options-pen')),
        findsNothing,
        reason: 'seçici açılınca panel kapanır',
      );
      // Başlangıç: aracın şimdiki rengi.
      expect(find.text('#1A1A1A'), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('picker-hex')), '#12');
      await t.pump();
      expect(find.text('Geçersiz kod'), findsOneWidget);
      final ok = t.widget<FilledButton>(
        find.byKey(const ValueKey('picker-ok')),
      );
      expect(ok.onPressed, isNull);

      await t.enterText(find.byKey(const ValueKey('picker-hex')), '#0A7E8C');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('picker-ok')));
      await t.pumpAndSettle();

      final s = container.read(toolProvider);
      expect(s.penColor, 0xFF0A7E8C);
      expect(s.customColors, [0xFF0A7E8C]);
      expect(settings.get<List<Object?>>('customColors'), ['#0A7E8C']);

      // Çizilen çizgi bu renkte.
      await drag(t, const Offset(300, 300), const Offset(400, 320));
      expect((items(0).single as Stroke).color, 0xFF0A7E8C);

      // Özel renk şekil panelinde de var.
      await openPanel(t, 'shape');
      await t.tap(find.byKey(const ValueKey('custom-color-0')));
      await t.pump();
      expect(container.read(toolProvider).shapeColor, 0xFF0A7E8C);
    });

    testWidgets('seçicide vazgeç: hiçbir şey değişmez', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pump(t, toolbar: true);
      await openPanel(t, 'highlighter');
      await t.tap(find.byKey(const ValueKey('custom-color-new')));
      await t.pumpAndSettle();
      // Ton çubuğunda sürükle: önizleme değişir.
      await t.drag(
        find.byKey(const ValueKey('picker-hue')),
        const Offset(60, 0),
      );
      await t.pump();
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      final s = container.read(toolProvider);
      expect(s.highlighterColor, highlighterColors[0]);
      expect(s.customColors, isEmpty);
    });

    testWidgets('alan ve ton çubuğu rengi belirler', (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pump(t, toolbar: true);
      await openPanel(t, 'pen');
      await t.tap(find.byKey(const ValueKey('custom-color-new')));
      await t.pumpAndSettle();
      final plane = find.byKey(const ValueKey('picker-plane'));
      final hue = find.byKey(const ValueKey('picker-hue'));
      // Ton: en sol (kırmızı); alan: sağ üst köşe (tam doygun, tam parlak).
      String hex() => t
          .widget<TextField>(find.byKey(const ValueKey('picker-hex')))
          .controller!
          .text;
      await t.tapAt(t.getTopLeft(hue) + const Offset(0, 24));
      await t.tapAt(t.getTopRight(plane) + const Offset(-0.01, 0));
      await t.pump();
      expect(hex(), '#FF0000');
      // Alan: sol alt köşe siyah.
      await t.tapAt(t.getBottomLeft(plane) + const Offset(0, -0.01));
      await t.pump();
      expect(hex(), '#000000');
      await t.tap(find.byKey(const ValueKey('picker-ok')));
      await t.pumpAndSettle();
      expect(container.read(toolProvider).penColor, 0xFF000000);
    });

    testWidgets('kayıtlı özel renkler açılışta yüklenir; bozuklar atlanır', (
      t,
    ) async {
      await pump(
        t,
        savedSettings: {
          'customColors': ['#0A7E8C', 'bozuk', 42, '#ABCDEF'],
        },
      );
      expect(container.read(toolProvider).customColors, [
        0xFF0A7E8C,
        0xFFABCDEF,
      ]);
    });
  });

  testWidgets(
    'imleç: kalem / fosforlu / silgi / geçici kalem kendi imlecini çizer',
    (t) async {
      await pump(t);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(150, 200));
      addTearDown(mouse.removePointer);
      MouseCursor active() =>
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
      for (final (tool, cursor) in [
        (Tool.pen, SystemMouseCursors.none),
        (Tool.highlighter, SystemMouseCursors.none),
        (Tool.eraser, SystemMouseCursors.none),
        (Tool.laser, SystemMouseCursors.none),
        (Tool.shape, SystemMouseCursors.precise),
        (Tool.text, SystemMouseCursors.text),
        (Tool.hand, SystemMouseCursors.grab),
      ]) {
        tools().select(tool);
        await t.pump();
        await mouse.moveBy(const Offset(1, 0));
        await t.pump();
        expect(active(), cursor, reason: tool.name);
      }
    },
  );

  group('araç kutusunun kenarı', () {
    test('en yakın kenar, ekrana oranla', () {
      const area = Size(1280, 800);
      expect(nearestEdge(const Offset(640, 20), area), DockEdge.top);
      expect(nearestEdge(const Offset(640, 780), area), DockEdge.bottom);
      expect(nearestEdge(const Offset(20, 400), area), DockEdge.left);
      expect(nearestEdge(const Offset(1270, 400), area), DockEdge.right);
      // Ekran dışı da kırpılır.
      expect(nearestEdge(const Offset(640, 2000), area), DockEdge.bottom);
    });

    test('eski ayar (yön) yeni kenara çevrilir', () {
      DockEdge read(Object? saved) {
        final c = ProviderContainer(
          overrides: [
            settingsStoreProvider.overrideWithValue(
              SettingsStore.memory({'toolDock': saved}),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c.read(toolDockProvider);
      }

      expect(read('horizontal'), DockEdge.top);
      expect(read('vertical'), DockEdge.left);
      expect(read('right'), DockEdge.right);
      expect(read('bozuk'), DockEdge.top);
      expect(read(null), DockEdge.top);
    });

    testWidgets(
      'tutamağı alta sürükle: kutu alta oturur, panel yukarı açılır',
      (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await pump(t, toolbar: true);
        expect(container.read(toolDockProvider), DockEdge.top);

        final grip = find.byKey(const ValueKey('dock-move'));
        final g = await t.startGesture(t.getCenter(grip));
        for (var i = 1; i <= 10; i++) {
          await g.moveBy(const Offset(-20, 70));
          await t.pump();
        }
        // Sürüklerken kutu parmağı izler.
        expect(t.getCenter(grip).dy, greaterThan(500));
        await g.up();
        await t.pumpAndSettle();
        expect(container.read(toolDockProvider), DockEdge.bottom);
        expect(settings.get<String>('toolDock'), 'bottom');
      },
    );
  });

  group('görsel düzenleme ve opaklık', () {
    // Sayfa 0'da (20,20) 60×40 pt görsel: ekranda (90,60)–(210,140).
    const image = ImageItem(
      id: 'g',
      imageId: 'a',
      x: 20,
      y: 20,
      width: 60,
      height: 40,
    );
    const text = TextItem(
      id: 't',
      text: 'Not',
      color: 0xFF1A1A1A,
      fontSize: 14,
      x: 20,
      y: 200,
      width: 40,
      height: 20,
    );

    Future<void> setUpItems(WidgetTester t) async {
      await pump(t);
      final decoded = await t.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
        return recorder.endRecording().toImage(30, 20);
      });
      // Görseli oturum sahiplenir (kapanınca o bırakır).
      session.images.add('a', Uint8List.fromList([1, 2, 3]), decoded);
      session.insertImage(0, image);
      session.pasteItems(0, const [text], dx: 0, dy: 0);
      session.clearSelection();
      tools().select(Tool.select);
      await t.pump();
    }

    Future<void> click(WidgetTester t, Offset at) async {
      await t.tapAt(at, kind: PointerDeviceKind.mouse);
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('seç aracıyla çift tıklama düzenleyiciyi açar; tek adım', (
      t,
    ) async {
      await setUpItems(t);
      await click(t, const Offset(150, 100));
      expect(find.byType(ImageEditor), findsNothing, reason: 'tek tık seçer');
      await click(t, const Offset(150, 100));
      await t.pumpAndSettle();
      expect(find.byType(ImageEditor), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('image-edit-rotate-right')));
      await t.tap(find.byKey(const ValueKey('image-edit-apply')));
      await t.pumpAndSettle();
      final g = items(0).whereType<ImageItem>().single;
      expect(g.rotation, 1);
      expect(g.width, closeTo(40, 1e-6));
      expect(g.height, closeTo(60, 1e-6));
      expect((g.x, g.y), (20, 20));
      session.undo();
      expect(items(0).whereType<ImageItem>().single, image);
    });

    testWidgets('vazgeçince değişmez', (t) async {
      await setUpItems(t);
      await click(t, const Offset(150, 100));
      await click(t, const Offset(150, 100));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('image-edit-rotate-right')));
      await t.tap(find.byKey(const ValueKey('image-edit-cancel')));
      await t.pumpAndSettle();
      expect(items(0).whereType<ImageItem>().single, image);
    });

    testWidgets('seçim çubuğu: görselde düzenle, metinde yalnız opaklık', (
      t,
    ) async {
      await setUpItems(t);
      session.select(0, {'g'});
      await t.pump();
      expect(
        find.byKey(const ValueKey('selection-edit-image')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('selection-opacity')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('selection-edit-image')));
      await t.pumpAndSettle();
      expect(find.byType(ImageEditor), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('image-edit-cancel')));
      await t.pumpAndSettle();

      final textId = items(0).whereType<TextItem>().single.id;
      session.select(0, {textId});
      await t.pump();
      expect(find.byKey(const ValueKey('selection-edit-image')), findsNothing);
      await t.tap(find.byKey(const ValueKey('selection-opacity')));
      await t.pumpAndSettle();
      final slider = find.byKey(const ValueKey('selection-opacity-slider'));
      expect(slider, findsOneWidget);
      // Kaydırıcının sol ucuna: %10.
      final track = t.getRect(
        find.descendant(of: slider, matching: find.byType(Slider)),
      );
      await t.tapAt(track.centerLeft + const Offset(4, 0));
      await t.pumpAndSettle();
      final after = items(0).whereType<TextItem>().single;
      expect(itemOpacity(after), closeTo(0.1, 0.01));
      session.undo();
      expect(itemOpacity(items(0).whereType<TextItem>().single), 1);
    });

    testWidgets('metin aracı opaklığı yeni metne uygulanır', (t) async {
      await pump(t);
      tools()
        ..select(Tool.text)
        ..setTextOpacity(40);
      await t.pump();
      await t.tapAt(const Offset(150, 200), kind: PointerDeviceKind.mouse);
      await t.pump();
      await t.enterText(find.byKey(const ValueKey('text-editor')), 'Soluk');
      await t.tapAt(const Offset(300, 500), kind: PointerDeviceKind.mouse);
      await t.pump();
      final item = items(0).whereType<TextItem>().single;
      expect(item.color >>> 24, (0.4 * 255).round());
    });
  });
}
