import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken_core/inken_core.dart';

InkenBackup _backup(String path, DateTime savedAt) => InkenBackup(
  sourcePath: path,
  sourceLength: 10,
  sourceModified: DateTime.utc(2026),
  savedAt: savedAt,
  document: InkenDocument.forPdf(const [(width: 595, height: 842)]),
);

void main() {
  late Directory dir;
  late BackupStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('inken_backup');
    store = BackupStore.at(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'yaz, listele (en yenisi önce), aynı dosyanın yedeği üstüne yazılır',
    () async {
      await store.write(_backup('/a/ders.pdf', DateTime.utc(2026, 1, 1)));
      await store.write(_backup('/b/ders.pdf', DateTime.utc(2026, 1, 2)));
      await store.write(_backup('/a/ders.pdf', DateTime.utc(2026, 1, 3)));
      final list = await store.list();
      expect(list.map((b) => b.sourcePath), ['/a/ders.pdf', '/b/ders.pdf']);
      expect(list.first.savedAt, DateTime.utc(2026, 1, 3));
      expect(dir.listSync(), hasLength(2), reason: 'geçici dosya kalmamalı');
    },
  );

  test('sil', () async {
    await store.write(_backup('/a/ders.pdf', DateTime.utc(2026)));
    await store.delete('/a/ders.pdf');
    await store.delete('/yok.pdf');
    expect(await store.list(), isEmpty);
  });

  test('okunamayan yedek atlanır ve silinir', () async {
    File('${dir.path}/bozuk.json').writeAsStringSync('{');
    await store.write(_backup('/a/ders.pdf', DateTime.utc(2026)));
    expect(await store.list(), hasLength(1));
    expect(File('${dir.path}/bozuk.json').existsSync(), isFalse);
  });

  test('yedek adı yoldan; kararlı ve yola özgü', () {
    expect(backupKey('/a/ders.pdf'), backupKey('/a/ders.pdf'));
    expect(backupKey('/a/ders.pdf'), isNot(backupKey('/b/ders.pdf')));
    expect(backupKey('/a/öğrenci.pdf'), matches(RegExp(r'^[0-9a-f]{16}$')));
  });
}
