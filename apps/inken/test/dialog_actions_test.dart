import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/theme/dialog_actions.dart';

void main() {
  Future<List<String>> show(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final pressed = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => AlertDialog(
            title: const Text('Kaydedilmemiş değişiklikler'),
            actions: [
              DialogActions(
                cancel: (label: 'Vazgeç', onPressed: () => pressed.add('c')),
                secondary: (
                  label: 'Kaydetme',
                  onPressed: () => pressed.add('s'),
                ),
                primary: (label: 'Kaydet', onPressed: () => pressed.add('p')),
              ),
            ],
          ),
        ),
      ),
    );
    return pressed;
  }

  Rect at(WidgetTester t, String key) =>
      t.getRect(find.byKey(ValueKey('dialog-$key')));

  testWidgets('telefon: tam genişlikte alt alta, ana iş üstte', (t) async {
    final pressed = await show(t, const Size(400, 800));
    final p = at(t, 'primary'), s = at(t, 'secondary'), c = at(t, 'cancel');
    expect(p.bottom, lessThanOrEqualTo(s.top));
    expect(s.bottom, lessThanOrEqualTo(c.top));
    expect(p.width, s.width);
    expect(s.width, c.width);
    expect(find.byType(OutlinedButton), findsOneWidget);
    await t.tap(find.text('Kaydet'));
    await t.tap(find.text('Kaydetme'));
    await t.tap(find.text('Vazgeç'));
    expect(pressed, ['p', 's', 'c']);
  });

  testWidgets('geniş: tek sırada, ana iş sağda', (t) async {
    await show(t, const Size(1280, 800));
    final p = at(t, 'primary'), s = at(t, 'secondary'), c = at(t, 'cancel');
    expect(p.center.dy, moreOrLessEquals(c.center.dy));
    expect(c.right, lessThanOrEqualTo(s.left));
    expect(s.right, lessThanOrEqualTo(p.left));
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
