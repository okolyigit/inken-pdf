import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_200.dart';

import '../../l10n/app_localizations.dart';
import '../../platform/link_opener.dart';
import '../../theme/tokens.dart';
import 'app_info.dart';

/// Hata bildirimlerinin e-posta adresi.
const feedbackEmail = 'ockyapps@gmail.com';

/// Hata bildirme yolu.
enum BugReportChannel { github, email }

/// Bildirimin gövdesi: doldurulacak başlıklar ve altında uygulama bilgileri.
/// Uygulama ağa bağlanmaz; bildirim kullanıcının tarayıcısında ya da e-posta
/// uygulamasında, kendi gönderdiği bir metin olarak açılır.
String bugReportBody(AppLocalizations l10n, String infoText) => [
  '## ${l10n.bugReportWhat}',
  '',
  '',
  '## ${l10n.bugReportExpected}',
  '',
  '',
  '## ${l10n.bugReportSteps}',
  '',
  '',
  '---',
  infoText,
].join('\n');

/// GitHub'da yeni hata kaydı sayfası, gövde doldurulmuş.
Uri githubIssueUri(String body) => Uri.parse(
  '$repositoryUrl/issues/new?body=${Uri.encodeQueryComponent(body)}',
);

/// `mailto:` bağlantısı. Boşluklar `%20` olarak kodlanır: `queryParameters`
/// `+` üretir ve e-posta uygulamaları onu düz `+` gösterir.
Uri mailtoUri({required String subject, required String body}) => Uri.parse(
  'mailto:$feedbackEmail'
  '?subject=${Uri.encodeComponent(subject)}'
  '&body=${Uri.encodeComponent(body)}',
);

/// "Hata bildir": GitHub mı e-posta mı diye sorar, seçileni açar.
/// Açılamazsa bildirim metni (e-postada adresle birlikte) panoya kopyalanır.
Future<void> reportBug(BuildContext context, String infoText) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final open = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(linkOpenerProvider);
  final channel = await showDialog<BugReportChannel>(
    context: context,
    builder: (context) => const _BugReportDialog(),
  );
  if (channel == null) return;
  final body = bugReportBody(l10n, infoText);
  final ok = await open(switch (channel) {
    BugReportChannel.github => githubIssueUri(body),
    BugReportChannel.email => mailtoUri(
      subject: l10n.bugReportSubject,
      body: body,
    ),
  });
  if (ok) return;
  await Clipboard.setData(
    ClipboardData(
      text: switch (channel) {
        BugReportChannel.github => body,
        BugReportChannel.email => '$feedbackEmail\n\n$body',
      },
    ),
  );
  messenger?.showSnackBar(
    SnackBar(
      content: Text(switch (channel) {
        BugReportChannel.github => l10n.bugReportCopiedGitHub(repositoryUrl),
        BugReportChannel.email => l10n.bugReportCopiedEmail(feedbackEmail),
      }),
    ),
  );
}

class _BugReportDialog extends StatelessWidget {
  const _BugReportDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey('bug-report-dialog'),
      title: Text(l10n.bugReportTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChannelTile(
              key: const ValueKey('bug-report-email'),
              icon: LucideIcons200.mail,
              title: l10n.bugReportEmail,
              hint: l10n.bugReportEmailHint(feedbackEmail),
              channel: BugReportChannel.email,
            ),
            const SizedBox(height: Space.s2),
            _ChannelTile(
              key: const ValueKey('bug-report-github'),
              icon: LucideIcons200.gitBranch,
              title: l10n.bugReportGitHub,
              hint: l10n.bugReportGitHubHint,
              channel: BugReportChannel.github,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bug-report-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.channel,
  });

  final IconData icon;
  final String title;
  final String hint;
  final BugReportChannel channel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceWell,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        hoverColor: c.surfaceHover,
        onTap: () => Navigator.pop(context, channel),
        child: Padding(
          padding: const EdgeInsets.all(Space.s3),
          child: Row(
            children: [
              Icon(icon, color: c.ink),
              const SizedBox(width: Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: InkenText.menu.copyWith(color: c.ink)),
                    Text(
                      hint,
                      style: InkenText.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
