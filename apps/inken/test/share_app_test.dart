import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/settings/app_info.dart';
import 'package:inken/features/settings/share_app.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/l10n/app_localizations_en.dart';
import 'package:inken/l10n/app_localizations_tr.dart';
import 'package:inken/platform/share_service.dart';

class _FakeSharer implements ShareService {
  _FakeSharer({required this.sheet});

  /// Paylaşma sayfası var mı (Android).
  final bool sheet;
  final texts = <(String, String)>[];

  @override
  bool get supported => true;

  @override
  Future<ShareOutcome> sharePdf(String path, {required String name}) =>
      throw UnimplementedError();

  @override
  Future<ShareOutcome> shareFiles(
    List<String> paths, {
    required String name,
    required String mime,
  }) => throw UnimplementedError();

  @override
  Future<bool> shareText(String text, {required String subject}) async {
    texts.add((text, subject));
    return sheet;
  }
}

void main() {
  test('paylaşma metni depo bağlantısını içerir (tr, en)', () {
    for (final AppLocalizations l10n in [
      AppLocalizationsTr(),
      AppLocalizationsEn(),
    ]) {
      final text = shareAppMessage(l10n);
      expect(text, contains(repositoryUrl));
      expect(text, startsWith('Inken PDF'));
    }
  });

  group('shareApp', () {
    String? clipboard;
    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> pumpAndTap(WidgetTester t, _FakeSharer sharer) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [shareServiceProvider.overrideWithValue(sharer)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => shareApp(context),
                  child: const Text('paylaş'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('paylaş'));
      await t.pumpAndSettle();
    }

    testWidgets('paylaşma sayfası varsa (Android) panoya dokunulmaz', (
      t,
    ) async {
      final sharer = _FakeSharer(sheet: true);
      await pumpAndTap(t, sharer);
      expect(sharer.texts.single.$1, contains(repositoryUrl));
      expect(sharer.texts.single.$2, 'Inken PDF');
      expect(clipboard, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('masaüstünde metin panoya kopyalanır ve bildirilir', (t) async {
      final sharer = _FakeSharer(sheet: false);
      await pumpAndTap(t, sharer);
      expect(clipboard, shareAppMessage(AppLocalizationsTr()));
      expect(find.text(AppLocalizationsTr().shareAppCopied), findsOneWidget);
    });
  });
}
