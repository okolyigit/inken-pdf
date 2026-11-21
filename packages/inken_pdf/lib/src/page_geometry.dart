import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Bir PDF sayfasının nokta (pt) cinsinden boyutu.
typedef PdfPageSize = ({double width, double height});

/// Bir sayfanın o an ekranda kapladığı yer.
@immutable
class PageViewport {
  const PageViewport({
    required this.index,
    required this.rect,
    required this.scale,
  });

  /// Sayfa sırası (0'dan başlar).
  final int index;

  /// Sayfanın görüntüleyici kutusu içindeki dikdörtgeni (mantıksal piksel).
  final Rect rect;

  /// Sayfa birimi (pt) başına ekran pikseli.
  final double scale;

  /// Görüntüleyici konumunu sayfa uzayına çevirir (pt, orijin sol üst).
  Offset toPage(Offset local) => (local - rect.topLeft) / scale;

  /// Sayfa uzayındaki noktayı görüntüleyici konumuna çevirir.
  Offset toView(Offset page) => rect.topLeft + page * scale;
}

/// Çizim katmanının görüntüleyiciden bilmesi gereken her şey: hangi sayfa
/// ekranda nerede. Kaydırma / yakınlaştırma değişince dinleyicilere haber
/// verir. pdfrx'e bağımlı değildir; testlerde sahte uygulaması kullanılır.
abstract class PageGeometry implements Listenable {
  /// Belge yüklendi ve yerleşim hesaplandı mı?
  bool get isReady;

  /// Ekranda en az bir kısmı görünen sayfalar.
  List<PageViewport> get visiblePages;

  /// [local] konumundaki sayfa; sayfalar arası boşluktaysa `null`.
  PageViewport? pageAt(Offset local);

  /// Sayfa o an yerleşimde varsa konumu (görünür olmasa da).
  PageViewport? viewportOf(int index);
}
