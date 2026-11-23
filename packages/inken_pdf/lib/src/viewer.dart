import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'page_geometry.dart';

/// Belgenin dikey kaydırma konumu (sayfa kaydırma çubuğu için). Konum
/// değişince haber verir.
abstract interface class PageScroller implements Listenable {
  /// 0 en üst, 1 en alt; belge ekrana sığıyorsa `null`.
  double? get scrollFraction;

  /// Görünen yüksekliğin belge yüksekliğine oranı.
  double get visibleFraction;

  Future<void> scrollToFraction(double fraction);

  /// Ekranda baskın olan sayfa (0'dan başlar).
  int? get currentPage;
  int get pageCount;
}

/// Belgedeki bir bağlantı: belge içi ([page], 0'dan) ya da dış adres
/// ([url]).
typedef InkenLink = ({int? page, Uri? url});

/// İçindekiler (PDF yer imleri) ağacında bir başlık. [page] 0'dan; hedefi
/// olmayan ya da silinmiş sayfaya giden başlıkta `null`.
class InkenOutlineItem {
  const InkenOutlineItem({
    required this.title,
    this.page,
    this.top,
    this.children = const [],
  });

  final String title;
  final int? page;

  /// Başlığın sayfadaki yeri (sayfanın üstünden pt; hedef `/XYZ` ise),
  /// yoksa `null` (sayfanın başı).
  final double? top;
  final List<InkenOutlineItem> children;
}

