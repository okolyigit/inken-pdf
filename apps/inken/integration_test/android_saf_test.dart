// Gerçek SAF kanalı (Kotlin, `inken/documents`), yalnızca Android'de.
// Seçici arayüzü otomatikleştirilemediğinden belge, hata ayıklama
// yardımcısıyla İndirilenler'de (content://) oluşturulur.
// Çalıştır: flutter test integration_test/android_saf_test.dart -d <android>
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/files/document_io.dart';
import 'package:inken/features/files/open_document.dart';
import 'package:inken/features/ink/ink_layer.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:integration_test/integration_test.dart';

const _channel = MethodChannel('inken/documents');

Future<String> _createDownload(String name) async => (await _channel
    .invokeMethod<String>('debugCreateDownload', {'name': name}))!;

Future<void> _delete(String uri) =>
    _channel.invokeMethod<void>('debugDelete', {'uri': uri});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = !Platform.isAndroid;

  testWidgets('oku / yaz / boyut / kısaltma', skip: skip, (t) async {
    final io = PlatformDocumentIo();
    final uri = await _createDownload(
      'inken-saf-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    addTearDown(() => _delete(uri));
    expect(isContentUri(uri), isTrue);

    final big = Uint8List.fromList(List.generate(300000, (i) => i % 251));
    await io.write(uri, big);
    expect((await io.stat(uri))!.size, big.length);
    expect(await io.read(uri), big);

    // Daha kısa içerik: dosya kısaltılmalı (eski kuyruk kalmamalı).
    final small = Uint8List.fromList(List.generate(1000, (i) => i % 7));
    await io.write(uri, small);
    expect((await io.stat(uri))!.size, small.length);
    expect(await io.read(uri), small);

    await _delete(uri);
    expect(await io.stat(uri), isNull);
  });

  testWidgets(
    'Inken dosyası URI\'den açılır, aynı URI\'ye kaydedilir',
    skip: skip,
    (t) async {
      t.platformDispatcher.localesTestValue = const [Locale('tr')];
      addTearDown(t.platformDispatcher.clearLocalesTestValue);
      await initInkenPdf();
      final io = PlatformDocumentIo();
      final uri = await _createDownload(
        'inken-ders-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      addTearDown(() => _delete(uri));

      // Bir çizgili Inken dosyası hazırla ve URI'ye yaz.
      final src = base64Decode(_twoPagesPdf);
      final read0 = (await t.runAsync(() => loadInkenFile(src)))!;
      expect(read0.inkenJson, isNull);
      await t.runAsync(() => io.write(uri, src));

      final dir = Directory.systemTemp.createTempSync('inken_saf');
      final container = ProviderContainer(
        overrides: [backupStoreProvider.overrideWithValue(BackupStore.at(dir))],
      );
      addTearDown(container.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const InkenApp(),
        ),
      );
      final bytes = (await t.runAsync(() => io.read(uri)))!;
      await t.runAsync(
        () => container
            .read(openDocumentProvider.notifier)
            .openBytes(name: 'ders.pdf', bytes: bytes, path: uri),
      );
      for (
        var i = 0;
        i < 100 && find.byType(InkLayer).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump();
      }
      final notifier = container.read(openDocumentProvider.notifier);
      // Düz PDF: yanına yazılamaz, yer sorulmalı.
      expect(notifier.needsSaveLocation, isTrue);

      final layer = t.widget<InkLayer>(find.byType(InkLayer));
      final box = t.getRect(find.byType(InkLayer));
      final v = layer.geometry.viewportOf(0)!;
      final g = await t.startGesture(
        box.topLeft + v.toView(const Offset(100, 150)),
        kind: PointerDeviceKind.stylus,
      );
      for (var i = 1; i <= 5; i++) {
        await g.moveTo(
          box.topLeft + v.toView(Offset(100 + i * 30.0, 150 + i * 2.0)),
          timeStamp: Duration(milliseconds: 12 * i),
        );
      }
      await g.up();
      await t.pump();
      final session = layer.session;
      expect(session.isDirty, isTrue);

      // "Farklı kaydet" ile seçilmiş gibi: aynı URI'yi Inken dosyası yap.
      await t.runAsync(
        () => notifier.save(
          session.document,
          target: (location: uri, name: 'ders.pdf'),
        ),
      );
      expect(
        notifier.needsSaveLocation,
        isFalse,
        reason: 'artık Inken dosyası',
      );
      final saved = (await t.runAsync(() => io.read(uri)))!;
      final json = (await t.runAsync(() => loadInkenFile(saved)))!.inkenJson;
      expect(decodeInkenDocument(json!).pages[0].items, hasLength(1));
    },
  );
}

