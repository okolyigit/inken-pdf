import 'geometry.dart';
import 'image_edit.dart';
import 'model.dart';
import 'pages.dart';

/// Belge üzerinde geri alınabilir tek bir değişiklik.
sealed class EditCommand {
  const EditCommand();
  InkenDocument apply(InkenDocument doc);
  InkenDocument revert(InkenDocument doc);
}

InkenDocument _withPage(
  InkenDocument doc,
  int pageIndex,
  List<InkItem> Function(List<InkItem> items) change,
) {
  final pages = [...doc.pages];
  final page = pages[pageIndex];
  pages[pageIndex] = page.copyWith(items: change(page.items));
  return doc.copyWith(pages: pages);
}

/// Sayfanın sonuna (en üste) öğe ekler.
class AddItems extends EditCommand {
  const AddItems(this.pageIndex, this.items);
  final int pageIndex;
  final List<InkItem> items;

  @override
  InkenDocument apply(InkenDocument doc) =>
      _withPage(doc, pageIndex, (old) => [...old, ...items]);

  @override
  InkenDocument revert(InkenDocument doc) {
    final ids = {for (final i in items) i.id};
    return _withPage(
      doc,
      pageIndex,
      (old) => [
        for (final i in old)
          if (!ids.contains(i.id)) i,
      ],
    );
  }
}

/// Öğeleri siler; geri alınca her biri eski sırasına döner.
class RemoveItems extends EditCommand {
  const RemoveItems._(this.pageIndex, this.removed);

  /// [ids] içinden sayfada bulunanları siler.
  factory RemoveItems(InkenDocument doc, int pageIndex, Set<String> ids) {
    final items = doc.pages[pageIndex].items;
    return RemoveItems._(pageIndex, {
      for (final (i, item) in items.indexed)
        if (ids.contains(item.id)) i: item,
    });
  }

  final int pageIndex;

  /// Silinen öğeler, silinmeden önceki sıra numaralarıyla.
  final Map<int, InkItem> removed;

  bool get isEmpty => removed.isEmpty;

  @override
  InkenDocument apply(InkenDocument doc) {
    final ids = {for (final i in removed.values) i.id};
    return _withPage(
      doc,
      pageIndex,
      (old) => [
        for (final i in old)
          if (!ids.contains(i.id)) i,
      ],
    );
  }

  @override
  InkenDocument revert(InkenDocument doc) => _withPage(doc, pageIndex, (old) {
    final result = [...old];
    final indices = removed.keys.toList()..sort();
    for (final i in indices) {
      result.insert(i.clamp(0, result.length), removed[i]!);
    }
    return result;
  });
}

/// Bir öğeyi aynı kimlikli yeni haliyle değiştirir (taşı, boyutlandır, renk).
class ReplaceItem extends EditCommand {
  const ReplaceItem(this.pageIndex, this.before, this.after)
    : assert(before != after);
  final int pageIndex;
  final InkItem before;
  final InkItem after;

  InkenDocument _swap(InkenDocument doc, InkItem from, InkItem to) => _withPage(
    doc,
    pageIndex,
    (old) => [
      for (final i in old)
        if (i.id == from.id) to else i,
    ],
  );

  @override
  InkenDocument apply(InkenDocument doc) => _swap(doc, before, after);

  @override
  InkenDocument revert(InkenDocument doc) => _swap(doc, after, before);
}

/// Öğeleri (dx, dy) kadar taşır; sıraları ve kimlikleri değişmez.
/// Geri alma, kaydırmayı tersine çevirmek yerine eski öğeleri geri koyar
/// (kayan nokta yuvarlaması birikmesin).
class MoveItems extends EditCommand {
  const MoveItems._(this.pageIndex, this.before, this.dx, this.dy);

  /// [ids] içinden sayfada bulunanları taşır.
  factory MoveItems(
    InkenDocument doc,
    int pageIndex,
    Set<String> ids,
    double dx,
    double dy,
  ) => MoveItems._(
    pageIndex,
    {
      for (final item in doc.pages[pageIndex].items)
        if (ids.contains(item.id)) item.id: item,
    },
    dx,
    dy,
  );

  final int pageIndex;

  /// Taşınan öğelerin taşınmadan önceki halleri.
  final Map<String, InkItem> before;
  final double dx;
  final double dy;

  @override
  InkenDocument apply(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [
      for (final i in old)
        if (before[i.id] case final b?) translateItem(b, dx, dy) else i,
    ],
  );

  @override
  InkenDocument revert(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [for (final i in old) before[i.id] ?? i],
  );
}

/// Öğeleri (ox, oy) sabit kalacak biçimde [scale] katı ölçekler
/// ([scaleItem]); sıraları ve kimlikleri değişmez. Geri alma eski öğeleri
/// geri koyar.
class ScaleItems extends EditCommand {
  const ScaleItems._(
    this.pageIndex,
    this.before,
    this.scale,
    this.ox,
    this.oy,
    this.scaleY,
  );

