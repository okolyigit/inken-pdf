import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inken_pdf/inken_pdf.dart';

void main() {
  test('gösterilen sürümler pubspec\'teki sabitlemelerle aynı', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('pdfrx: $pdfrxVersion\n'));
    expect(pubspec, contains('pdfium_dart: $pdfiumDartVersion\n'));
  });
}
