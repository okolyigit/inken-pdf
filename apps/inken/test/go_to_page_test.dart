import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/viewer/go_to_page.dart';

void main() {
  test('sayfa numarası: 1 tabanlı girdi, aralığa çekilir', () {
    expect(parsePageInput('3', 12), 2);
    expect(parsePageInput(' 12 ', 12), 11);
    expect(parsePageInput('99', 12), 11);
    expect(parsePageInput('0', 12), 0);
    expect(parsePageInput('', 12), isNull);
    expect(parsePageInput('a', 12), isNull);
    expect(parsePageInput('1', 0), isNull);
  });
}
