import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inken uygulama ikonu (tasarım sistemi → AppIcon). Renkleri sabittir,
/// temaya göre değişmez. Ekranda 48 fiziksel pikselin altında sadeleştirilmiş
/// çizim kullanılır: ana ikonun "PDF" yazısı ve ince yarığı küçük boyda
/// kaybolur. Karar mantıksal değil fiziksel boyuta göredir; telefonda 32px
/// (≈ 100 fiziksel piksel) ana ikonu gösterir, masaüstünde 1x'te 32px
/// sadeleştirilmiş olanı.
class InkenLogo extends StatelessWidget {
  const InkenLogo({super.key, this.size = 28});

  final double size;

  /// Bu fiziksel boyutun altında sadeleştirilmiş ikon.
  static const smallBelowPhysicalPx = 48.0;

  static String assetFor(double size, double devicePixelRatio) =>
      size * devicePixelRatio < smallBelowPhysicalPx
      ? 'assets/brand/inken-small.svg'
      : 'assets/brand/inken-app-icon.svg';

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetFor(size, MediaQuery.devicePixelRatioOf(context)),
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