  /// [ids] içinden sayfada bulunanları ölçekler. [scaleY] verilirse
  /// dikeyde ayrı ölçek (orantısız, kenar tutamakları).
  factory ScaleItems(
    InkenDocument doc,
    int pageIndex,
    Set<String> ids,
    double scale,
    double ox,
    double oy, {
    double? scaleY,
  }) => ScaleItems._(
    pageIndex,
    {
      for (final item in doc.pages[pageIndex].items)
        if (ids.contains(item.id)) item.id: item,
    },
    scale,
    ox,
    oy,
    scaleY,
  );

  final int pageIndex;
  final Map<String, InkItem> before;
  final double scale;
  final double? scaleY;
  final double ox;
  final double oy;

  @override
  InkenDocument apply(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [
      for (final i in old)
        if (before[i.id] case final b?)
          scaleItem(b, scale, ox, oy, scaleY)
        else
          i,
    ],
  );

  @override
  InkenDocument revert(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [for (final i in old) before[i.id] ?? i],
  );
}

/// Öğelerin rengini değiştirir ([recolorItem]); sıraları ve kimlikleri
/// değişmez. Geri alma eski öğeleri geri koyar.
class RecolorItems extends EditCommand {
  const RecolorItems._(this.pageIndex, this.before, this.color);

  /// [ids] içinden sayfada bulunan ve rengi olanları boyar.
  factory RecolorItems(
    InkenDocument doc,
    int pageIndex,
    Set<String> ids,
    int color,
  ) => RecolorItems._(pageIndex, {
    for (final item in doc.pages[pageIndex].items)
      if (ids.contains(item.id) && hasColor(item)) item.id: item,
  }, color);

  final int pageIndex;
  final Map<String, InkItem> before;
  final int color;

  bool get isEmpty => before.isEmpty;

  @override
  InkenDocument apply(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [
      for (final i in old)
        if (before[i.id] case final b?) recolorItem(b, color) else i,
    ],
  );

  @override
  InkenDocument revert(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [for (final i in old) before[i.id] ?? i],
  );
}

/// Seçili metin ve görsellerin opaklığını [opacity] (0–1) yapar.
class SetOpacity extends EditCommand {
  const SetOpacity._(this.pageIndex, this.before, this.opacity);

  /// [ids] içinden sayfada bulunan ve opaklığı olanlara; zaten o
  /// opaklıktakiler atlanır.
  factory SetOpacity(
    InkenDocument doc,
    int pageIndex,
    Set<String> ids,
    double opacity,
  ) => SetOpacity._(pageIndex, {
    for (final item in doc.pages[pageIndex].items)
      if (ids.contains(item.id) &&
          hasOpacity(item) &&
          withOpacity(item, opacity) != item)
        item.id: item,
  }, opacity);

  final int pageIndex;
  final Map<String, InkItem> before;
  final double opacity;

  bool get isEmpty => before.isEmpty;

  @override
  InkenDocument apply(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [
      for (final i in old)
        if (before[i.id] case final b?) withOpacity(b, opacity) else i,
    ],
  );

  @override
  InkenDocument revert(InkenDocument doc) => _withPage(
    doc,
    pageIndex,
    (old) => [for (final i in old) before[i.id] ?? i],
  );
}

/// Öğeleri [fromPage]'den [toPage]'e (dx, dy) kaydırarak taşır (sayfalar
/// arası sürükleme). Hedefte en üste, kaynaktaki sıralarıyla eklenir;
/// kimlikleri değişmez. Geri alma kaynakta eski sıralarına koyar.
class TransferItems extends EditCommand {
  TransferItems(
    InkenDocument doc,
    this.fromPage,
    this.toPage,
    Set<String> ids,
    this.dx,
    this.dy,
  ) : assert(fromPage != toPage),
      _remove = RemoveItems(doc, fromPage, ids);

  final int fromPage;
  final int toPage;
  final double dx;
  final double dy;
  final RemoveItems _remove;

  bool get isEmpty => _remove.isEmpty;

  List<InkItem> get _moved => [
    for (final i in (_remove.removed.keys.toList()..sort()))
      translateItem(_remove.removed[i]!, dx, dy),
  ];

  @override
  InkenDocument apply(InkenDocument doc) =>
      AddItems(toPage, _moved).apply(_remove.apply(doc));

  @override
  InkenDocument revert(InkenDocument doc) =>
      _remove.revert(AddItems(toPage, _moved).revert(doc));
}

/// Bir sayfanın öğe listesini toptan değiştirir (piksel silgisi gibi,
/// birçok öğenin bölündüğü işlemler). Geçmiş doğrusal olduğundan geri
/// alınırken sayfa [after] durumundadır.
class SetPageItems extends EditCommand {
  const SetPageItems(this.pageIndex, this.before, this.after);
  final int pageIndex;
  final List<InkItem> before;
  final List<InkItem> after;

