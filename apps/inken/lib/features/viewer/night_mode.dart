import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_store.dart';

/// Gece / okuma modu açık mı; kalıcı (`settings.json`). Açıkken sayfalar
/// koyu zeminde açık yazıyla görünür (`NightMode.pageFilter`), çizimler
/// koyu zeminde okunacak tona çevrilir (`nightInkColor`). Yalnızca
/// ekranda: kaydedilen, yazdırılan ve dışa aktarılan dosya değişmez.
class NightModeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(settingsStoreProvider).get<bool>('nightMode') ?? false;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('nightMode', on);
  }

  void toggle() => set(!state);
}

final nightModeProvider = NotifierProvider<NightModeNotifier, bool>(
  NightModeNotifier.new,
);
