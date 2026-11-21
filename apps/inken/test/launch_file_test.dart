import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/files/launch_file.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('inken_launch'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('ilk var olan dosya; seçenekler ve olmayanlar atlanır', () async {
    final pdf = File('${dir.path}/ders notu.pdf')..writeAsStringSync('x');
    final l = LaunchFile.fromArgs([
      '--verbose',
      '${dir.path}/yok.pdf',
      pdf.path,
    ]);
    final first = await l.take();
    expect(first?.location, pdf.path);
    expect(first?.name, 'ders notu.pdf');
    expect(first?.writable, isTrue);
    expect(await l.take(), isNull, reason: 'bir kez verilir');
  });

  test('file:// URI çözülür', () async {
    final pdf = File('${dir.path}/ö ü.pdf')..writeAsStringSync('x');
    final l = LaunchFile.fromArgs([pdf.uri.toString()]);
    expect((await l.take())?.location, pdf.path);
  });

  test('argüman yoksa null', () async {
    expect(await LaunchFile.fromArgs(const []).take(), isNull);
  });
}
