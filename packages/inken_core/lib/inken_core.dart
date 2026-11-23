/// Inken PDF çizim modeli: belge, sayfa katmanı, öğeler, geri al / yinele,
/// silgi kesişimi ve `inken.json` serileştirmesi. Flutter'a bağımlı değildir.
///
/// Koordinat sistemi: **sayfa uzayı**, birim PDF noktası (1/72 inç),
/// orijin sayfanın sol üst köşesi, y aşağı doğru artar. PDF'in sol-alt
/// orijinli uzayına dönüşüm yalnızca `inken_pdf` içinde, yazarken yapılır.
library;

export 'src/appearance.dart';
export 'src/colors.dart';
export 'src/coordinate_plane.dart';
export 'src/export_options.dart';
export 'src/instruments.dart';
export 'src/backup.dart';
export 'src/capture.dart';
export 'src/geometry.dart';
export 'src/history.dart';
export 'src/image_edit.dart';
export 'src/inken_core_base.dart';
export 'src/model.dart';
export 'src/pages.dart';
export 'src/print_layout.dart';
export 'src/serialization.dart';
export 'src/stroke_builder.dart';
export 'src/text_font.dart';
export 'src/text_layout.dart';
export 'src/zip.dart';
