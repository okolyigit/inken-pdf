import 'package:flutter/material.dart';

import 'tokens.dart';

/// Pencerelerdeki (yazdırma, dışa aktarma) sıkı form düzeni: etiket solda
/// [FormRow.labelWidth] genişlikte sütunda, denetim sağda; satır en az
/// [FormRow.height]; telefonda etiket üstte. Pencere tek ekrana sığsın diye araç kutusundaki 48 px
/// dokunma alanından küçük (kullanıcı kararı, 23 Kasım 2026).
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.below,
  });

  static const double labelWidth = 104;
  static const double height = 40;

  final String label;
  final Widget child;

  /// Denetimin altında soluk kısa açıklama.
  final String? hint;

  /// Denetimin altında ek denetim (ör. sayfa aralığı kutusu).
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelText = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: InkenText.label.copyWith(
        color: c.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
        ?below,
        if (hint case final h?)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s1),
            child: Text(
              h,
              style: InkenText.caption.copyWith(color: c.inkMuted),
            ),
          ),
      ],
    );
    // Telefonda etiket sütunu denetimi daraltır: etiket üstte.
    if (InkenLayout.of(context) == InkenLayout.phone) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [if (label.isNotEmpty) labelText, body],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            height: height,
            child: Align(alignment: Alignment.centerLeft, child: labelText),
          ),
          const SizedBox(width: Space.s2),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Sıkı onay kutusu satırı (36 px): kutu ve metin, satırın tamamı dokunulur.
class FormCheck extends StatelessWidget {
  const FormCheck({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => onChanged(!value),
        child: SizedBox(
          height: 36,
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: Space.s1),
              Expanded(
                child: Text(
                  label,
                  style: InkenText.menu.copyWith(color: c.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sıkı açılır liste ve metin kutusu süsü (36 px yükseklik).
const InputDecoration denseFieldDecoration = InputDecoration(
  isDense: true,
  border: OutlineInputBorder(),
  contentPadding: EdgeInsets.symmetric(horizontal: Space.s3, vertical: 8),
);

/// Dokunma alanı küçültülmüş anahtar (form satırında etiketin sağında).
class FormSwitch extends StatelessWidget {
  const FormSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch(
    value: value,
    onChanged: onChanged,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
