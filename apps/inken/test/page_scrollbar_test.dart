import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/viewer/page_scrollbar.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// 100 sayfalık belge; ekranda %10'u görünür.
class _FakeScroller extends ChangeNotifier implements PageScroller {
  double? fraction = 0;
  final List<double> requests = [];

  @override
  double? get scrollFraction => fraction;

  @override
  double get visibleFraction => 0.1;

  @override
  int get pageCount => 100;

  @override
  int? get currentPage => fraction == null ? null : (fraction! * 99).round();

  @override
  Future<void> scrollToFraction(double f) async {
    requests.add(f);
    fraction = f;
    notifyListeners();
  }
}

void main() {
  late _FakeScroller scroller;

  // Çubuk 400 px yüksekliğinde: tutamak 40 px, yol 360 px.
  Future<void> pump(WidgetTester t) async {
    scroller = _FakeScroller();
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            height: 400,
            child: PageScrollbar(scroller: scroller),
          ),
        ),
      ),
    );
  }

  Offset at(WidgetTester t, double y) =>
      t.getTopLeft(find.byKey(const ValueKey('page-scrollbar'))) +
      Offset(PageScrollbar.hitWidth / 2, y);

  testWidgets('tutamak konumu kaydırmayı izler', (t) async {
    await pump(t);
    final thumb = find.byKey(const ValueKey('page-scrollbar-thumb'));
    expect(t.getTopLeft(thumb).dy, 0);
    scroller.fraction = 0.5;
    scroller.notifyListeners();
    await t.pumpAndSettle();
    expect(t.getTopLeft(thumb).dy, 180);
    expect(t.getSize(thumb).height, 40);
  });

  testWidgets('tutamağı sürüklemek kaydırır; sürüklerken sayfa görünür', (
    t,
  ) async {
    await pump(t);
    final g = await t.startGesture(at(t, 20));
    await g.moveBy(const Offset(0, 30));
    await g.moveBy(const Offset(0, 90));
    await t.pump();
    expect(scroller.fraction, greaterThan(0));
    final label = find.byKey(const ValueKey('page-scrollbar-label'));
    expect(label, findsOneWidget);
    expect(
      find.descendant(of: label, matching: find.textContaining('/ 100')),
      findsOneWidget,
    );
    final before = scroller.fraction!;
    await g.moveBy(const Offset(0, 36));
    await t.pump();
    expect(scroller.fraction, closeTo(before + 0.1, 1e-9));
    await g.moveBy(const Offset(0, 1000));
    await t.pump();
    expect(scroller.fraction, 1);
    await g.up();
    await t.pump();
    expect(label, findsNothing);
  });

  testWidgets('çubuğa dokunmak o konuma atlar', (t) async {
    await pump(t);
    // Tutamağın ortası 200 px'e gelsin: (200 - 20) / 360 = 0.5.
    await t.tapAt(at(t, 200));
    await t.pump();
    expect(scroller.fraction, closeTo(0.5, 1e-9));
  });

  testWidgets('belge ekrana sığıyorsa çubuk yok', (t) async {
    await pump(t);
    scroller.fraction = null;
    scroller.notifyListeners();
    await t.pump();
    expect(find.byKey(const ValueKey('page-scrollbar')), findsNothing);
  });
}
