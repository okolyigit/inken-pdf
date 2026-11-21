import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings_store.dart';

/// Arayüz boyutu: akıllı tahtada (büyük ve yüksek çözünürlüklü ekran,
/// uzaktan bakılır, parmakla dokunulur) her şey orantılı büyür: düğmeler,
/// menüler, paneller, pencereler, dokunma alanları.
enum UiScale {
  normal(1),
  large(1.25),
  larger(1.5);

  const UiScale(this.factor);
  final double factor;
}

/// Seçilen arayüz boyutu; kalıcı (`settings.json` → `uiScale`).
class UiScaleNotifier extends Notifier<UiScale> {
  @override
  UiScale build() => ref
      .read(settingsStoreProvider)
      .getEnum('uiScale', UiScale.values, UiScale.normal);

  void set(UiScale scale) {
    state = scale;
    ref.read(settingsStoreProvider).put('uiScale', scale.name);
  }
}

final uiScaleProvider = NotifierProvider<UiScaleNotifier, UiScale>(
  UiScaleNotifier.new,
);

/// Altındaki her şeyi [scale] katı büyütür. Çocuk, ekranın 1/[scale]'i
/// kadar mantıksal alanda yerleşir (uyarlanabilir yerleşim buna göre
/// karar verir) ve büyütülerek çizilir; dokunuşlar ters dönüşümle iletilir.
/// Ekran yoğunluğu da [scale] katı bildirilir: PDF sayfaları ve görseller
/// büyütüldüğü için bulanıklaşmaz, daha yüksek çözünürlükte çizilir.
class ScaledApp extends StatelessWidget {
  const ScaledApp({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        size: mq.size / scale,
        devicePixelRatio: mq.devicePixelRatio * scale,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
        systemGestureInsets: mq.systemGestureInsets / scale,
      ),
      child: _LayoutScale(scale: scale, child: child),
    );
  }
}

class _LayoutScale extends SingleChildRenderObjectWidget {
  const _LayoutScale({required this.scale, super.child});

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutScale(scale);

  @override
  void updateRenderObject(BuildContext context, _RenderLayoutScale r) {
    r.scale = scale;
  }
}

class _RenderLayoutScale extends RenderProxyBox {
  _RenderLayoutScale(this._scale);

  double _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final c = constraints;
    double div(double v) => v.isFinite ? v / _scale : v;
    child.layout(
      BoxConstraints(
        minWidth: div(c.minWidth),
        maxWidth: div(c.maxWidth),
        minHeight: div(c.minHeight),
        maxHeight: div(c.maxHeight),
      ),
      parentUsesSize: true,
    );
    size = c.constrain(child.size * _scale);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
