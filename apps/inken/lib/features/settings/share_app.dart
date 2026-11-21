import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/share_service.dart';
import 'app_info.dart';

/// Uygulamayı tanıtan, depo bağlantılı paylaşma metni.
String shareAppMessage(AppLocalizations l10n) =>
    l10n.shareAppText(repositoryUrl);

/// Uygulamayı paylaşır: Android'de sistemin paylaşma sayfası; masaüstünde
/// ortak bir paylaşma penceresi olmadığından metin panoya kopyalanır ve
/// bildirilir.
Future<void> shareApp(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sharer = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(shareServiceProvider);
  final text = shareAppMessage(l10n);
  try {
    if (await sharer.shareText(text, subject: l10n.appTitle)) return;
  } on Object {
    // Paylaşma sayfası açılamadı: panoya kopyalanır.
  }
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(SnackBar(content: Text(l10n.shareAppCopied)));
}
