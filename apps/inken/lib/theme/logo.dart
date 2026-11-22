import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inken uygulama ikonu (tasarım sistemi → AppIcon). Renkleri sabittir,
/// temaya göre değişmez. Her boyutta aynı çizim ("PDF" etiketli ana ikon).
class InkenLogo extends StatelessWidget {
  const InkenLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/inken-app-icon.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