/// [InkenPdfViewer]'ı yönetir ve sayfaların ekrandaki konumunu bildirir.
class InkenViewerController extends ChangeNotifier
    implements PageGeometry, PageScroller {
  InkenViewerController() {
    _pdf.addListener(notifyListeners);
  }

  final PdfViewerController _pdf = PdfViewerController();
  bool _ready = false;

  @override
  bool get isReady => _ready && _pdf.isReady;

  /// Sayfa boyutları (pt). Belge hazır değilse boş.
  List<PdfPageSize> get pageSizes => isReady
      ? [for (final p in _pdf.pages) (width: p.width, height: p.height)]
      : const [];

  @override
  int get pageCount => isReady ? _pdf.pageCount : 0;

  /// Ekranda baskın olan sayfa (0'dan başlar): görüş alanında en çok yer
  /// kaplayan; eşitlikte üstteki.
  ///
  /// pdfrx'in `pageNumber`'ı kullanılmaz: kendi geçişimizden ([goToPage])
  /// sonra güncellenmiyor, geçişin ortasındaki bir sayfada kalıyordu
  /// (500 sayfada End sonrası "433").
  @override
  int? get currentPage {
    if (!isReady) return null;
    final List<Rect> layouts;
    final Rect visible;
    try {
      layouts = _pdf.layout.pageLayouts;
      visible = _pdf.value.calcVisibleRect(_pdf.viewSize);
    } on Object {
      final n = _pdf.pageNumber; // yerleşim henüz yok
      return n == null ? null : n - 1;
    }
    if (layouts.isEmpty) return null;
    // Sayfalar dikey sırada: görünür alanın üstünden önceki son sayfayı
    // ikili aramayla bul, oradan aşağı doğru en çok görüneni seç.
    var lo = 0, hi = layouts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (layouts[mid].top <= visible.top) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    var best = lo;
    var bestHeight = -1.0;
    for (var i = lo; i < layouts.length; i++) {
      final r = layouts[i];
      if (r.top > visible.bottom) break;
      final h = r.intersect(visible).height;
      if (h > bestHeight + 0.5) {
        best = i;
        bestHeight = h;
      }
    }
    return best;
  }

  double get zoom => isReady ? _pdf.currentZoom : 1;

  List<PageViewport> _viewports({required bool onlyVisible}) {
    if (!isReady) return const [];
    final List<Rect> layouts;
    final Size viewSize;
    try {
      layouts = _pdf.layout.pageLayouts;
      viewSize = _pdf.viewSize;
    } on Object {
      return const []; // yerleşim henüz hesaplanmadı
    }
    final zoom = _pdf.currentZoom;
    final pages = _pdf.pages;
    final view = Offset.zero & viewSize;
    final result = <PageViewport>[];
    for (var i = 0; i < layouts.length && i < pages.length; i++) {
      final doc = layouts[i];
      final topLeft = _pdf.documentToLocal(doc.topLeft);
      final rect = topLeft & (doc.size * zoom);
      if (onlyVisible && !rect.overlaps(view)) continue;
      result.add(
        PageViewport(
          index: i,
          rect: rect,
          scale: zoom * doc.width / pages[i].width,
        ),
      );
    }
    return result;
  }

  @override
  List<PageViewport> get visiblePages => _viewports(onlyVisible: true);

  @override
  PageViewport? pageAt(Offset local) {
    for (final v in visiblePages) {
      if (v.rect.contains(local)) return v;
    }
    return null;
  }

  @override
  PageViewport? viewportOf(int index) {
    for (final v in _viewports(onlyVisible: false)) {
      if (v.index == index) return v;
    }
    return null;
  }

  /// [index] sayfasına yumuşakça kayar (sayfa gezgini, Page Up / Down,
  /// Home / End).
  ///
  /// pdfrx'in kendi geçişi yavaş başlayıp yavaş biter; tuş basılı tutulunca
  /// her basış onu sıfır hızdan yeniden başlattığı için kaydırma takılarak
  /// ilerliyordu. Burada eğri hızlı başlar, yumuşak durur ve yeni hedef
  /// geldiğinde o anki konumdan devam eder (tekerlek gibi akıcı).
  ///
  /// [top] verilirse sayfanın başı yerine sayfanın üstünden o kadar pt
  /// aşağısı ekranın üstüne gelir (içindekilerde başlığın yeri).
  Future<void> goToPage(int index, {double? top}) {
    if (!isReady || pageCount == 0) return Future.value();
    final n = index.clamp(0, pageCount - 1) + 1;
    _animTop = top;
    final Matrix4 target;
    try {
      target = _pageMatrix(n, top);
    } on Object {
      return _pdf.goToPage(pageNumber: n); // yerleşim henüz hazır değil
    }
    final current = _pdf.value;
    _animFromX = current.entry(0, 3);
    _animFromY = current.entry(1, 3);
    _animToX = target.entry(0, 3);
    _animToY = target.entry(1, 3);
    _animPage = n;
    _animDone?.complete(); // önceki hedef geçersiz
    final done = _animDone = Completer<void>();
    final ticker = _ticker ??= Ticker(_onTick, debugLabel: 'inken-page');
    ticker
      ..stop()
      ..start();
    return done.future;
  }

  // ------------------------------------------------------- metin seçimi

  /// Seçili metin var mı (metin seçme aracında)?
  bool get hasSelectedText =>
      _pdf.isReady && _pdf.textSelectionDelegate.hasSelectedText;

  /// Belge metin kopyalamaya izin veriyor mu (PDF izinleri)?
  bool get isCopyAllowed =>
      _pdf.isReady && _pdf.textSelectionDelegate.isCopyAllowed;

  /// Seçili metin (izin denetimi çağıranın işi: [isCopyAllowed]).
  Future<String> selectedText() async =>
      hasSelectedText ? _pdf.textSelectionDelegate.getSelectedText() : '';

  /// Seçili metni panoya kopyalar; izin yoksa ya da seçim boşsa `false`.
  Future<bool> copySelectedText() async =>
      hasSelectedText && await _pdf.textSelectionDelegate.copyTextSelection();

  /// Belgenin bütün metnini seçer.
  Future<void> selectAllText() async {
    if (_pdf.isReady) await _pdf.textSelectionDelegate.selectAllText();
  }

  Future<void> clearTextSelection() async {
    if (_pdf.isReady) await _pdf.textSelectionDelegate.clearTextSelection();
  }

  void _selectionChanged(PdfTextSelection _) => notifyListeners();

  /// [index] sayfasına geçişsiz atlar (belge yeniden yüklendikten sonra
  /// kalınan yere dönmek için).
  Future<void> jumpToPage(int index) {
    if (!isReady || pageCount == 0) return Future.value();
    _ticker?.stop();
    _animDone?.complete();
    _animDone = null;
    _animPage = null;
    final n = index.clamp(0, pageCount - 1) + 1;
    try {
      _pdf.value = _pageMatrix(n);
      return Future.value();
    } on Object {
      // Yerleşim henüz yok: pdfrx'e bırakılır (son sayfada da üstü hizalı).
      return _pdf.goToPage(
        pageNumber: n,
        anchor: PdfPageAnchor.top,
        duration: Duration.zero,
      );
    }
  }

  /// Sayfalar arası ve kenar boşluğu (görüntüleyiciden): sayfa üstü görüş
  /// alanının üstünden bu kadar aşağıda durur.
  double _margin = 0;

  /// [pageNumber] (1'den) sayfasının üstünü görüş alanının üstüne getiren
  /// matris, **o anki yakınlaştırmayla**; yatay konum korunur, belge
  /// sınırına kırpılır. pdfrx'in `calcMatrixForPage`'i sayfayı sığdıran
  /// yakınlaştırmayla hesaplar: ondan yalnızca kaydırmayı almak, ekran daha
  /// yakınken uzak sayfada yanlış yerde durduruyordu (100 sayfada End
  /// 86. sayfada kalıyordu).
  /// Başlığın üstünde bırakılan pay (pt; başlık ekranın kenarına
  /// yapışmasın).
  static const double _headingGap = 16;

  /// [pageNumber] sayfasının başını (ya da sayfanın üstünden [offset] pt
  /// aşağısını) ekranın üstüne getiren matris; yakınlaştırma ve yatay
  /// konum korunur.
  Matrix4 _pageMatrix(int pageNumber, [double? offset]) {
    final page = _pdf.layout.pageLayouts[pageNumber - 1];
    final zoom = _pdf.currentZoom;
    final view = _pdf.viewSize;
    final center = _pdf.centerPosition;
    final sizes = pageSizes;
    final scale = pageNumber <= sizes.length && sizes[pageNumber - 1].height > 0
        ? page.height / sizes[pageNumber - 1].height
        : 1.0;
    final top = offset == null
        ? page.top - _margin
        : page.top + (offset - _headingGap).clamp(0, double.infinity) * scale;
    return _pdf.makeMatrixInSafeRange(
      _pdf.calcMatrixFor(
        Offset(center.dx, top + view.height / 2 / zoom),
        zoom: zoom,
      ),
      forceClamp: true,
    );
  }

  /// Sayfa geçişinin süresi.
  static const pageAnimation = Duration(milliseconds: 240);

  Ticker? _ticker;
  Completer<void>? _animDone;
  double _animFromX = 0, _animFromY = 0, _animToX = 0, _animToY = 0;
  double? _animTop;

  /// Geçişin hedef sayfası (1'den). Büyük belgede sayfa boyutları kademeli
  /// yüklenir; yerleşim geçiş sürerken değişebildiği için hedef her karede
  /// yeniden hesaplanır (yoksa uzak sayfada yanlış yerde durulur).
  int? _animPage;

  void _onTick(Duration elapsed) {
    final t = (elapsed.inMicroseconds / pageAnimation.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    final e = Curves.easeOutCubic.transform(t);
    if (!isReady) {
      _finishAnimation();
      return;
    }
    final page = _animPage;
    if (page != null) {
      try {
        final target = _pageMatrix(page, _animTop);
        _animToX = target.entry(0, 3);
        _animToY = target.entry(1, 3);
      } on Object {
        // Yerleşim o an hesaplanamıyor; son hedef kullanılır.
      }
    }
    final m = _pdf.value.clone()
      ..setEntry(0, 3, _animFromX + (_animToX - _animFromX) * e)
      ..setEntry(1, 3, _animFromY + (_animToY - _animFromY) * e);
    _pdf.value = m;
    if (t >= 1) _finishAnimation();
  }

  void _finishAnimation() {
    _animPage = null;
    _ticker?.stop();
    _animDone?.complete();
    _animDone = null;
  }

  /// Bir önceki [goToPageBy] hedefi (kaydırma animasyonu sürerken).
  int? _pageTarget;

  /// [delta] sayfa ileri / geri gider. Animasyon bitmeden yeniden
  /// çağrılırsa (tuş art arda / basılı tutuluyor) ekrandaki sayfadan değil,
  /// son hedeften sayar: her basış tam bir sayfa.
  Future<void> goToPageBy(int delta) async {
    final from = _pageTarget ?? currentPage;
    if (from == null) return;
    final target = (from + delta).clamp(0, pageCount - 1);
    if (target == from && _pageTarget == null) return;
    _pageTarget = target;
    try {
      await goToPage(target);
    } finally {
      if (_pageTarget == target) _pageTarget = null;
    }
  }

  /// Dikey kaydırma konumu (0 en üst, 1 en alt); belge ekrana sığıyorsa
  /// ya da yerleşim hazır değilse `null`.
  @override
  double? get scrollFraction {
    final m = _scrollMetrics();
    if (m == null) return null;
    return (m.top / m.range).clamp(0.0, 1.0);
  }

  /// Ekranda görünen yüksekliğin belge yüksekliğine oranı (0..1).
  @override
  double get visibleFraction {
    final m = _scrollMetrics();
    if (m == null) return 1;
    return (m.viewHeight / (m.range + m.viewHeight)).clamp(0.0, 1.0);
  }

  /// Belgeyi dikeyde [fraction] konumuna kaydırır; yatay konum ve
  /// yakınlaştırma değişmez.
  @override
  Future<void> scrollToFraction(double fraction) async {
    final m = _scrollMetrics();
    if (m == null) return;
    final top = fraction.clamp(0.0, 1.0) * m.range;
    await _pdf.goToPosition(documentOffset: Offset(m.left, top));
  }

  ({double top, double left, double range, double viewHeight})?
  _scrollMetrics() {
    if (!isReady) return null;
    try {
      final view = _pdf.visibleRect;
      final range = _pdf.documentSize.height - view.height;
      if (range <= 0) return null;
      return (
        top: view.top,
        left: view.left,
        range: range,
        viewHeight: view.height,
      );
    } on Object {
      return null; // yerleşim henüz hesaplanmadı
    }
  }

  /// Yakınlaştırma sınırları (görüntüleyicinin izin verdiği).
  double get minZoom => isReady ? _pdf.minScale : 1;
  double get maxZoom => isReady ? _pdf.maxScale : 1;

  /// Ekranın ortasını sabit tutarak yakınlaştırır (kaydırma çubuğu için).
  Future<void> setZoom(double zoom) async {
    if (!isReady) return;
    final z = zoom.clamp(minZoom, maxZoom);
    await _pdf.setZoom(_pdf.centerPosition, z, duration: Duration.zero);
  }

  Future<void> zoomIn() => _pdf.zoomUp();
  Future<void> zoomOut() => _pdf.zoomDown();

  /// Geçerli sayfanın tamamı ekrana sığar; sayfa ortalanır.
  Future<void> fitPage() => _fit(width: false);

  /// Geçerli sayfanın genişliği ekrana sığar; dikey konum korunur.
  Future<void> fitWidth() => _fit(width: true);

  /// [fitPage] / [fitWidth] yakınlaştırması (sayfa kenar boşluğu dahil);
  /// belge hazır değilse `null`.
  double? fitZoom({required bool width}) {
    if (!isReady) return null;
    try {
      final page = _pdf.layout.pageLayouts[currentPage ?? 0];
      final view = _pdf.viewSize;
      var zoom = view.width / (page.width + 2 * _margin);
      if (!width) {
        zoom = math.min(zoom, view.height / (page.height + 2 * _margin));
      }
      return zoom.clamp(minZoom, maxZoom);
    } on Object {
      return null; // yerleşim henüz yok
    }
  }

  Future<void> _fit({required bool width}) async {
    final zoom = fitZoom(width: width);
    if (zoom == null) return;
    final Matrix4 target;
    try {
      final page = _pdf.layout.pageLayouts[currentPage ?? 0];
      final visible = _pdf.value.calcVisibleRect(_pdf.viewSize);
      final y = width
          ? visible.center.dy.clamp(page.top, page.bottom)
          : page.center.dy;
      target = _pdf.makeMatrixInSafeRange(
        _pdf.calcMatrixFor(Offset(page.center.dx, y), zoom: zoom),
        forceClamp: true,
      );
    } on Object {
      return;
    }
    _finishAnimation();
    await _pdf.goTo(target);
  }

  void _setReady(bool value) {
    _ready = value;
    if (value) _generation++;
    notifyListeners();
  }

  int _generation = 0;

  /// Kademeli yüklenen sayfaların boyutu gelince dinleyiciler haberdar olur
  /// ([pageSizes] değişir; sayfa paneli satır yüksekliklerini yeniler).
  StreamSubscription<PdfDocumentEvent>? _pageEvents;

  void _watchPages(PdfDocument document) {
    unawaited(_pageEvents?.cancel());
    _pageEvents = document.events.listen((event) {
      if (event is PdfDocumentPageStatusChangedEvent) notifyListeners();
    });
  }

  /// Her yeni yüklenen belgede artar (sayfa düzeni değişince görüntüleyici
  /// yeni kopyayı yükler); belgeye bağlı önbellekler bununla yenilenir.
  int get documentGeneration => _generation;

  /// Gösterilen belgenin içindekiler ağacı; yoksa boş.
  Future<List<InkenOutlineItem>> loadOutline() async {
    if (!isReady) return const [];
    final nodes = await _pdf.document.loadOutline();
    final count = _pdf.pageCount;
    List<InkenOutlineItem> convert(List<PdfOutlineNode> list) => [
      for (final n in list)
        InkenOutlineItem(
          title: n.title.trim(),
          page: switch (n.dest?.pageNumber) {
            final p? when p >= 1 && p <= count => p - 1,
            _ => null,
          },
          top: _destTop(n.dest, count),
          children: convert(n.children),
        ),
    ];
    return convert(nodes);
  }

  /// `/XYZ sol üst yakınlaştırma` hedefinin sayfanın üstünden uzaklığı
  /// (pt). Üst değeri olmayan ya da başka türlü hedefte `null`.
  double? _destTop(PdfDest? dest, int count) {
    if (dest == null || dest.command != PdfDestCommand.xyz) return null;
    final params = dest.params;
    final top = params == null || params.length < 2 ? null : params[1];
    if (top == null || dest.pageNumber < 1 || dest.pageNumber > count) {
      return null;
    }
    final height = _pdf.document.pages[dest.pageNumber - 1].height;
    final y = height - top;
    return y <= 0 || y >= height ? null : y;
  }

  /// Görüntüleyicinin bağlantı işleyicisi ([InkenPdfViewer.onLink]).
  ValueChanged<InkenLink>? _onLink;

  /// pdfrx'e hep aynı fonksiyon verilir (parametre eşitliği bozulmasın);
  /// asıl işleyici [_onLink].
  void _linkTapped(PdfLink link) {
    final dest = link.dest;
    _onLink?.call((
      page: dest == null ? null : dest.pageNumber - 1,
      url: link.url,
    ));
  }

  /// Belgede metin arama; ilk kullanımda kurulur.
  InkenTextSearch get search =>
      _search ??= InkenTextSearch._(_pdf, _centerOnMatch);

  /// Eşleşmeyi o anki yakınlaştırmayla görüş alanının ortasına getirir;
  /// yatayda zaten görünüyorsa yatay konum korunur.
  Future<void> _centerOnMatch(int pageNumber, PdfRect bounds) async {
    if (!isReady) return;
    final Matrix4 target;
    try {
      final r = _pdf.calcRectForRectInsidePage(
        pageNumber: pageNumber,
        rect: bounds,
      );
      final visible = _pdf.value.calcVisibleRect(_pdf.viewSize);
      final x = r.left >= visible.left && r.right <= visible.right
          ? _pdf.centerPosition.dx
          : r.center.dx;
      target = _pdf.makeMatrixInSafeRange(
        _pdf.calcMatrixFor(Offset(x, r.center.dy), zoom: _pdf.currentZoom),
        forceClamp: true,
      );
    } on Object {
      return; // yerleşim henüz yok
    }
    _finishAnimation();
    await _pdf.goTo(target);
  }

  InkenTextSearch? _search;

  /// Görüntüleyici parametrelerinde aynı liste kalsın (her kurulumda yeni
  /// liste parametreleri "değişmiş" gösterir).
  late final List<PdfViewerPagePaintCallback> _paintCallbacks = [_paintMatches];

  void _paintMatches(Canvas canvas, Rect pageRect, PdfPage page) =>
      _search?._searcher.pageTextMatchPaintCallback(canvas, pageRect, page);

  @override
  void dispose() {
    _finishAnimation();
    _ticker?.dispose();
    _search?.dispose();
    _pdf.removeListener(notifyListeners);
    unawaited(_pageEvents?.cancel());
    super.dispose();
  }
}

/// Belgede metin arama (görüntüleyicinin gösterdiği kopyada). Sonuçlar
/// sayfalarda vurgulanır; geçerli eşleşme ayrı renkte.
///
/// Büyük / küçük harf ve Türkçe I / ı / İ / i ayrımı yapılmaz; boşluklar
/// esnektir (satır sonu dahil). Taranmış (metinsiz) sayfalarda sonuç
/// çıkmaz.
class InkenTextSearch extends ChangeNotifier {
  InkenTextSearch._(this._pdf, this._center)
    : _searcher = PdfTextSearcher(_pdf) {
    _searcher.addListener(_changed);
  }

  final PdfViewerController _pdf;
  final PdfTextSearcher _searcher;
  final Future<void> Function(int pageNumber, PdfRect bounds) _center;

  /// Son ortalanan eşleşme: pdfrx eşleşmeyi yalnızca görünür yapar
  /// (kenarda kalabilir); her yeni geçerli eşleşme ortaya getirilir.
  PdfPageTextRange? _centered;

  void _changed() {
    final i = currentIndex;
    final match = i == null ? null : _searcher.matches[i];
    if (match != null && !identical(match, _centered)) {
      _centered = match;
      unawaited(_center(match.pageNumber, match.bounds));
    }
    notifyListeners();
  }

  String _query = '';

  /// Son aranan metin.
  String get query => _query;

  /// Şimdiye kadar bulunan eşleşme sayısı (arama sürerken artar).
  int get matchCount => _searcher.matches.length;

  /// Geçerli eşleşmenin sırası (0'dan); eşleşme yoksa `null`.
  int? get currentIndex => _searcher.hasMatches ? _searcher.currentIndex : null;

  /// Geçerli eşleşmenin sayfası (0'dan).
  int? get currentPage {
    final i = currentIndex;
    return i == null ? null : _searcher.matches[i].pageNumber - 1;
  }

  /// Arama sürüyor mu?
  bool get isSearching => _searcher.isSearching;

  /// [text]'i arar ve [fromPage]'den (0'dan) itibaren ilk eşleşmeye gider.
  /// Boş metin aramayı temizler.
  void find(String text, {int? fromPage}) {
    _query = text;
    _centered = null;
    if (text.trim().isEmpty) {
      _searcher.resetTextSearch();
    } else {
      _searcher.startTextSearch(
        searchPattern(text),
        goToFirstMatch: true,
        startPageNumber: fromPage == null ? null : fromPage + 1,
      );
    }
    notifyListeners();
  }

  /// Sonraki eşleşme; sondan başa sarar.
  Future<void> next() => _step(1);

  /// Önceki eşleşme; baştan sona sarar.
  Future<void> previous() => _step(-1);

  Future<void> _step(int delta) async {
    final n = matchCount;
    if (!_pdf.isReady || n == 0) return;
    final i = currentIndex;
    final to = i == null ? (delta > 0 ? 0 : n - 1) : (i + delta) % n;
    await _searcher.goToMatchOfIndex(to);
  }

  /// Aramayı ve vurguları temizler.
  void clear() => find('');

  @override
  void dispose() {
    _searcher.removeListener(_changed);
    _searcher.dispose();
    super.dispose();
  }
}

/// [text] için arama deseni: harfler büyük / küçük ayrımsız, Türkçe
/// I / ı / İ / i birbirini bulur, boşluk dizileri her türlü boşluğa
/// (satır sonu dahil) uyar.
@visibleForTesting
RegExp searchPattern(String text) {
  final b = StringBuffer();
  var space = false;
  for (final rune in text.trim().runes) {
    final ch = String.fromCharCode(rune);
    if (ch.trim().isEmpty) {
      if (!space) b.write(r'\s+');
      space = true;
      continue;
    }
    space = false;
    b.write('iıIİ'.contains(ch) ? '[iıIİ]' : RegExp.escape(ch));
  }
  return RegExp(b.toString(), caseSensitive: false, unicode: true);
}

/// Uygulamanın kendisi işlediği, görüntüleyicinin dokunmaması gereken tuşlar.
final Set<LogicalKeyboardKey> _appKeys = {
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.equal,
  LogicalKeyboardKey.minus,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyC,
};

/// Bellekteki bir PDF'i gösterir.
///
/// Dosya her zaman bayt olarak verilir: Inken, kendi açıklamalarını
/// gizlemek için dosyanın bellekteki bir kopyasını gösterir (Faz 0 kararı).
class InkenPdfViewer extends StatelessWidget {
  const InkenPdfViewer({
    super.key,
    required this.data,
    required this.sourceName,
    required this.controller,
    this.onLoaded,
    this.backgroundColor = const Color(0xFFE9E3D6),
    this.pageGap = 32,
    this.password,
    this.matchColor,
    this.activeMatchColor,
    this.onLink,
    this.linkColor,
    this.linkHoverColor,
    this.pageColorFilter,
    this.textSelection = false,
  });

  /// Metin seçilebilir mi (metin seçme aracı). Kapalıyken sürükleme ve
  /// dokunuş yalnızca kaydırır; çizimle çakışmasın diye varsayılan kapalı.
  final bool textSelection;

  /// Sayfa görüntüsüne uygulanan renk süzgeci (gece modu); vurgular ve
  /// zemin etkilenmez.
  final ColorFilter? pageColorFilter;

  /// Bağlantıya dokunulunca. Bağlantılar yalnızca dokunuş görüntüleyiciye
  /// ulaştığında çalışır (çizim katmanı el aracında geçirir).
  final ValueChanged<InkenLink>? onLink;

  /// Bağlantı alanının rengi; fare üstündeyken [linkHoverColor].
  final Color? linkColor;
  final Color? linkHoverColor;

  /// Arama eşleşmelerinin ve geçerli eşleşmenin vurgu rengi.
  final Color? matchColor;
  final Color? activeMatchColor;

  final Uint8List data;

  /// Açılış parolası (parolalı dosyada).
  final String? password;

  /// Belgeyi ayırt eden ad (önbellek anahtarı); aynı ad aynı içerik demektir.
  final String sourceName;

  final InkenViewerController controller;

  /// Belge açılınca sayfa boyutlarıyla çağrılır.
  final void Function(List<PdfPageSize> pages)? onLoaded;

  /// Sayfaların arkasındaki zemin ("masa").
  final Color backgroundColor;

  /// Sayfalar arası ve kenar boşluğu (mantıksal piksel, %100'de).
  final double pageGap;

  @override
  Widget build(BuildContext context) {
    controller._margin = pageGap;
    controller._onLink = onLink;
    return PdfViewer.data(
      data,
      sourceName: sourceName,
      passwordProvider: password == null ? null : () => password,
      controller: controller._pdf,
      params: PdfViewerParams(
        backgroundColor: backgroundColor,
        margin: pageGap,
        pageImageColorFilter: pageColorFilter,
        pageDropShadow: const BoxShadow(
          color: Color(0x24000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
        // Sayfa ve yakınlaştırma tuşları uygulamanın kısayollarındadır;
        // görüntüleyici odaktayken bunları ayrıca işlerse her basış iki kez
        // sayılır. Ok tuşlarıyla kaydırma görüntüleyicide kalır.
        onKey: (_, key, _) => _appKeys.contains(key) ? false : null,
        pagePaintCallbacks: controller._paintCallbacks,
        linkHandlerParams: onLink == null
            ? null
            : PdfLinkHandlerParams(
                onLinkTap: controller._linkTapped,
                linkColor: linkColor,
                linkHoverColor: linkHoverColor,
              ),
        matchTextColor: matchColor,
        activeMatchTextColor: activeMatchColor,
        // Metin seçimi yalnızca metin seçme aracında (çizimle çakışır).
        textSelectionParams: PdfTextSelectionParams(
          enabled: textSelection,
          onTextSelectionChange: controller._selectionChanged,
        ),
        onViewerReady: (document, _) {
          controller._setReady(true);
          controller._watchPages(document);
          _whenAllPagesLoaded(document, () {
            // Bu arada başka bir kopya yüklendiyse onun hazır bildirimi gelir.
            if (!controller._pdf.isReady ||
                !identical(controller._pdf.document, document)) {
              return;
            }
            onLoaded?.call(controller.pageSizes);
          });
        },
      ),
    );
  }
}

/// [document]'in bütün sayfaları yüklenince [then]'i çağırır. pdfrx
/// sayfaları kademeli yükler; yüklenmemiş sayfa geçici olarak ilk sayfanın
/// boyutunu gösterir. Model gerçek boyutlarla kurulsun diye sayfa boyutları
/// ancak hepsi yüklenince verilir.
void _whenAllPagesLoaded(PdfDocument document, VoidCallback then) {
  bool all() => document.pages.every((p) => p.isLoaded);
  if (all()) {
    then();
    return;
  }
  late final StreamSubscription<PdfDocumentEvent> sub;
  sub = document.events.listen((event) {
    if (event is PdfDocumentPageStatusChangedEvent && all()) {
      unawaited(sub.cancel());
      then();
    }
  });
}

/// Görüntüleyicinin yüklediği belgeden tek bir sayfanın küçük resmi
/// (sayfa listesi paneli). Belge ikinci kez açılmaz; görüntüleyici hazır
/// değilken boş. Sayfa, verilen kutuya oranı korunarak sığdırılır.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.controller,
    required this.pageIndex,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.colorFilter,
  });

  /// Sayfa görüntüsünün renk süzgeci (gece modu).
  final ColorFilter? colorFilter;

  final InkenViewerController controller;

  /// 0'dan başlayan sayfa sırası.
  final int pageIndex;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.isReady || pageIndex >= controller.pageCount) {
        return ColoredBox(color: backgroundColor);
      }
      final view = PdfPageView(
        document: controller._pdf.document,
        pageNumber: pageIndex + 1,
        // Küçük resim: düşük çözünürlük yeter, bellek az.
        maximumDpi: 60,
        backgroundColor: backgroundColor,
      );
      final filter = colorFilter;
      return filter == null
          ? view
          : ColorFiltered(colorFilter: filter, child: view);
    },
  );
}