  @override
  InkenDocument apply(InkenDocument doc) =>
      _withPage(doc, pageIndex, (_) => after);

  @override
  InkenDocument revert(InkenDocument doc) =>
      _withPage(doc, pageIndex, (_) => before);
}

/// [index] konumuna yeni sayfa ekler.
class InsertPage extends EditCommand {
  const InsertPage(this.index, this.page);
  final int index;
  final PageLayer page;

  @override
  InkenDocument apply(InkenDocument doc) =>
      doc.copyWith(pages: [...doc.pages]..insert(index, page));

  @override
  InkenDocument revert(InkenDocument doc) =>
      doc.copyWith(pages: [...doc.pages]..removeAt(index));
}

/// [index] konumundaki sayfayı (çizimleriyle) siler. Dosyadan gelen sayfa
/// kayıtta dosyadan da silinir; geri alınınca çizimleriyle geri gelir.
class RemovePage extends EditCommand {
  const RemovePage(this.index, this.page);
  final int index;
  final PageLayer page;

  @override
  InkenDocument apply(InkenDocument doc) =>
      doc.copyWith(pages: [...doc.pages]..removeAt(index));

  @override
  InkenDocument revert(InkenDocument doc) =>
      doc.copyWith(pages: [...doc.pages]..insert(index, page));
}

/// [indexes] sayfalarını (çizimleriyle) birlikte siler; tek geri alma
/// adımıdır. Geri alınınca hepsi eski yerlerine döner.
class RemovePages extends EditCommand {
  RemovePages(InkenDocument doc, Iterable<int> indexes)
    : _removed = {for (final i in indexes.toSet()) i: doc.pages[i]};

  final Map<int, PageLayer> _removed;

  @override
  InkenDocument apply(InkenDocument doc) => doc.copyWith(
    pages: [
      for (final (i, p) in doc.pages.indexed)
        if (!_removed.containsKey(i)) p,
    ],
  );

  @override
  InkenDocument revert(InkenDocument doc) {
    final pages = [...doc.pages];
    for (final i in _removed.keys.toList()..sort()) {
      pages.insert(i, _removed[i]!);
    }
    return doc.copyWith(pages: pages);
  }
}

/// [indexes] sayfalarını [turns] çeyrek tur saat yönünde (negatif: ters)
/// döndürür ([rotatePage]); tek geri alma adımıdır. Önceki ve sonraki
/// sayfalar saklanır: geri alma, ters döndürmenin kayan nokta hatası
/// olmadan eski hali verir.
class RotatePages extends EditCommand {
  RotatePages(InkenDocument doc, Iterable<int> indexes, int turns)
    : _before = {for (final i in indexes) i: doc.pages[i]},
      _after = {for (final i in indexes) i: rotatePage(doc.pages[i], turns)};

  final Map<int, PageLayer> _before;
  final Map<int, PageLayer> _after;

  InkenDocument _set(InkenDocument doc, Map<int, PageLayer> pages) => doc
      .copyWith(pages: [for (final (i, p) in doc.pages.indexed) pages[i] ?? p]);

  @override
  InkenDocument apply(InkenDocument doc) => _set(doc, _after);

  @override
  InkenDocument revert(InkenDocument doc) => _set(doc, _before);
}

/// Belgenin tamamını değiştirir (yedekten kurtarma gibi); tek geri alma
/// adımıdır.
class ReplaceDocument extends EditCommand {
  const ReplaceDocument(this.before, this.after);
  final InkenDocument before;
  final InkenDocument after;

  @override
  InkenDocument apply(InkenDocument doc) => after;

  @override
  InkenDocument revert(InkenDocument doc) => before;
}

/// Belgenin güncel hali ile geri al / yinele yığınları.
class EditHistory {
  /// [dirty]: belge kaydedilmemiş değişiklikle başlar (kayıt sürerken
  /// yapılan değişiklikler yeni sayfa numaralarına taşındığında).
  EditHistory(this._document, {this.limit = 500, bool dirty = false})
    : _savedRevision = dirty ? -1 : 0;

  /// Tutulacak en fazla geri alma adımı.
  final int limit;

  InkenDocument _document;
  final List<EditCommand> _undo = [];
  final List<EditCommand> _redo = [];
  int _revision = 0;
  int _savedRevision;

  InkenDocument get document => _document;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Son [markSaved] çağrısından beri değişiklik var mı?
  bool get isDirty => _revision != _savedRevision;

  /// Her değişiklikte farklılaşan sayaç (önbellek anahtarı olarak kullanılır).
  int get revision => _revision;

  void execute(EditCommand command) {
    _document = command.apply(_document);
    _undo.add(command);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
    _revision++;
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    final command = _undo.removeLast();
    _document = command.revert(_document);
    _redo.add(command);
    _revision++;
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final command = _redo.removeLast();
    _document = command.apply(_document);
    _undo.add(command);
    _revision++;
    return true;
  }

  void markSaved() => _savedRevision = _revision;
}
