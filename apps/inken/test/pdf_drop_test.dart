import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/pdf_drop.dart';
import 'package:inken/l10n/app_localizations.dart';

/// Eklentinin yerel tarafının göndereceği mesaj (`desktop_drop` kanalı).
Future<void> _native(WidgetTester t, String method, Object? args) async {
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'desktop_drop',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
  await t.pump();
}

void main() {
  test('ilk PDF seçilir; uzantı büyük / küçük harf', () {
    expect(firstPdf(['/a/not.txt', '/a/Ders.PDF', '/a/b.pdf']), '/a/Ders.PDF');
    expect(firstPdf(['/a/resim.png']), isNull);
    expect(firstPdf(const []), isNull);
  });

  testWidgets('üzerine gelince katman; PDF bırakılınca açılır', (t) async {
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PdfDropTarget(
            onPdf: opened.add,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final overlay = find.byKey(const ValueKey('pdf-drop-overlay'));
    expect(overlay, findsNothing);

    await _native(t, 'entered', [100.0, 100.0]);
    expect(overlay, findsOneWidget);
    expect(find.text("PDF'i açmak için bırak"), findsOneWidget);
    await _native(t, 'exited', null);
    expect(overlay, findsNothing);

    await _native(t, 'entered', [100.0, 100.0]);
    await _native(t, 'performOperation', [
      '/belgeler/a.txt',
      '/belgeler/ödev.pdf',
    ]);
    expect(opened, ['/belgeler/ödev.pdf']);
    expect(overlay, findsNothing);

    await _native(t, 'entered', [100.0, 100.0]);
    await _native(t, 'performOperation', ['/belgeler/resim.png']);
    expect(opened, hasLength(1));
    expect(find.text('Yalnızca PDF dosyaları açılabilir'), findsOneWidget);
  });
}
