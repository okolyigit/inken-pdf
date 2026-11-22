import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/settings/app_info.dart';
import 'package:inken/features/settings/bug_report.dart';
import 'package:inken/l10n/app_localizations.dart';
import 'package:inken/l10n/app_localizations_en.dart';
import 'package:inken/l10n/app_localizations_tr.dart';
import 'package:inken/platform/link_opener.dart';

void main() {
  test('gövde başlıkları ve uygulama bilgilerini içerir (tr, en)', () {
    for (final AppLocalizations l10n in [
      AppLocalizationsTr(),
      AppLocalizationsEn(),
    ]) {
      final body = bugReportBody(l10n, 'Sürüm: 0.1.0');
      expect(body, contains(l10n.bugReportWhat));
      expect(body, contains(l10n.bugReportExpected));
      expect(body, contains(l10n.bugReportSteps));
      expect(body, endsWith('Sürüm: 0.1.0'));
    }
  });

  test('mailto: boşluk %20, Türkçe harfler ve satırlar korunur', () {
    final uri = mailtoUri(subject: 'Inken PDF hata', body: 'Ne oldu?\nşğı & ?');
    final text = uri.toString();
    expect(
      text,
      startsWith('mailto:$feedbackEmail?subject=Inken%20PDF%20hata'),
    );
    expect(text, isNot(contains('+')));
    expect(uri.queryParameters['body'], 'Ne oldu?\nşğı & ?');
  });

  test('GitHub: yeni hata kaydı sayfası, gövde çözülünce aynı', () {
    final uri = githubIssueUri('a & b\nç');
    expect(uri.toString(), startsWith('$repositoryUrl/issues/new?body='));
    expect(uri.queryParameters['body'], 'a & b\nç');
  });

  group('reportBug', () {
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

    Future<List<Uri>> run(
      WidgetTester tester, {
      required String choice,
      bool opens = true,
    }) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkOpenerProvider.overrideWithValue((url) async {
              opened.add(url);
              return opens;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => reportBug(context, 'BILGI'),
                  child: const Text('bildir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('bildir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bug-report-dialog')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(choice)));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('e-posta seçilince mailto açılır', (tester) async {
      final opened = await run(tester, choice: 'bug-report-email');
      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'mailto');
      expect(opened.single.path, feedbackEmail);
      expect(opened.single.queryParameters['body'], contains('BILGI'));
      expect(clipboard, isNull);
    });

    testWidgets('GitHub seçilince hata kaydı sayfası açılır', (tester) async {
      final opened = await run(tester, choice: 'bug-report-github');
      expect(opened.single.toString(), startsWith('$repositoryUrl/issues/new'));
      expect(opened.single.queryParameters['body'], contains('BILGI'));
    });

    testWidgets('vazgeçince hiçbir şey açılmaz', (tester) async {
      final opened = await run(tester, choice: 'bug-report-cancel');
      expect(opened, isEmpty);
      expect(clipboard, isNull);
    });

    testWidgets('e-posta açılamazsa adresle birlikte panoya', (tester) async {
      await run(tester, choice: 'bug-report-email', opens: false);
      expect(clipboard, startsWith(feedbackEmail));
      expect(clipboard, contains('BILGI'));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

}