/// test/fixtures/two_pages.pdf (cihazda depo klasörü yok).
const _twoPagesPdf =
    'JVBERi0xLjcKJcfsj6IKJSVJbnZvY2F0aW9uOiBncyAtcSAtc0RFVklDRT1wZGZ3cml0ZSA/'
    'ID8gPyA/CjUgMCBvYmoKPDwvTGVuZ3RoIDYgMCBSL0ZpbHRlciAvRmxhdGVEZWNvZGU+Pgpz'
    'dHJlYW0KeJwti7EKwjAURff3FXezQaxJFesiQsFBcKlm7BJiWp5tUi0NqF8varnDgcs5D8hU'
    'QX430XqSaOhB6vdigvUoNC3PObItdE1/WSHPkG8ktKfkGFoXUPNzjIPDAhfzqg2U0Ldfp9bf'
    'bi2hT5SoSiB7Yo4VdlAKVxfaznkODNu/Y4jvVMxo9ZezSqDgAdE2LnAAWxjLnRkYY3/vjGe0'
    'xo487MWMDppKKukDkrI3y2VuZHN0cmVhbQplbmRvYmoKMTEgMCBvYmoKPDwvTGVuZ3RoIDEy'
    'IDAgUi9GaWx0ZXIgL0ZsYXRlRGVjb2RlPj4Kc3RyZWFtCnicK1Qw0DNUMABBKJ2cy2WgkM5V'
    'yGUIFlWAUsm5Ck4hXPpB5gpGFgohaVwQxYYK5kYK5mYGCiG5XBqeedmpeQppmRUlpUWpCroK'
    'wYmVaYkKRpohWVyuIVyBXIFcAPJwGNJlbmRzdHJlYW0KZW5kb2JqCjQgMCBvYmoKPDwvVHlw'
    'ZS9QYWdlL01lZGlhQm94IFswIDAgNTk1IDg0Ml0KL1JvdGF0ZSAwL1BhcmVudCAzIDAgUgov'
    'UmVzb3VyY2VzPDwvUHJvY1NldFsvUERGIC9UZXh0XQovRm9udCA5IDAgUgo+PgovQ29udGVu'
    'dHMgNSAwIFIKPj4KZW5kb2JqCjEwIDAgb2JqCjw8L1R5cGUvUGFnZS9NZWRpYUJveCBbMCAw'
    'IDU5NSA4NDJdCi9Sb3RhdGUgMC9QYXJlbnQgMyAwIFIKL1Jlc291cmNlczw8L1Byb2NTZXRb'
    'L1BERiAvVGV4dF0KL0ZvbnQgMTMgMCBSCj4+Ci9Db250ZW50cyAxMSAwIFIKPj4KZW5kb2Jq'
    'CjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFsKNCAwIFIKMTAgMCBSCl0gL0NvdW50'
    'IDIKPj4KZW5kb2JqCjEgMCBvYmoKPDwvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMyAwIFIKL01l'
    'dGFkYXRhIDE1IDAgUgo+PgplbmRvYmoKMTQgMCBvYmoKPDwvRmlsdGVyL0ZsYXRlRGVjb2Rl'
    'L0xlbmd0aCAzNDk+PnN0cmVhbQp4nF3SQW6kMBAF0D2n4Ab9saEcJPQ3ySaLiUYzcwGwTcQi'
    'NCKdxdw+qt/JLGbxkD7GdtnU5fH56Xnfbu3l53nNv+utXbe9nPX9+nHm2i71ddubLrRly7ev'
    'pGd+m4/m8vhjPv78PWob2lLXe36Z3+rlV9frTXefk6+lvh9zrue8v9ZmAjitK5u6l/+GYrjP'
    'WNavTwMoQACbKYwUIIweFwoQFo+FAoTisVKAUNlMsaMAsfMYKEAMHiMFiNFjoQDRl4orBYgr'
    'm6kPFKD3uf1IAXqvaogUYPClrKMA5vtapACm0Z4CWO9xoAA2eDQKYOYxUQBLHkcKYL6vLRTA'
    '/DYsUwDLHgsFMD+RVQpgfjm2UgDzAyZQgOTXngIFSH7e1FOA5DWngQIkrzk9UID04HGkAMmL'
    'TDMFSLM64PtXezN4V303UZs/zrPuN7WeWstbatvrv+48rofPautemk/6lri+CmVuZHN0cmVh'
    'bQplbmRvYmoKMTUgMCBvYmoKPDwvVHlwZS9NZXRhZGF0YQovU3VidHlwZS9YTUwvTGVuZ3Ro'
    'IDE0NTc+PnN0cmVhbQo8P3hwYWNrZXQgYmVnaW49J++7vycgaWQ9J1c1TTBNcENlaGlIenJl'
    'U3pOVGN6a2M5ZCc/Pgo8P2Fkb2JlLXhhcC1maWx0ZXJzIGVzYz0iQ1JMRiI/Pgo8eDp4bXBt'
    'ZXRhIHhtbG5zOng9J2Fkb2JlOm5zOm1ldGEvJyB4OnhtcHRrPSdYTVAgdG9vbGtpdCAyLjku'
    'MS0xMywgZnJhbWV3b3JrIDEuNic+CjxyZGY6UkRGIHhtbG5zOnJkZj0naHR0cDovL3d3dy53'
    'My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIycgeG1sbnM6aVg9J2h0dHA6Ly9ucy5h'
    'ZG9iZS5jb20vaVgvMS4wLyc+CjxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiIHhtbG5z'
    'OnBkZj0naHR0cDovL25zLmFkb2JlLmNvbS9wZGYvMS4zLycgcGRmOlByb2R1Y2VyPSdHUEwg'
    'R2hvc3RzY3JpcHQgMTAuMDguMCcvPgo8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4'
    'bWxuczp4bXA9J2h0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8nPjx4bXA6TW9kaWZ5RGF0'
    'ZT4yMDI2LTExLTExVDEyOjE1OjI2KzAzOjAwPC94bXA6TW9kaWZ5RGF0ZT4KPHhtcDpDcmVh'
    'dGVEYXRlPjIwMjYtMTEtMTFUMTI6MTU6MjYrMDM6MDA8L3htcDpDcmVhdGVEYXRlPgo8eG1w'
    'Ok1ldGFkYXRhRGF0ZT4yMDI2LTExLTExVDEyOjE1OjI2KzAzOjAwPC94bXA6TWV0YWRhdGFE'
    'YXRlPgo8eG1wOkNyZWF0b3JUb29sPidVbmtub3duQXBwbGljYXRpb24nPC94bXA6Q3JlYXRv'
    'clRvb2w+PC9yZGY6RGVzY3JpcHRpb24+CjxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIi'
    'IHhtbG5zOnhtcE1NPSdodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vJyB4bXBNTTpE'
    'b2N1bWVudElEPSd1dWlkOmZiMzc1ODRkLTE1Y2MtMTFmZC0wMDAwLTIzN2RmYWUxYzJhOScv'
    'Pgo8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczp4bXBNTT0naHR0cDovL25z'
    'LmFkb2JlLmNvbS94YXAvMS4wL21tLycgeG1wTU06UmVuZGl0aW9uQ2xhc3M9J2RlZmF1bHQn'
    'Lz4KPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wTU09J2h0dHA6Ly9u'
    'cy5hZG9iZS5jb20veGFwLzEuMC9tbS8nIHhtcE1NOlZlcnNpb25JRD0nMScvPgo8cmRmOkRl'
    'c2NyaXB0aW9uIHJkZjphYm91dD0iIiB4bWxuczpkYz0naHR0cDovL3B1cmwub3JnL2RjL2Vs'
    'ZW1lbnRzLzEuMS8nIGRjOmZvcm1hdD0nYXBwbGljYXRpb24vcGRmJz48ZGM6dGl0bGU+PHJk'
    'ZjpBbHQ+PHJkZjpsaSB4bWw6bGFuZz0neC1kZWZhdWx0Jz4nVW50aXRsZWQnPC9yZGY6bGk+'
    'PC9yZGY6QWx0PjwvZGM6dGl0bGU+PC9yZGY6RGVzY3JpcHRpb24+CjwvcmRmOlJERj4KPC94'
    'OnhtcG1ldGE+CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg'
    'ICAgICAgICAgICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgICAgICAg'
    'ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAKPD94cGFj'
    'a2V0IGVuZD0ndyc/PgplbmRzdHJlYW0KZW5kb2JqCjggMCBvYmoKPDwvRmlsdGVyL0ZsYXRl'
    'RGVjb2RlCi9UeXBlL09ialN0bQovTiA2Ci9GaXJzdCAzMS9MZW5ndGggMTc5Pj5zdHJlYW0K'
    'eJx9jM0KgkAURvfzFN/OJOjeO6ZTIS4qqkVB9PMApgMJ4YhOQW8fQ7sWfbtzOHwZGHNMIRoy'
    'gyTQAoMkhYawQIxWeU4nowwYp6JQc/Mj8pyW5WA3rvW0s4+X9U1V0sVd26ZytYVMQ0iXd2cp'
    'RIrOz5sPFJR8H469q5+V7Ufb4x7buxv8UPVN5yE84dmEY0Wr3pa+ce269Ha0XmjWmYRpSXU2'
    '5iRijmJFB1f/LYriAxgHPrwKZW5kc3RyZWFtCmVuZG9iagoxNiAwIG9iago8PAovVHlwZSAv'
    'WFJlZgovU2l6ZSAxNwovUm9vdCAxIDAgUiAvSW5mbyAyIDAgUgovSUQgWzwyNTNBMDlEQTY2'
    'NUZCNkExOEU3OTYxNkY3RkYyMTIzNT48MjUzQTA5REE2NjVGQjZBMThFNzk2MTZGN0ZGMjEy'
    'MzU+XQovSW5kZXggWzAgMTcgXQovVyBbMSAyIDJdCi9GaWx0ZXIgL0ZsYXRlRGVjb2RlL0xl'
    'bmd0aCA2OQo+PgpzdHJlYW0KeJwlirENgDAQxOx/IiFBjxiBipKKcdiBUVmEOiiksc4nA7Wa'
    'BwQjxXhBH5Czfz8Gp6Uvjasle9doSPMGywrOG3xnpwYiCmVuZHN0cmVhbQplbmRvYmoKc3Rh'
    'cnR4cmVmCjMxMTMKJSVFT0YK';
