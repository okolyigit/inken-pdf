import 'package:flutter/widgets.dart';
import 'package:inken_pdf/inken_pdf.dart';

/// Çizim katmanının gördüğü sayfa yerleşimi, kapılı.
///
/// Sayfa eklenince / silinince model hemen değişir; görüntüleyici yeni
/// kopyayı ancak worker onu ürettikten ve yeniden yükledikten sonra
/// gösterir. Aradaki kısa sürede modeldeki sayfa numaraları ekrandakilerle
/// uyuşmaz: çizimler yanlış sayfada görünür, girdi yanlış sayfaya düşerdi.
/// Kapı kapalıyken katman hiçbir sayfa görmez (çizmez, girdi almaz).
class LayoutGate extends ChangeNotifier implements PageGeometry {
  LayoutGate(this.inner) {
    inner.addListener(notifyListeners);
  }

  final PageGeometry inner;

  bool _open = true;
  bool get open => _open;
  set open(bool value) {
    if (value == _open) return;
    _open = value;
    notifyListeners();
  }

  @override
  bool get isReady => _open && inner.isReady;

  @override
  List<PageViewport> get visiblePages => _open ? inner.visiblePages : const [];

  @override
  PageViewport? pageAt(Offset local) => _open ? inner.pageAt(local) : null;

  @override
  PageViewport? viewportOf(int index) => _open ? inner.viewportOf(index) : null;

  @override
  void dispose() {
    inner.removeListener(notifyListeners);
    super.dispose();
  }
}
