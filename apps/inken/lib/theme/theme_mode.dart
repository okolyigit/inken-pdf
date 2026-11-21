import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_store.dart';

/// Açık (kâğıt) / koyu (gece sınıfı) tema. Varsayılan sistemi izler.
/// Koyu tema yalnızca kromu koyulaştırır; sayfa beyaz kalır.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref
      .read(settingsStoreProvider)
      .getEnum('theme', ThemeMode.values, ThemeMode.system);

  void set(ThemeMode mode) {
    state = mode;
    ref.read(settingsStoreProvider).put('theme', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Şu an koyu tema mı (sistem ayarı dahil)?
bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
