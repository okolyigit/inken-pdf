import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dış adresi (web, e-posta) sistemin uygulamasında açar; açılamazsa
/// `false`. Testler sahtesiyle değiştirir.
typedef LinkOpener = Future<bool> Function(Uri url);

final linkOpenerProvider = Provider<LinkOpener>((ref) => _launch);

Future<bool> _launch(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
