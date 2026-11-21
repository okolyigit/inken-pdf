import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../settings/settings_store.dart';

/// Yüzen kutular kullanılmayınca soluklaşsın mı (Görünüm menüsü)?
class FloatingFadeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(settingsStoreProvider).get<bool>('fadeFloating') ?? true;

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).put('fadeFloating', on);
  }
}

final floatingFadeProvider = NotifierProvider<FloatingFadeNotifier, bool>(
  FloatingFadeNotifier.new,
);

/// Belgenin üzerinde süzülen bir kutuyu kullanılmadığında soluklaştırır.
///
/// Fare üzerindeyken, dokunulunca, [wakeOn] haber verince (sayfa ya da araç
/// değişti) tam görünür; [Motion.idleAfter] boyunca kullanılmazsa
/// [Opacities.idleFloating]'e iner. Soluk kutu da dokunuşa hemen yanıt
/// verir (önce uyandırmak gerekmez). [keepAwake] (açık panel) sürdükçe
/// soluklaşmaz.
class IdleFade extends ConsumerStatefulWidget {
  const IdleFade({
    super.key,
    required this.child,
    this.wakeOn,
    this.wakeKey,
    this.keepAwake = false,
  });

  final Widget child;
  final Listenable? wakeOn;

  /// Değişince uyandırır (ör. seçili araç klavyeyle değişti).
  final Object? wakeKey;
  final bool keepAwake;

  @override
  ConsumerState<IdleFade> createState() => _IdleFadeState();
}

class _IdleFadeState extends ConsumerState<IdleFade> {
  bool _awake = true;
  bool _hovered = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.wakeOn?.addListener(_wake);
    _scheduleIdle();
  }

  @override
  void didUpdateWidget(IdleFade old) {
    super.didUpdateWidget(old);
    if (old.wakeOn != widget.wakeOn) {
      old.wakeOn?.removeListener(_wake);
      widget.wakeOn?.addListener(_wake);
    }
    if (old.wakeKey != widget.wakeKey) {
      _awake = true;
      _scheduleIdle();
    } else if (old.keepAwake && !widget.keepAwake) {
      _scheduleIdle();
    }
  }

  @override
  void dispose() {
    widget.wakeOn?.removeListener(_wake);
    _timer?.cancel();
    super.dispose();
  }

  void _wake() {
    if (!_awake) setState(() => _awake = true);
    _scheduleIdle();
  }

  void _scheduleIdle() {
    _timer?.cancel();
    _timer = Timer(Motion.idleAfter, () {
      if (!mounted || _hovered || widget.keepAwake) return;
      setState(() => _awake = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(floatingFadeProvider);
    final visible = !enabled || _awake || _hovered || widget.keepAwake;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _wake();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _scheduleIdle();
      },
      child: Listener(
        // Dokunma ekranında üzerine gelme yok: dokunuş uyandırır.
        onPointerDown: (_) => _wake(),
        onPointerUp: (_) => _scheduleIdle(),
        child: AnimatedOpacity(
          opacity: visible ? 1 : Opacities.idleFloating,
          duration: visible ? Motion.fast : Motion.fadeOut,
          curve: Motion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}
