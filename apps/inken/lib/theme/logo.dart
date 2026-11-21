import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inken uygulama ikonu (tasarım sistemi → AppIcon). Renkleri sabittir,
/// temaya göre değişmez. 48px'in altında sadeleştirilmiş çizim kullanılır:
/// ana ikonun ince yarığı küçük boyda kaybolur.
class InkenLogo extends StatelessWidget {
  const InkenLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    size < 48
        ? 'assets/brand/inken-small.svg'
        : 'assets/brand/inken-app-icon.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
