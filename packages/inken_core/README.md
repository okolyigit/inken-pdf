# inken_core

Inken PDF'in çizim modeli, saf Dart (Flutter'a bağımlı değil):

- `InkenDocument` / `PageLayer` / `InkItem` (çizgi, şekil, metin, görsel) — freezed.
- Geri al / yinele (`EditHistory` ve komutlar), silgi kesişimi, seçim geometrisi.
- `inken.json` kodlama / çözme ve sürüm dönüştürücüleri (`docs/format.md`).
- PDF açıklamalarının görünüm akışları (`appearanceFor`); metin için DejaVu Sans harf şekilleri (`TextFont`).

Koordinatlar sayfa uzayında: pt, orijin sol üst, y aşağı.

```sh
dart test
dart run build_runner build   # freezed / json kodu
```
