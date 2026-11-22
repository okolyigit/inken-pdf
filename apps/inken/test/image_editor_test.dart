import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/image_editor.dart';
import 'package:inken/features/ink/ink_painter.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_core/inken_core.dart';

/// [w]x[h] görsel: sol yarı kırmızı, sağ yarı mavi.
Future<ui.Image> _image(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, w / 2, h.toDouble()),
      Paint()..color = const Color(0xFFFF0000),
    )
    ..drawRect(
      Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()),
      Paint()..color = const Color(0xFF0000FF),
    );
  return recorder.endRecording().toImage(w, h);
}

const _cm = 72 / 2.54;

/// 400x200 görsel, sayfada 10 cm × 5 cm.
const _item = ImageItem(
  id: 'g',
  imageId: 'a',
  x: 30,
  y: 40,
  width: 10 * _cm,
  height: 5 * _cm,
);

void main() {
  late ui.Image image;

  Future<ImageEditorState> pump(
    WidgetTester t, {
    Size size = const Size(1280, 800),
    ImageItem item = _item,
  }) async {
    image = (await t.runAsync(() => _image(400, 200)))!;
    addTearDown(image.dispose);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dialog(
            child: ImageEditor(
              item: item,
              image: image,
              phone: size.width < 600,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    return t.state<ImageEditorState>(find.byType(ImageEditor));
  }

  String field(WidgetTester t, String key) => t
      .widget<TextField>(find.byKey(ValueKey('image-edit-$key')))
      .controller!
      .text;

  testWidgets('boyut cm; kilitliyken oran korunur, açıkken korunmaz', (
    t,
  ) async {
    final s = await pump(t);
    expect(field(t, 'width'), '10,0');
    expect(field(t, 'height'), '5,0');
    expect(s.locked, isTrue);
    await t.enterText(find.byKey(const ValueKey('image-edit-width')), '20');
    expect(field(t, 'height'), '10,0');
    expect(s.widthPt, closeTo(20 * _cm, 0.01));
    expect(s.heightPt, closeTo(10 * _cm, 0.01));
    await t.tap(find.byKey(const ValueKey('image-edit-lock')));
    await t.pump();
    expect(s.locked, isFalse);
    await t.enterText(find.byKey(const ValueKey('image-edit-width')), '12,5');
    expect(s.widthPt, closeTo(12.5 * _cm, 0.01));
    expect(s.heightPt, closeTo(10 * _cm, 0.01), reason: 'yükseklik aynı');
  });

  testWidgets('döndür: en ve boy yer değiştirir; iki yön', (t) async {
    final s = await pump(t);
    await t.tap(find.byKey(const ValueKey('image-edit-rotate-right')));
    await t.pump();
    expect(s.turns, 1);
    expect(field(t, 'width'), '5,0');
    expect(field(t, 'height'), '10,0');
    await t.tap(find.byKey(const ValueKey('image-edit-rotate-left')));
    await t.tap(find.byKey(const ValueKey('image-edit-rotate-left')));
    await t.pump();
    expect(s.turns, 3);
  });

  testWidgets('1:1 kırpma ortada kare; sayfadaki ölçek korunur', (t) async {
    final s = await pump(t);
    await t.tap(find.byKey(const ValueKey('crop-square')));
    await t.pump();
    expect(s.crop.left, closeTo(0.25, 1e-9));
    expect(s.crop.right, closeTo(0.75, 1e-9));
    expect(s.crop.top, 0);
    expect(s.widthPt, closeTo(5 * _cm, 0.01));
    expect(s.heightPt, closeTo(5 * _cm, 0.01));
    await t.tap(find.byKey(const ValueKey('crop-original')));
    await t.pump();
    expect(s.crop, fullCrop);
  });

  testWidgets('köşeden sürükleyerek kırpılır, içinden kaydırılır', (t) async {
    final s = await pump(t);
    final preview = t.getRect(find.byKey(const ValueKey('image-edit-preview')));
    final img = s.imageRectIn(preview.size).shift(preview.topLeft);
    // Sağ alt köşeyi içeri: genişliğin ve yüksekliğin dörtte biri.
    await t.dragFrom(
      img.bottomRight - const Offset(2, 2),
      Offset(-img.width / 4, -img.height / 4),
    );
    await t.pump();
    expect(s.crop.right, closeTo(0.75, 0.02));
    expect(s.crop.bottom, closeTo(0.75, 0.02));
    expect(s.crop.left, 0);
    final w = s.crop.right - s.crop.left;
    // Çerçevenin içinden sola itmek: kenara dayanır, boyutu değişmez.
    await t.dragFrom(img.center, Offset(-img.width, 0));
    await t.pump();
    expect(s.crop.left, 0);
    expect(s.crop.right - s.crop.left, closeTo(w, 1e-9));
  });

  testWidgets('opaklık ve sıfırla; sonuç öğesi', (t) async {
    final s = await pump(
      t,
      item: _item.copyWith(rotation: 1, cropRight: 0.5, opacity: 0.4),
    );
    expect(s.turns, 1);
    expect(s.opacityPercent, 40);
    final r = s.result;
    expect(r.rotation, 1);
    expect(r.cropRight, closeTo(0.5, 1e-9), reason: 'gidiş-dönüş');
    expect(r.opacity, closeTo(0.4, 1e-9));
    s.setOpacityPercent(70);
    await t.tap(find.byKey(const ValueKey('image-edit-reset')));
    await t.pump();
    expect(s.turns, 0);
    expect(s.crop, fullCrop);
    expect(s.opacityPercent, 100);
    expect((s.result.x, s.result.y), (30, 40), reason: 'sol üst sabit');
  });

  testWidgets('telefonda tam ekran düzen taşmaz', (t) async {
    await pump(t, size: const Size(390, 844));
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('image-edit-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('image-edit-reset')), findsOneWidget);
  });

  testWidgets('ekranda kırpma, döndürme, opaklık PDF ile aynı yönde', (
    t,
  ) async {
    await t.runAsync(() async {
      final img = await _image(4, 2);
      Future<List<int>> pixel(ImageItem g, int x, int y) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
        paintEditedImage(
          canvas,
          img,
          Rect.fromLTWH(g.x, g.y, g.width, g.height),
          crop: cropOf(g),
          turns: g.rotation,
          opacity: g.opacity,
        );
        final out = await recorder.endRecording().toImage(60, 60);
        final data = await out.toByteData();
        out.dispose();
        final i = (y * 60 + x) * 4;
        return data!.buffer.asUint8List().sublist(i, i + 3);
      }

      const g = ImageItem(
        id: 'g',
        imageId: 'a',
        x: 10,
        y: 10,
        width: 20,
        height: 40,
      );
      // Büyütürken yumuşatma kenarda komşu pikseli biraz karıştırır:
      // baskın renge bakılır.
      String tone(List<int> p) => p[0] > 200 && p[2] < 60
          ? 'kırmızı'
          : p[2] > 200 && p[0] < 60
          ? 'mavi'
          : '$p';
      // Saat yönünde çeyrek tur: sol yarı (kırmızı) üste gelir.
      final turned = g.copyWith(rotation: 1);
      expect(tone(await pixel(turned, 20, 15)), 'kırmızı');
      expect(tone(await pixel(turned, 20, 45)), 'mavi');
      // Sol yarı kırpılınca kutunun tamamı kırmızı.
      final cropped = g.copyWith(cropRight: 0.5);
      expect(tone(await pixel(cropped, 15, 15)), 'kırmızı');
      expect(tone(await pixel(cropped, 25, 45)), 'kırmızı');
      // Yarı saydam: beyaz zeminde açık kırmızı.
      final faded = cropped.copyWith(opacity: 0.5);
      final p = await pixel(faded, 15, 15);
      expect(p[0], greaterThan(240));
      expect(p[1], inInclusiveRange(100, 150));
      img.dispose();
    });
  });
}
