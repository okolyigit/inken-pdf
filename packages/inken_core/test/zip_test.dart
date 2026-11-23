import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:inken_core/inken_core.dart';
import 'package:test/test.dart';

void main() {
  test('crc32 bilinen değerler', () {
    expect(crc32(utf8.encode('')), 0);
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
    expect(
      crc32(utf8.encode('The quick brown fox jumps over the lazy dog')),
      0x414FA339,
    );
  });

  final entries = <ZipEntry>[
    (name: 'ders - sayfa 1.png', bytes: Uint8List.fromList([1, 2, 3, 4])),
    (
      name: 'ödev - sayfa 2.png',
      bytes: Uint8List.fromList(utf8.encode('çğıöşü')),
    ),
    (name: 'boş.png', bytes: Uint8List(0)),
  ];

  test('yapı: yerel başlıklar, merkez dizin, son kayıt', () {
    final zip = storeZip(entries, modified: DateTime(2026, 11, 23, 10, 30));
    final data = ByteData.sublistView(zip);
    expect(data.getUint32(0, Endian.little), 0x04034b50);
    final end = zip.length - 22;
    expect(data.getUint32(end, Endian.little), 0x06054b50);
    expect(data.getUint16(end + 10, Endian.little), 3, reason: 'kayıt sayısı');
    final centralSize = data.getUint32(end + 12, Endian.little);
    final centralOffset = data.getUint32(end + 16, Endian.little);
    expect(centralOffset + centralSize, end);
    expect(data.getUint32(centralOffset, Endian.little), 0x02014b50);
  });

  test('sistem arşiv açıcısı içeriği bire bir çıkarır', () async {
    final python = await _which('python3');
    if (python == null) {
      markTestSkipped('python3 yok');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('inken_zip');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.zip')..writeAsBytesSync(storeZip(entries));
    final r = await Process.run(python, [
      '-I',
      '-c',
      'import json,sys,zipfile\n'
          'z=zipfile.ZipFile(sys.argv[1])\n'
          'assert z.testzip() is None\n'
          'print(json.dumps({n: list(z.read(n)) for n in z.namelist()}))',
      file.path,
    ], stdoutEncoding: utf8);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final got = (jsonDecode(r.stdout as String) as Map)
        .cast<String, List<dynamic>>();
    expect(got.keys, entries.map((e) => e.name));
    for (final e in entries) {
      expect(got[e.name], e.bytes);
    }
  });

  test('geçersiz ya da tekrarlanan ad hata verir', () {
    final b = Uint8List(1);
    expect(() => storeZip([(name: '', bytes: b)]), throwsArgumentError);
    expect(() => storeZip([(name: '/a', bytes: b)]), throwsArgumentError);
    expect(
      () => storeZip([(name: 'a', bytes: b), (name: 'a', bytes: b)]),
      throwsArgumentError,
    );
  });

  test('boş arşiv yalnızca son kayıttır', () {
    expect(storeZip(const <ZipEntry>[]).length, 22);
  });
}

Future<String?> _which(String name) async {
  try {
    final r = await Process.run('which', [name]);
    return r.exitCode == 0 ? (r.stdout as String).trim() : null;
  } on ProcessException {
    return null;
  }
}
