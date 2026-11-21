# inken (uygulama)

Inken PDF'in Flutter uygulaması: arayüz, araçlar, açma / kaydetme akışı, platform kanalları (`inken/print`, `inken/clipboard`, `inken/documents`, `inken/window`).

- `lib/features/` — özellikler (çizim katmanı, görüntüleyici, dosyalar, yedek, ayarlar, sunum örtüleri).
- `lib/theme/` — tasarım sistemi token'ları (`tokens.dart`), tema, arayüz boyutu.
- `lib/l10n/` — Türkçe (şablon) ve İngilizce metinler.
- `integration_test/` — gerçek uygulamada testler: `flutter test integration_test/<ad>_test.dart -d linux` (dosyaları tek tek çalıştırın). `INKEN_SHOT=<klasör>` ekran görüntüsü yazar.
