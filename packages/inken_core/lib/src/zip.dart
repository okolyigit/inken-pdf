import 'dart:convert';
import 'dart:typed_data';

/// ZIP arşivindeki bir dosya.
typedef ZipEntry = ({String name, Uint8List bytes});

/// [entries]'i sıkıştırmadan (STORE) tek bir ZIP arşivine yazar: PNG ve
/// JPEG zaten sıkıştırılmış olduğundan sıkıştırma kazandırmaz; bağımlılık
/// gerekmez. Adlar UTF-8'dir (genel amaçlı bit 11); her işletim sisteminin
/// arşiv açıcısı okur. Ad tekrarlanamaz; arşiv 4 GB'tan küçük olmalıdır
/// (ZIP64 yazılmaz).
Uint8List storeZip(List<ZipEntry> entries, {DateTime? modified}) {
  final names = <String>{};
  for (final e in entries) {
    if (e.name.isEmpty || e.name.startsWith('/') || e.name.contains('\\')) {
      throw ArgumentError.value(e.name, 'name', 'geçersiz ad');
    }
    if (!names.add(e.name)) {
      throw ArgumentError.value(e.name, 'name', 'iki kez');
    }
  }
  final (time, date) = _dosTime(modified ?? DateTime.now());
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  for (final e in entries) {
    final name = utf8.encode(e.name);
    final crc = crc32(e.bytes);
    final size = e.bytes.length;
    final offset = out.length;
    if (offset + size > 0xFFFFFFFF) {
      throw StateError('Arşiv 4 GB sınırını aşıyor');
    }
    out
      ..add(_u32(0x04034b50))
      ..add(_u16(20)) // açmak için sürüm 2.0
      ..add(_u16(0x0800)) // UTF-8 adlar
      ..add(_u16(0)) // STORE
      ..add(_u16(time))
      ..add(_u16(date))
      ..add(_u32(crc))
      ..add(_u32(size))
      ..add(_u32(size))
      ..add(_u16(name.length))
      ..add(_u16(0))
      ..add(name)
      ..add(e.bytes);
    central
      ..add(_u32(0x02014b50))
      ..add(_u16(20)) // yazan sürüm
      ..add(_u16(20))
      ..add(_u16(0x0800))
      ..add(_u16(0))
      ..add(_u16(time))
      ..add(_u16(date))
      ..add(_u32(crc))
      ..add(_u32(size))
      ..add(_u32(size))
      ..add(_u16(name.length))
      ..add(_u16(0)) // ek alan
      ..add(_u16(0)) // açıklama
      ..add(_u16(0)) // disk
      ..add(_u16(0)) // iç öznitelikler
      ..add(_u32(0)) // dış öznitelikler
      ..add(_u32(offset))
      ..add(name);
  }
  final centralOffset = out.length;
  final centralBytes = central.takeBytes();
  out
    ..add(centralBytes)
    ..add(_u32(0x06054b50))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(entries.length))
    ..add(_u16(entries.length))
    ..add(_u32(centralBytes.length))
    ..add(_u32(centralOffset))
    ..add(_u16(0));
  return out.takeBytes();
}

/// CRC-32 (IEEE 802.3, ZIP ve PNG'deki).
int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return c ^ 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
}, growable: false);

/// MS-DOS saat ve tarihi (yerel saat, 2 sn çözünürlük, 1980'den önce 1980).
(int, int) _dosTime(DateTime t) {
  if (t.year < 1980) return (0, (1 << 5) | 1);
  final time = (t.hour << 11) | (t.minute << 5) | (t.second ~/ 2);
  final date = ((t.year - 1980) << 9) | (t.month << 5) | t.day;
  return (time, date);
}

Uint8List _u16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);

Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
