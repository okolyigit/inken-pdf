import 'package:inken_core/inken_core.dart';

void main() {
  final history = EditHistory(
    InkenDocument.forPdf([(width: 595, height: 842)]),
  );
  history.execute(
    AddItems(0, [
      InkItem.stroke(
        id: newItemId(),
        tool: InkTool.pen,
        color: 0xFFDC1E1E,
        width: 2.5,
        points: const [InkPoint(72, 100, 0.4), InkPoint(120, 110, 0.7)],
      ),
    ]),
  );
  print(encodeInkenDocument(history.document));
}
