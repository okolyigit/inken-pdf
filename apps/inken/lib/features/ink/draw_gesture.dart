import 'package:flutter/gestures.dart';

/// Tek işaretçiyle çizim hareketi.
///
/// Görüntüleyicinin kaydırma / yakınlaştırma tanıyıcısıyla aynı hareket
/// arenasında yarışır:
///
/// * [accepts] `false` dönerse işaretçiye hiç karışmaz; görüntüleyici alır.
/// * [isDeferred] `false` ise (kalem, fare) arenayı anında kazanır; ilk
///   noktadan itibaren çizilir.
/// * [isDeferred] `true` ise (dokunma) küçük bir hareket bekler. Bu sırada
///   ikinci parmak gelirse çekilir ve iki parmak hareketi görüntüleyiciye
///   kalır. Çizim başladıktan sonra gelen ek dokunuşlar yutulur (avuç).
class DrawGestureRecognizer extends OneSequenceGestureRecognizer {
  DrawGestureRecognizer({
    required this.accepts,
    required this.isDeferred,
    super.debugOwner,
  });

  /// Bu işaretçi çizecek mi?
  bool Function(PointerDownEvent event) accepts;

  /// Kabul etmeden önce hareket beklensin mi?
  bool Function(PointerDownEvent event) isDeferred;

  void Function(PointerEvent event)? onStart;
  void Function(PointerEvent event)? onUpdate;
  void Function(PointerEvent event)? onEnd;
  void Function()? onCancel;

  /// Ertelenmiş kabulde çizimin başlaması için gereken hareket (piksel).
  static const double deferredSlop = 3;

  int? _primary;
  bool _accepted = false;
  bool _started = false;
  final List<PointerEvent> _buffer = [];

  @override
  String get debugDescription => 'draw';

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    // Çizim sürerken gelen her işaretçiyi (avuç) biz alıp yutarız.
    if (_primary != null && _accepted) return true;
    return accepts(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_primary != null) {
      if (_accepted) {
        // Avuç / ikinci dokunuş: yut.
        startTrackingPointer(event.pointer, event.transform);
        resolvePointer(event.pointer, GestureDisposition.accepted);
      } else {
        // Henüz çizmeye başlamadık ve ikinci parmak geldi: iki parmak
        // hareketi. Çekil; yeni işaretçiyi hiç izleme.
        final first = _primary!;
        _reset(cancelled: true);
        resolvePointer(first, GestureDisposition.rejected);
        stopTrackingPointer(first);
      }
      return;
    }
    _primary = event.pointer;
    _accepted = false;
    _started = false;
    _buffer
      ..clear()
      ..add(event);
    startTrackingPointer(event.pointer, event.transform);
    if (!isDeferred(event)) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    }
  }

  void _flush() {
    if (!_accepted || _buffer.isEmpty) return;
    for (final e in _buffer) {
      if (!_started) {
        _started = true;
        onStart?.call(e);
      } else {
        onUpdate?.call(e);
      }
    }
    _buffer.clear();
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _primary) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        stopTrackingPointer(event.pointer);
      }
      return;
    }
    if (event is PointerMoveEvent) {
      if (_accepted) {
        _flush();
        onUpdate?.call(event);
      } else {
        _buffer.add(event);
        final start = _buffer.first.position;
        if ((event.position - start).distance > deferredSlop) {
          resolvePointer(event.pointer, GestureDisposition.accepted);
        }
      }
    } else if (event is PointerUpEvent) {
      if (!_accepted) {
        // Hareketsiz dokunuş: nokta koy ("i"nin noktası, ondalık virgül).
        resolvePointer(event.pointer, GestureDisposition.accepted);
      }
      if (_accepted) {
        _flush();
        if (_started) onEnd?.call(event);
      }
      stopTrackingPointer(event.pointer);
      _reset(cancelled: false);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      _reset(cancelled: true);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer == _primary) {
      _accepted = true;
      _flush();
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == _primary) {
      stopTrackingPointer(pointer);
      _reset(cancelled: true);
    }
  }

  void _reset({required bool cancelled}) {
    final wasStarted = _started;
    _primary = null;
    _accepted = false;
    _started = false;
    _buffer.clear();
    if (cancelled && wasStarted) onCancel?.call();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
