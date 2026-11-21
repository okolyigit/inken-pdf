import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';

import 'ink_session.dart';

/// Inken'in kendi panosundaki öğeler (Kopyala / Kes).
///
/// Öğeler uygulamanın içinde tutulur; sistem panosuna yalnızca bir işaret
/// metni ([marker]) yazılır. Yapıştırırken sistem panosunda hâlâ bu işaret
/// varsa öğeler yapıştırılır; arada başka bir uygulamada bir şey (ör. bir
/// görsel) kopyalandıysa işaret gitmiştir ve o yapıştırılır.
class ItemClip {
  ItemClip({
    required this.items,
    required this.images,
    required this.sourcePage,
    required this.sourceSession,
    required this.marker,
  });

  /// Kopyalanan öğeler, sayfadaki sıralarıyla.
  final List<InkItem> items;

  /// Öğelerdeki görsellerin baytları: başka belgeye de yapıştırılabilsin.
  final Map<String, Uint8List> images;

  final int sourcePage;

  /// Kopyalandığı oturum (aynı belge mi diye bakılır).
  final Object sourceSession;

  final String marker;

  /// Aynı yere art arda yapıştırmada her kopya biraz daha kayar.
  int pasteCount = 0;
}

class ItemClipboardNotifier extends Notifier<ItemClip?> {
  @override
  ItemClip? build() => null;

  void set(ItemClip clip) => state = clip;
}

final itemClipboardProvider =
    NotifierProvider<ItemClipboardNotifier, ItemClip?>(
      ItemClipboardNotifier.new,
    );

/// Aynı sayfaya yapıştırılan kopyanın her seferki kayması (pt).
const double pasteOffset = 12;

final Random _random = Random();

/// Seçimi Inken panosuna kopyalar ve sistem panosuna [label] ile başlayan
/// işaret metnini yazar. Seçim yoksa `false`.
Future<bool> copySelection(
  WidgetRef ref,
  InkSession session, {
  required String label,
}) async {
  final page = session.selectionPage;
  final items = session.selectedItems;
  if (page == null || items.isEmpty) return false;
  final marker = '$label · ${_random.nextInt(1 << 32).toRadixString(16)}';
  ref
      .read(itemClipboardProvider.notifier)
      .set(
        ItemClip(
          items: items,
          images: {
            for (final i in items)
              if (i is ImageItem) i.imageId: ?session.images.png(i.imageId),
          },
          sourcePage: page,
          sourceSession: session,
          marker: marker,
        ),
      );
  try {
    await Clipboard.setData(ClipboardData(text: marker));
  } on Object {
    // Sistem panosu yazılamadı; Inken panosu yine geçerli.
  }
  return true;
}

/// Sistem panosunda hâlâ Inken'in işareti mi var? Okunamazsa `null`.
Future<bool?> clipboardHoldsMarker(ItemClip clip) async {
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text == clip.marker;
  } on Object {
    return null;
  }
}

/// [clip]'i [session]'ın [page] sayfasına yapıştırır: görselleri belgeye
/// ekler, aynı belgede aynı sayfaya yapıştırılıyorsa kopyayı kaydırır.
void pasteClip(InkSession session, ItemClip clip, int page) {
  for (final e in clip.images.entries) {
    session.images.add(e.key, e.value);
  }
  final samePlace =
      identical(clip.sourceSession, session) && clip.sourcePage == page;
  final shift = samePlace ? pasteOffset * ++clip.pasteCount : 0.0;
  session.pasteItems(page, clip.items, dx: shift, dy: shift);
}
