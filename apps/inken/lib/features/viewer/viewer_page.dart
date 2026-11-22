import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken_pdf/inken_pdf.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../backup/backup_store.dart';
import '../files/document_io.dart';
import '../files/document_properties.dart';
import '../files/open_document.dart';
import '../ink/ink_images.dart';
import '../ink/ink_layer.dart';
import '../ink/item_clipboard.dart';
import '../ink/ink_session.dart';
import '../ink/instruments.dart';
import 'app_menus.dart';
import 'idle_fade.dart';
import 'night_mode.dart';
import 'page_panel.dart';
import 'page_scrollbar.dart';
import '../ink/ink_toolbar.dart';
import '../ink/mobile_dock.dart';
import '../ink/tool_options.dart';
import '../ink/tool_state.dart';
import '../presentation/stage_cover.dart';
import '../../platform/window_title.dart';
import '../../theme/dialog_actions.dart';
import '../print/print_dialog.dart';
import '../../theme/logo.dart';
import '../../theme/theme_mode.dart';
import '../../theme/tokens.dart';
import '../settings/settings_page.dart';
import '../settings/settings_store.dart';
import '../settings/share_app.dart';
import '../settings/shortcuts.dart';
import 'go_to_page.dart';
import 'home_page.dart' show openErrorMessage;
import 'layout_gate.dart';
import '../files/launch_file.dart';
import '../files/pdf_drop.dart';
import '../files/recent_documents.dart';
import '../../platform/clipboard_service.dart';
import '../../platform/print_service.dart';
import '../../platform/share_service.dart';
import 'quick_bar.dart';
import 'search_box.dart';
import '../../platform/link_opener.dart';

class ViewerPage extends ConsumerStatefulWidget {
  const ViewerPage({super.key, required this.document});

  final OpenDocument document;

  @override
  ConsumerState<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends ConsumerState<ViewerPage> {
  final InkenViewerController _controller = InkenViewerController();

  /// Belge yüklenince görüntüleyici çizim katmanının içine taşınır;
  /// genel anahtar, bu sırada baştan kurulmasını (ve PDF'in yeniden
  /// yüklenmesini) önler.
  final GlobalKey _viewerKey = GlobalKey();
  InkSession? _session;
  bool _saving = false;

  // ---- sayfa düzeni (ekle / sil)
  //
  // Görüntüleyici, açık dosyanın görüntüleme kopyasını gösterir. Sayfa
  // eklenip silinince model değişir; kopya worker'da modelin düzenine
  // getirilir ([arrangeDisplay]) ve görüntüleyici yeniden yüklenir. Bu sırada
  // çizim katmanı [_gate] kapalıdır.

  /// Çizim katmanının gördüğü yerleşim; düzen uyuşmazken kapalı.
  late final LayoutGate _gate = LayoutGate(_controller);

  /// Gösterilen kopya; `null` ise açık dosyanın kendi görüntüleme kopyası.
  Uint8List? _display;

  /// Her yeni kopyada artar: görüntüleyici belgeyi yeniden yükler.
  int _displayGen = 0;

  /// Ekrandaki sayfa düzeninin anahtarı ([pageLayoutKey]).
  String? _shownKey;

  /// Açık dosyanın sayfa sayısı (kayıttan sonra kaydedilenin).
  int? _sourceCount;

  bool _arranging = false;
  bool _reloading = false;

  /// Yeniden yüklemeden sonra dönülecek sayfa ve yakınlaştırma.
  int? _targetPage;
  double? _returnZoom;
  bool _exporting = false;

  /// Tam ekran: menü ve araç çubukları gizli, yüzen kutular kalır.
  bool _fullscreen = false;

  /// Telefonda alt araç rafı açık mı? Varsayılan kapalı: belge okuma
  /// hâlinde açılır, parmak sayfayı kaydırır. Kapalıyken el aracındadır;
  /// raf açılınca önceki araca dönülür ([_parkedTool]).
  bool _phoneDock = false;

  /// Telefon yan menüsünde açık bölümler (belge açıkken hatırlanır).
  final Set<String> _drawerOpen = {};

  /// Raf kapanırken seçili olan araç; `null`: raf açık ya da telefon değil.
  Tool? _parkedTool;

  void _setPhoneDock(bool open) {
    if (open == _phoneDock) return;
    setState(() => _phoneDock = open);
    _syncPhoneTool(phone: true);
  }

  /// Telefonda raf kapalıyken el aracına geçer, raf açılınca (ya da yerleşim
  /// telefon olmaktan çıkınca) önceki aracı geri getirir.
  void _syncPhoneTool({required bool phone}) {
    final tools = ref.read(toolProvider.notifier);
    final park = phone && !_phoneDock;
    if (park && _parkedTool == null) {
      _parkedTool = ref.read(toolProvider).tool;
      tools.select(Tool.hand);
    } else if (!park && _parkedTool != null) {
      final back = _parkedTool!;
      _parkedTool = null;
      if (ref.read(toolProvider).tool == Tool.hand) tools.select(back);
    }
  }

  void _setFullscreen(bool on) {
    if (on == _fullscreen) return;
    setState(() => _fullscreen = on);
    AppFullscreen.set(on);
  }

  /// Esc: önce açık seçenek panelini, sonra seçimi, sonra örtüyü (spot
  /// ışığı / perde), sonra ölçme araçlarını, sonra tam ekranı kapatır.
  /// Kapatacak bir şey bulduysa `true`.
  bool _escape() {
    final options = ref.read(toolOptionsProvider.notifier);
    final session = _session;
    if (ref.read(toolOptionsProvider) != null) {
      options.close();
    } else if (_searchOpen) {
      _closeSearch();
    } else if (session != null && session.hasSelection) {
      session.clearSelection();
    } else if (ref.read(stageCoverProvider).mode != StageCover.none) {
      _cover.close();
    } else if (ref.read(instrumentsProvider).isNotEmpty) {
      _instruments.closeAll();
    } else if (_fullscreen) {
      _setFullscreen(false);
    } else {
      return false;
    }
    return true;
  }

  /// Sistem geri hareketi (Android): Esc gibi önce açık olanı kapatır;
  /// kapatacak bir şey yoksa belgeyi kapatıp ana ekrana döner.
  void _back() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else if (!_escape()) {
      _close();
    }
  }

  /// Bu oturumda en az bir kez kaydedildi mi (durum satırı için).
  bool _savedOnce = false;

  final GlobalKey _docKey = GlobalKey();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  /// Pencerenin kendi kapat düğmesi (masaüstü): kaydedilmemiş değişiklik
  /// varsa önce sorar.
  late final AppLifecycleListener _exitListener;
  bool _askingToClose = false;

  /// Otomatik yedek: belirli aralıkla, yalnızca kaydedilmemiş değişiklik
  /// varsa ve son yedekten beri model değiştiyse.
  late final BackupStore _backups = ref.read(backupStoreProvider);
  Timer? _backupTimer;
  StreamSubscription<void>? _arrivals;
  InkenDocument? _backedUp;

  /// Yedek yazma / silme işlemleri sırayla çalışır (silme, süren bir
  /// yazmanın ardından gelir).
  Future<void> _backupQueue = Future.value();

  /// Örtü belgeye aittir: belge kapanınca kapanır. `dispose` içinde `ref`
  /// kullanılamadığı için önceden alınır.
  late final StageCoverNotifier _cover;
  late final InstrumentsNotifier _instruments;

  void _toggleCover(StageCover mode) {
    ref.read(toolOptionsProvider.notifier).close();
    _cover.toggle(mode);
  }

  @override
  void initState() {
    super.initState();
    _cover = ref.read(stageCoverProvider.notifier);
    _instruments = ref.read(instrumentsProvider.notifier);
    HardwareKeyboard.instance.addHandler(_onKey);
    _exitListener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      // Android uygulamayı arka planda öldürebilir; beklemeden yedekle.
      onPause: _queueBackup,
    );
    _backupTimer = Timer.periodic(
      ref.read(backupIntervalProvider),
      (_) => _queueBackup(),
    );
    // Başka bir uygulamadan "Birlikte aç" (Android, uygulama açıkken).
    _arrivals = ref
        .read(launchFileProvider)
        .arrivals
        .listen((_) => _openIncoming());
    if (widget.document.isProtected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).protectedFileWarning),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    _arrivals?.cancel();
    _exitListener.dispose();
    _session?.dispose();
    _gate.dispose();
    _controller.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    // Belge tam ekrandayken kapanırsa ana sayfa normal pencerede açılsın.
    if (_fullscreen) AppFullscreen.set(false);
    // Ağaç sökülürken sağlayıcı değiştirilemez; hemen ardından kapatılır.
    final cover = _cover;
    final instruments = _instruments;
    Future.microtask(() {
      cover.close();
      // Araçlar sayfalara bağlı: başka belgede anlamları yok.
      instruments.closeAll();
    });
    super.dispose();
  }

  void _onLoaded(List<PdfPageSize> pages) {
    if (!mounted) return;
    if (_session != null) {
      unawaited(_afterReload());
      return;
    }
    _sourceCount = pages.length;
    _shownKey = pageLayoutKey(InkenDocument.forPdf(pages));
    final model = widget.document.model ?? InkenDocument.forPdf(pages);
    final session = InkSession(model, images: InkImages(widget.document.images))
      ..addListener(_syncLayout);
    final recovered = widget.document.recovered;
    if (recovered != null) session.restore(recovered);
    setState(() => _session = session);
    // Kurtarılan modelde eklenmiş / silinmiş sayfa olabilir.
    _syncLayout();
  }

  /// Yeni kopya yüklendi: kalınan sayfaya dön, uyuşuyorsa kapıyı aç.
  Future<void> _afterReload() async {
    _reloading = false;
    final zoom = _returnZoom;
    final page = _targetPage;
    _returnZoom = null;
    _targetPage = null;
    if (zoom != null) await _controller.setZoom(zoom);
    if (page != null) await _controller.jumpToPage(page);
    final session = _session;
    if (!mounted || session == null) return;
    _gate.open = _shownKey == pageLayoutKey(session.document);
    // Yeni kopyada arama sıfırlanır; açık arama yeniden yapılır.
    final query = _controller.search.query;
    if (_searchOpen && query.trim().isNotEmpty) {
      _controller.search.find(query, fromPage: _controller.currentPage);
    }
    _syncLayout();
  }

  void _syncLayout() => unawaited(_arrange());

  /// Görüntüleme kopyasını modelin sayfa düzenine getirir. Sürerken model
  /// yine değişirse sonuç atılır ve güncel düzen için yeniden üretilir.
  Future<void> _arrange() async {
    if (_arranging || _reloading) return;
    _arranging = true;
    try {
      while (mounted) {
        final session = _session;
        final count = _sourceCount;
        if (session == null || count == null) return;
        final doc = session.document;
        final key = pageLayoutKey(doc);
        if (key == _shownKey) {
          _gate.open = true;
          return;
        }
        _gate.open = false;
        final bytes = isSourceLayout(doc, count)
            ? null
            : await arrangeDisplay(
                widget.document.displayBytes,
                doc,
                password: widget.document.password,
              );
        if (!mounted) return;
        if (pageLayoutKey(_session!.document) != key) continue;
        _targetPage ??= _controller.currentPage;
        _returnZoom ??= _controller.zoom;
        _reloading = true;
        setState(() {
          _display = bytes;
          _displayGen++;
          _shownKey = key;
        });
        return;
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).pageLayoutFailed(e.toString()),
          ),
        ),
      );
    } finally {
      _arranging = false;
    }
  }

  /// Belgede arama kutusu açık mı (Ctrl+F)?
  bool _searchOpen = false;
  final GlobalKey<SearchBoxState> _searchKey = GlobalKey();

  void _openSearch() {
    if (_session == null) return;
    if (_searchOpen) {
      _searchKey.currentState?.focus();
    } else {
      setState(() => _searchOpen = true);
    }
  }

  /// Belgedeki bağlantı: belge içindeyse o sayfaya gider; dış adresse
  /// önce sorar (tahtada kazara dokunuş tarayıcıyı açmasın).
  Future<void> _openLink(InkenLink link) async {
    final page = link.page;
    if (page != null) {
      await _controller.goToPage(page);
      return;
    }
    final url = link.url;
    if (url == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final open = ref.read(linkOpenerProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('link-dialog'),
        title: Text(l10n.linkOpenTitle),
        content: Text(l10n.linkOpenBody(url.toString())),
        actions: [
          TextButton(
            key: const ValueKey('link-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('link-open'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.linkOpen),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await open(url)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.linkOpenFailed(url.toString()))),
      );
    }
  }

  void _closeSearch() {
    _controller.search.clear();
    setState(() => _searchOpen = false);
  }

  /// Eklenecek sayfanın kullanıcının seçtiği yönü; `null`: geçerli
  /// sayfanınki.
  PageOrientation? _newOrientation;

  /// Geçerli sayfanın sırası (modelin sınırları içinde).
  int _currentIndex(InkSession session) => (_controller.currentPage ?? 0).clamp(
    0,
    session.document.pages.length - 1,
  );

  /// "Sayfa ekle" menülerinde seçili görünen yön.
  PageOrientation _effectiveOrientation(InkSession? session) {
    final chosen = _newOrientation;
    if (chosen != null || session == null) {
      return chosen ?? PageOrientation.portrait;
    }
    return orientationOf(session.document.pages[_currentIndex(session)]);
  }

  void _setNewOrientation(PageOrientation o) =>
      setState(() => _newOrientation = o);

  /// Eklenecek sayfanın kâğıt rengi; belge açık kaldıkça hatırlanır.
  PageColor _newColor = PageColor.white;

  void _setNewColor(PageColor c) => setState(() => _newColor = c);

  /// Geçerli sayfanın arkasına [template] zeminli sayfa ekler.
  void _insertPage(PageTemplate template) {
    final session = _session;
    if (session == null || !session.canChangePages) return;
    _insertPageAt(_currentIndex(session) + 1, template);
  }

  /// [index] konumuna [template] zeminli, seçili yönde sayfa ekler; boyut
  /// komşu sayfadan alınır. Yeni sayfaya gidilir.
  void _insertPageAt(int index, PageTemplate template) {
    final session = _session;
    if (session == null || !session.canChangePages) return;
    final pages = session.document.pages;
    final at = index.clamp(0, pages.length);
    final like = (at - 1).clamp(0, pages.length - 1);
    _targetPage = at;
    session.insertPage(
      at,
      newPageLike(
        session.document,
        like,
        template,
        orientation: _effectiveOrientation(session),
        color: _newColor,
      ),
    );
  }

  /// Geçerli sayfayı [turns] çeyrek tur döndürür (1 sağa, -1 sola).
  void _rotateCurrentPage(int turns) {
    final session = _session;
    if (session == null) return;
    _rotatePages({_currentIndex(session)}, turns);
  }

  void _rotatePages(Set<int> pages, int turns) {
    final session = _session;
    if (session == null || !session.canChangePages || pages.isEmpty) return;
    _targetPage = _currentIndex(session);
    session.rotatePages(pages, turns);
  }

  /// [pages] sayfalarını siler (en az bir sayfa kalır); geri alınabilir,
  /// bildirimde "Geri al" düğmesi.
  void _deletePages(Set<int> pages) {
    final session = _session;
    if (session == null || !session.canChangePages || pages.isEmpty) return;
    final count = session.document.pages.length;
    if (pages.length >= count) return;
    final current = _currentIndex(session);
    final before = pages.where((p) => p < current).length;
    _targetPage = (current - before).clamp(0, count - pages.length - 1);
    if (pages.length == 1) {
      session.removePage(pages.single);
    } else {
      session.removePages(pages);
    }
    final l10n = AppLocalizations.of(context);
    _showDeleted(
      session,
      pages.length == 1
          ? l10n.pageDeleted(pages.single + 1)
          : l10n.pagesDeleted(pages.length),
    );
  }

  /// Geçerli sayfayı siler; geri alınabilir.
  void _deletePage() {
    final session = _session;
    if (session == null || !_canDeletePage(session)) return;
    _deletePages({_currentIndex(session)});
  }

  void _showDeleted(InkSession session, String message) {
    final afterDelete = session.document;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Yalnızca silmeyi geri alır: arada başka değişiklik olduysa
          // bildirimdeki düğme bir şey yapmaz (Ctrl+Z yine çalışır).
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () {
              if (identical(session.document, afterDelete)) session.undo();
            },
          ),
        ),
      );
  }

  bool _canDeletePage(InkSession? session) =>
      session != null &&
      session.canChangePages &&
      session.document.pages.length > 1;

  void _queueBackup() => _backupQueue = _backupQueue.then((_) => _backup());

  Future<void> _backup() async {
    final session = _session;
    final path = widget.document.path;
    if (session == null || path == null || _saving || !session.isDirty) return;
    final document = session.document;
    if (identical(document, _backedUp)) return;
    try {
      final stat = await ref.read(documentIoProvider).stat(path);
      if (stat == null) return;
      await _backups.write(
        InkenBackup(
          sourcePath: path,
          sourceName: widget.document.name,
          sourceLength: stat.size,
          sourceModified: stat.modified,
          savedAt: DateTime.now(),
          document: document,
          sourcePageCount: _sourceCount,
        ),
        images: session.images.all,
      );
      _backedUp = document;
    } on Object catch (e) {
      // Yedek alınamadı; bir sonraki turda yeniden denenir.
      debugPrint('Otomatik yedek alınamadı: $e');
    }
  }

  /// [path]'in yedeğini siler (kaydedildi ya da değişiklikler bırakıldı).
  Future<void> _dropBackup(String? path) {
    _backedUp = null;
    if (path == null) return _backupQueue;
    return _backupQueue = _backupQueue.then((_) async {
      try {
        await _backups.delete(path);
      } on Object catch (e) {
        debugPrint('Yedek silinemedi: $e');
      }
    });
  }

  /// Kaydeder; başarılıysa `true`. [target] verilirse oraya ("Farklı
  /// kaydet"), verilmezse olağan yere. Olağan yer sorulmadan bulunamıyorsa
  /// (Android'de düz PDF'in ilk kaydı) kayıt yeri sorulur.
  Future<bool> _save({DocTarget? target}) async {
    final session = _session;
    if (session == null || _saving) return false;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(openDocumentProvider.notifier);
    if (target == null && notifier.needsSaveLocation) return _saveAs();
    final previousPath = widget.document.path;
    setState(() => _saving = true);
    // Kayıt sürerken sayfa düzeni değişmez; kayıttan sonra sayfalar yeni
    // dosyaya göre numaralanır.
    session.saving = true;
    try {
      final snapshot = session.document;
      final count = _sourceCount ?? snapshot.pages.length;
      final relaid = !isSourceLayout(snapshot, count);
      // Ekran bu düzeni mi gösteriyor? Öyleyse kayıttan sonra yeniden
      // yükleme gerekmez: gösterilen kopya kaydedilenin kopyasıyla aynıdır.
      final shownMatches = !_reloading && _shownKey == pageLayoutKey(snapshot);
      // Kaydedilen dosyanın görüntüleme kopyası: modelin düzenindeki kopya
      // (ekrandaki yeniden yüklenmekte olabilir; ona güvenilmez).
      final display = relaid
          ? await arrangeDisplay(
              widget.document.displayBytes,
              snapshot,
              password: widget.document.password,
            )
          : null;
      final outcome = await notifier.save(
        snapshot,
        target: target,
        displayBytes: display,
        images: await _imagesFor(session, snapshot),
      );
      session.markSaved(snapshot, outcome.model);
      if (relaid) {
        // Açık dosya artık kaydedilen: düzeni kendi düzeni, numaralar
        // yeni. Ekran aynı düzeni gösteriyorsa yalnızca anahtar güncellenir;
        // değilse görüntüleyici kaydedilenin kopyasıyla yeniden yüklenir.
        _sourceCount = outcome.model.pages.length;
        _shownKey = shownMatches ? pageLayoutKey(session.document) : null;
      }
      _savedOnce = true;
      await _dropBackup(previousPath);
      final name = outcome.name;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome.skippedItems == 0
                ? l10n.savedTo(name)
                : l10n.savedWithSkipped(name, outcome.skippedItems),
          ),
        ),
      );
      return true;
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.saveFailed(e.toString()))),
      );
      return false;
    } finally {
      session.saving = false;
      if (mounted) setState(() => _saving = false);
      _syncLayout();
    }
  }

  /// Kayıt penceresiyle bir PDF yeri seçtirir. [allowed] yeri reddederse
  /// [rejected] gösterilir; var olan başka bir dosya için onay sorulur
  /// (Linux'un kayıt penceresi sormuyor; Android'de sistem yeni ad verir).
  /// Vazgeçilirse ya da desteklenmiyorsa `null`.
  Future<DocTarget?> _pickTarget({
    required String suggestedName,
    required bool Function(String location) allowed,
    required String rejected,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = widget.document.path;
    final DocTarget? target;
    try {
      target = await ref
          .read(documentIoProvider)
          .pickSave(
            suggestedName: suggestedName,
            typeLabel: l10n.pdfFileType,
            near: path,
          );
    } on UnimplementedError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pickerUnavailable)));
      return null;
    }
    if (target == null || !mounted) return null;
    if (!allowed(target.location)) {
      messenger.showSnackBar(SnackBar(content: Text(rejected)));
      return null;
    }
    // Açık Inken dosyasının kendisi seçildiyse olağan kayıttır, sorulmaz.
    if (!isContentUri(target.location) &&
        File(target.location).existsSync() &&
        !samePath(target.location, path) &&
        !await _confirmOverwrite(target.name)) {
      return null;
    }
    return mounted ? target : null;
  }

  Future<bool> _saveAs() async {
    if (_session == null || _saving) return false;
    final l10n = AppLocalizations.of(context);
    final doc = widget.document;
    final target = await _pickTarget(
      suggestedName: doc.isInkenFile || doc.path == null
          ? doc.name
          : '${withoutPdfExtension(doc.name)}_inken.pdf',
      allowed: (t) => canSaveAsOver(doc, t),
      rejected: l10n.saveAsOntoOriginal,
    );
    return target != null && await _save(target: target);
  }

  /// Çizimleri sayfaya gömülü bir kopyaya dışa aktarır; yeri kullanıcı seçer.
  Future<void> _export() async {
    final session = _session;
    if (session == null || _exporting) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(openDocumentProvider.notifier);
    final path = widget.document.path;
    final target = await _pickTarget(
      suggestedName: l10n.exportFileName(
        withoutPdfExtension(widget.document.name),
      ),
      allowed: (t) => !samePath(t, path),
      rejected: l10n.exportOntoOpenFile,
    );
    if (target == null) return;
    setState(() => _exporting = true);
    try {
      final document = session.document;
      final skipped = await notifier.exportFlattened(
        document,
        target.location,
        images: await _imagesFor(session, document),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            skipped == 0
                ? l10n.exportedTo(target.name)
                : l10n.exportedWithSkipped(target.name, skipped),
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.exportFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Yazıcıya verilecek görseller: [document]'te kullanılanlar, çözülmüş.
  Future<Map<String, InkenImage>> _imagesFor(
    InkSession session,
    InkenDocument document,
  ) => session.images.forWriting(referencedImageIds(document));

  // ---- görsel

  bool _addingImage = false;

  /// Metin seçme aracı seçili mi (Ctrl+C / Ctrl+A metne gider)?
  bool get _selectingText => ref.read(toolProvider).tool == Tool.textSelect;

  /// Seçili PDF metnini sistem panosuna kopyalar; sonucu bildirir.
  Future<void> _copyText() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_controller.hasSelectedText) return;
    if (!_controller.isCopyAllowed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.textCopyNotAllowed)));
      return;
    }
    final ok = await _controller.copySelectedText();
    if (!ok || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.textCopied)));
  }

  /// Seçilenleri Inken panosuna kopyalar (metin seçme aracında seçili
  /// metni sistem panosuna).
  Future<void> _copy() async {
    if (_selectingText) return _copyText();
    final session = _session;
    if (session == null) return;
    await copySelection(
      ref,
      session,
      label: AppLocalizations.of(context).clipboardMarker,
    );
  }

  /// Seçilenleri kopyalayıp siler.
  Future<void> _cut() async {
    final session = _session;
    if (session == null || !session.hasSelection) return;
    final ids = session.selection;
    await _copy();
    if (!mounted || !identical(session, _session)) return;
    // Kopyalarken seçim değiştiyse silme yapılmaz.
    if (setEquals(ids, session.selection)) session.deleteSelection();
  }

  /// Geçerli sayfadaki her şeyi seçer (seç aracına geçer).
  void _selectAll() {
    if (_selectingText) {
      _controller.selectAllText();
      return;
    }
    final session = _session;
    if (session == null) return;
    _selectTool(Tool.select);
    session.selectAll(_currentPage(session));
  }

  int _currentPage(InkSession session) => (_controller.currentPage ?? 0).clamp(
    0,
    session.document.pages.length - 1,
  );

  /// Yapıştırır: Inken'den kopyalanan öğeler (sistem panosunda hâlâ onların
  /// işareti varsa), yoksa panodaki görsel.
  Future<void> _paste() async {
    final session = _session;
    if (session == null || _addingImage) return;
    final clip = ref.read(itemClipboardProvider);
    final ours = clip == null ? false : await clipboardHoldsMarker(clip);
    if (!mounted || !identical(session, _session)) return;
    if (clip != null && ours == true) return _pasteClip(session, clip);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Uint8List? bytes;
    try {
      bytes = await ref.read(clipboardServiceProvider).readImage();
    } on Object catch (e) {
      debugPrint('Pano okunamadı: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.clipboardNoImage)));
      return;
    }
    if (!mounted) return;
    if (bytes == null) {
      // Sistem panosu okunamadıysa Inken panosu yine yapıştırılır.
      if (clip != null && ours == null) return _pasteClip(session, clip);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.clipboardNoImage)));
      return;
    }
    await _addImage(bytes);
  }

  void _pasteClip(InkSession session, ItemClip clip) {
    _selectTool(Tool.select);
    pasteClip(session, clip, _currentPage(session));
  }

  /// Dosyadan görsel ekler (dosya seçici).
  Future<void> _insertImageFile() async {
    if (_session == null || _addingImage) return;
    final l10n = AppLocalizations.of(context);
    final bytes = await ref
        .read(documentIoProvider)
        .pickImage(typeLabel: l10n.imageFileType);
    if (bytes != null && mounted) await _addImage(bytes);
  }

  /// Pencereye bırakılan görsel dosyasını ekler.
  Future<void> _insertDroppedImage(String path) async {
    if (_session == null || _addingImage) return;
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on FileSystemException {
      if (mounted) _imageFailed();
      return;
    }
    if (mounted) await _addImage(bytes);
  }

  void _imageFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).imageUnreadable)),
    );
  }

  /// Görseli ekranın ortasındaki sayfaya, görünen kısmına ortalayarak ekler;
  /// seç aracına geçer ve görseli seçer (köşeden hemen boyutlandırılsın).
  Future<void> _addImage(Uint8List raw) async {
    final session = _session;
    if (session == null) return;
    setState(() => _addingImage = true);
    try {
      final prepared = await prepareImage(raw);
      if (!mounted || !identical(session, _session)) {
        prepared?.image.dispose();
        return;
      }
      if (prepared == null) return _imageFailed();
      final pages = session.document.pages;
      final page = (_controller.currentPage ?? 0).clamp(0, pages.length - 1);
      final layer = pages[page];
      // Sayfanın ekranda görünen kısmı, sayfa uzayında.
      var visible = (
        left: 0.0,
        top: 0.0,
        right: layer.width,
        bottom: layer.height,
      );
      final view = _gate.viewportOf(page);
      final area = _docKey.currentContext?.size;
      if (view != null && area != null) {
        // Kenarlardaki yüzen kutuların (araç kutusu, sayfa gezgini,
        // yakınlaştırma, kaydırma çubuğu) altı sayılmaz: tutamaklar
        // onların altında kalmasın.
        const band = Space.s3 + Sizes.target + Space.s3;
        var free = Rect.fromLTRB(
          band,
          band,
          area.width - band,
          area.height - band,
        );
        if (free.isEmpty) free = Offset.zero & area;
        final a = view.toPage(free.topLeft);
        final b = view.toPage(free.bottomRight);
        visible = (left: a.dx, top: a.dy, right: b.dx, bottom: b.dy);
      }
      final place = placeImage(
        pageWidth: layer.width,
        pageHeight: layer.height,
        visible: visible,
        pixelWidth: prepared.image.width,
        pixelHeight: prepared.image.height,
      );
      session.images.add(prepared.id, prepared.png, prepared.image);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _selectTool(Tool.select);
      session.insertImage(
        page,
        ImageItem(
          id: newItemId(),
          imageId: prepared.id,
          x: place.x,
          y: place.y,
          width: place.width,
          height: place.height,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingImage = false);
    }
  }

  bool _printing = false;

  /// Yazdırır: Inken'in yazdırma penceresi açılır (önizleme, yazıcı ve
  /// ayarlar). Yazdırılan, çizimleri gömülü (ya da çizimsiz) bir kopyadır;
  /// geçici klasöre yazılır, açık belge değişmez.
  Future<void> _print() async {
    final session = _session;
    final printer = ref.read(printServiceProvider);
    if (session == null || _printing || !printer.supported) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(openDocumentProvider.notifier);
    setState(() => _printing = true);
    Directory? folder;
    var keep = false;
    try {
      final root = Directory('${Directory.systemTemp.path}/inken-print');
      _cleanOldPrints(root);
      final dir = folder = Directory(
        '${root.path}/${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      final document = session.document;
      final images = await _imagesFor(session, document);
      final name = safeFileName(widget.document.name);
      Future<String> prepare({required bool drawings}) async {
        final file = File('${dir.path}/${drawings ? '' : 'cizimsiz-'}$name');
        await notifier.exportFlattened(
          drawings
              ? document
              : document.copyWith(
                  pages: [
                    for (final p in document.pages) p.copyWith(items: const []),
                  ],
                ),
          file.path,
          images: drawings ? images : const {},
        );
        return file.path;
      }

      final prepared = <bool, Future<String>>{};
      if (!mounted) return;
      final choice = await showPrintDialog(
        context,
        pageCount: document.pages.length,
        currentPage: _controller.currentPage ?? 0,
        preparePdf: ({required bool drawings}) =>
            prepared[drawings] ??= prepare(drawings: drawings),
        service: printer,
        settings: ref.read(settingsStoreProvider),
      );
      if (choice == null) return;
      final path = await (prepared[choice.drawings] ??= prepare(
        drawings: choice.drawings,
      ));
      final outcome = await printer.printPdf(
        path,
        title: widget.document.name,
        request: choice.request,
      );
      switch (outcome) {
        case PrintOutcome.printed:
          messenger.showSnackBar(SnackBar(content: Text(l10n.printSent)));
        case PrintOutcome.started:
          keep = true; // Android: iş bitince sistem tarafı siler.
        case PrintOutcome.cancelled:
          break;
      }
    } on PrinterUnsupported {
      messenger.showSnackBar(SnackBar(content: Text(l10n.printUnsupported)));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.printFailed(e.toString()))),
      );
    } finally {
      if (!keep && folder != null) {
        try {
          folder.deleteSync(recursive: true);
        } on Object catch (e) {
          debugPrint('Yazdırma dosyası silinemedi: $e');
        }
      }
      if (mounted) setState(() => _printing = false);
    }
  }

  /// Bir günden eski yazdırma çıktılarını siler (Windows'ta dış uygulamaya
  /// verilenler).
  bool _sharing = false;

  /// Paylaşır: ekrandaki hâl (kaydedilmemiş değişiklikler dahil),
  /// kaydetmedeki gibi düzenlenebilir PDF olarak geçici klasöre yazılır ve
  /// sistemin paylaşma yoluna verilir ([ShareService]). Açık dosya
  /// değişmez. Alan uygulama dosyayı sonra okuyabilir; eski kopyalar
  /// sonraki paylaşmada temizlenir.
  Future<void> _share() async {
    final session = _session;
    final sharer = ref.read(shareServiceProvider);
    if (session == null || _sharing || !sharer.supported) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(openDocumentProvider.notifier);
    setState(() => _sharing = true);
    try {
      final root = Directory('${Directory.systemTemp.path}/inken-share');
      _cleanOldPrints(root);
      final folder = Directory(
        '${root.path}/${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      final name = safeFileName(widget.document.name);
      final file = File('${folder.path}/$name');
      final document = session.document;
      await notifier.exportCopy(
        document,
        file.path,
        images: await _imagesFor(session, document),
      );
      final outcome = await sharer.sharePdf(file.path, name: name);
      switch (outcome) {
        case ShareOutcome.mailed:
          messenger.showSnackBar(SnackBar(content: Text(l10n.shareMailed)));
        case ShareOutcome.shown:
          messenger.showSnackBar(SnackBar(content: Text(l10n.shareShown)));
        case ShareOutcome.shared ||
            ShareOutcome.started ||
            ShareOutcome.dismissed:
          break;
      }
    } on ShareUnsupported {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareUnsupported)));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.shareFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static void _cleanOldPrints(Directory root) {
    if (!root.existsSync()) return;
    final limit = DateTime.now().subtract(const Duration(days: 1));
    for (final e in root.listSync()) {
      try {
        if (e.statSync().modified.isBefore(limit)) {
          e.deleteSync(recursive: true);
        }
      } on Object {
        // Kullanımda olabilir; sonra yeniden denenir.
      }
    }
  }

  Future<bool> _confirmOverwrite(String name) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.overwriteTitle),
        content: Text(l10n.overwriteBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.overwrite),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Kaydedilmemiş değişiklik varsa sorar; belge kapatılabilirse `true`.
  /// Kapatılacaksa yedek de silinir.
  Future<bool> _confirmClose() async {
    final closes = await _askToClose();
    if (closes) await _dropBackup(widget.document.path);
    return closes;
  }

  Future<bool> _askToClose() async {
    final session = _session;
    if (session == null || !session.isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<_CloseChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesBody),
        actions: [
          DialogActions(
            cancel: (
              label: l10n.cancel,
              onPressed: () => Navigator.pop(context, _CloseChoice.cancel),
            ),
            secondary: (
              label: l10n.discardChanges,
              onPressed: () => Navigator.pop(context, _CloseChoice.discard),
            ),
            primary: (
              label: l10n.save,
              onPressed: () => Navigator.pop(context, _CloseChoice.save),
            ),
          ),
        ],
      ),
    );
    return switch (choice) {
      _CloseChoice.discard => true,
      _CloseChoice.save => await _save(),
      _CloseChoice.cancel || null => false,
    };
  }

  Future<AppExitResponse> _onExitRequested() async {
    // Soru zaten açıkken pencereye yeniden basılırsa ikinci diyalog açılmaz.
    if (_askingToClose) return AppExitResponse.cancel;
    _askingToClose = true;
    try {
      return await _confirmClose()
          ? AppExitResponse.exit
          : AppExitResponse.cancel;
    } finally {
      _askingToClose = false;
    }
  }

  /// Tek boş sayfalık yeni PDF açar; açık belgede kaydedilmemiş değişiklik
  /// varsa önce sorar.
  Future<void> _newDocument() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirmClose() || !mounted) return;
    try {
      await ref
          .read(openDocumentProvider.notifier)
          .openNew(name: l10n.untitledDocument);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(openErrorMessage(l10n, e))),
      );
    }
  }

  /// Başka bir PDF açar: önce dosya seçilir, sonra (gerekirse) bu belgenin
  /// kaydedilmemiş değişiklikleri sorulur.
  Future<void> _openAnother() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(openDocumentProvider.notifier);
    final file = await notifier.pickPdf(typeLabel: l10n.pdfFileType);
    if (file == null || !mounted || !await _confirmClose()) return;
    try {
      await notifier.openPicked(file);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(openErrorMessage(l10n, e))),
      );
    }
  }

  /// Pencereye bırakılan PDF'i açar; açık belgede kaydedilmemiş değişiklik
  /// varsa önce sorar.
  Future<void> _openDropped(String path) => _openExternal(
    RecentDocument(
      location: path,
      name: displayNameOf(path, fallback: path),
      openedAt: DateTime.now(),
    ),
  );

  /// Başka bir uygulamanın gönderdiği PDF'i açar (bkz. [LaunchFile]).
  Future<void> _openIncoming() async {
    final RecentDocument? file;
    try {
      file = await ref.read(launchFileProvider).take();
    } on Object catch (e) {
      debugPrint('Gelen dosya alınamadı: $e');
      return;
    }
    if (file != null && mounted) await _openExternal(file);
  }

  /// Dışarıdan gelen belgeyi açar; açık belgede kaydedilmemiş değişiklik
  /// varsa önce sorar.
  Future<void> _openExternal(RecentDocument file) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirmClose() || !mounted) return;
    try {
      await ref.read(openDocumentProvider.notifier).openRecent(file);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(openErrorMessage(l10n, e))),
      );
    }
  }

  Future<void> _close() async {
    if (await _confirmClose() && mounted) {
      ref.read(openDocumentProvider.notifier).close();
    }
  }

  void _selectTool(Tool tool) {
    ref.read(toolProvider.notifier).select(tool);
    ref.read(toolOptionsProvider.notifier).close();
  }

  void _goPage(int delta) => _controller.goToPageBy(delta);

  bool _canSave(InkSession? session) =>
      session != null && !_saving && session.isDirty;

  /// Kayıt durumu: metin ve noktanın rengi; söylenecek bir şey yoksa `null`.
  ({String text, Color dot})? _status(InkSession? session) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    if (_saving) return (text: l10n.statusSaving, dot: c.inkFaint);
    if (session?.isDirty ?? false) {
      return (text: l10n.statusUnsaved, dot: c.lineStrong);
    }
    if (_savedOnce) return (text: l10n.statusSaved, dot: c.success);
    return null;
  }

  Future<void> _chooseTheme() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(themeModeProvider);
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          for (final (m, label) in themeChoices(l10n))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: m == current
                        ? Icon(LucideIcons.check, color: context.colors.brand)
                        : null,
                  ),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (mode != null) ref.read(themeModeProvider.notifier).set(mode);
  }

  /// Belge özellikleri penceresi.
  Future<void> _showProperties() async {
    final session = _session;
    if (session == null) return;
    final pages = session.document.pages;
    final current = _controller.currentPage;
    await showDocumentProperties(
      context,
      document: widget.document,
      pageCount: pages.length,
      currentPage: current != null && current < pages.length
          ? pages[current]
          : null,
    );
  }

  /// "Sayfaya git" penceresi.
  Future<void> _askGoToPage() async {
    final count = _controller.pageCount;
    if (count == 0) return;
    final page = await showGoToPageDialog(
      context,
      count: count,
      current: _controller.currentPage ?? 0,
    );
    if (page != null) await _controller.goToPage(page);
  }

  Future<void> _chooseInputMode() async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(toolProvider).inputMode;
    final mode = await showDialog<InputMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.inputMode),
        children: [
          for (final (m, label) in [
            (InputMode.auto, l10n.inputModeAuto),
            (InputMode.pen, l10n.inputModePen),
            (InputMode.touch, l10n.inputModeTouch),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: m == current
                        ? Icon(LucideIcons.check, color: context.colors.brand)
                        : null,
                  ),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (mode != null) ref.read(toolProvider.notifier).setInputMode(mode);
  }

  /// Menü çubuğunun (masaüstü) ve logo menüsünün (tablet) menüleri.
  /// Kısayollar menüde yalnızca gösterilir; asıl bağlar
  /// [CallbackShortcuts]'tadır. [barStyle] verilirse üst düzey başlıklar
  /// menü çubuğu biçimindedir.
  List<Widget> _menus(InkSession? session, {ButtonStyle? barStyle}) => appMenus(
    context,
    ref,
    barStyle: barStyle,
    onNew: _newDocument,
    onOpen: _openAnother,
    onSettings: _openSettings,
    onSelectTool: _selectTool,
    actions: _actions(session),
  );

  void _openSettings() => openSettingsPage(context);

  /// Menünün ve hızlı erişim çubuğunun ortak komutları.
  DocumentMenuActions _actions(InkSession? session) => DocumentMenuActions(
    save: _canSave(session) ? _save : null,
    saveAs: session == null || _saving ? null : _saveAs,
    export: session == null || _exporting ? null : _export,
    close: _close,
    undo: session?.canUndo ?? false ? session!.undo : null,
    redo: session?.canRedo ?? false ? session!.redo : null,
    deleteSelection: session?.hasSelection ?? false
        ? session!.deleteSelection
        : null,
    zoomIn: _controller.zoomIn,
    zoomOut: _controller.zoomOut,
    fitPage: _controller.fitPage,
    fitWidth: _controller.fitWidth,
    actualSize: () => _controller.setZoom(1),
    fullscreen: () => _setFullscreen(!_fullscreen),
    previousPage: () => _goPage(-1),
    nextPage: () => _goPage(1),
    goToPage: _askGoToPage,
    insertPage: session != null && session.canChangePages ? _insertPage : null,
    newPageOrientation: _effectiveOrientation(session),
    setNewPageOrientation: _setNewOrientation,
    newPageColor: _newColor,
    setNewPageColor: _setNewColor,
    deletePage: _canDeletePage(session) ? _deletePage : null,
    rotatePage: session != null && session.canChangePages
        ? _rotateCurrentPage
        : null,
    paste: session == null ? null : _paste,
    cut: session?.hasSelection ?? false ? _cut : null,
    copy: (session?.hasSelection ?? false) || _selectingText ? _copy : null,
    selectAll: session == null ? null : _selectAll,
    find: session == null ? null : _openSearch,
    properties: session == null ? null : _showProperties,
    pagePanel: ref.read(pagePanelProvider.notifier).toggle,
    insertImage: session == null ? null : _insertImageFile,
    spotlight: () => _toggleCover(StageCover.spotlight),
    curtain: () => _toggleCover(StageCover.curtain),
    print:
        session == null ||
            _printing ||
            !ref.read(printServiceProvider).supported
        ? null
        : _print,
    share:
        session == null || _sharing || !ref.read(shareServiceProvider).supported
        ? null
        : _share,
  );

  /// Masaüstünde menü çubuğunun altındaki, tablette üst çubuğun ortasındaki
  /// hızlı erişim çubuğu.
  Widget _quickBar(InkSession? session, {bool framed = true}) => QuickBar(
    onOpen: _openAnother,
    onSettings: _openSettings,
    actions: _actions(session),
    framed: framed,
  );

  /// Kayıt durumu (● Kaydedildi), menü çubuğunda sağa yaslı. Dosya adı
  /// pencerenin başlık çubuğundadır.
  Widget _statusLine(InkSession? session) {
    final c = context.colors;
    final status = _status(session);
    if (status == null) return const SizedBox.shrink();
    return Row(
      key: const ValueKey('save-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: status.dot),
        const SizedBox(width: Space.s2),
        Text(status.text, style: InkenText.label.copyWith(color: c.inkMuted)),
      ],
    );
  }

  /// Klasik menü çubuğu, yalnızca masaüstünde.
  Widget _menuBar(InkSession? session) => AppMenuBar(
    menus: (barStyle) => _menus(session, barStyle: barStyle),
    trailing: _statusLine(session),
  );

  /// Tablette menü çubuğunun yerine: logo düğmesi aynı menüleri açar.
  Widget _logoMenu(InkSession? session) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: _menus(session),
      builder: (context, menu, _) => IconButton(
        key: const ValueKey('app-menu'),
        tooltip: l10n.menu,
        icon: const InkenLogo(size: 32),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }

  /// Telefon: üst uygulama çubuğu (☰ · dosya adı + durum · geri al · ⋮).
  Widget _phoneAppBar(InkSession? session, {required double height}) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final status = _status(session);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: Space.s1),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('app-menu'),
            tooltip: l10n.menu,
            icon: const Icon(LucideIcons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: Space.s1),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InkenText.fileName.copyWith(color: c.ink),
                ),
                if (status != null)
                  Text(
                    status.text,
                    style: InkenText.caption.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('phone-tools'),
            tooltip: _phoneDock ? l10n.phoneToolsHide : l10n.phoneToolsShow,
            isSelected: _phoneDock,
            icon: const Icon(LucideIcons.penLine),
            style: IconButton.styleFrom(
              foregroundColor: c.ink,
              backgroundColor: _phoneDock ? c.brandTint : null,
            ),
            onPressed: () => _setPhoneDock(!_phoneDock),
          ),
          IconButton(
            key: const ValueKey('share'),
            tooltip: l10n.shareDocument,
            icon: const Icon(LucideIcons.share2),
            onPressed: _actions(session).share,
          ),
          IconButton(
            key: const ValueKey('undo'),
            tooltip: l10n.undo,
            icon: const Icon(LucideIcons.undo2),
            onPressed: session?.canUndo ?? false ? session!.undo : null,
          ),
          // Sabit genişlik ve sağ kenara hizalı: MenuAnchor sağa sığmayan
          // menüyü düğmenin soluna atar (ekranın ortasında açılırdı).
          MenuAnchor(
            alignmentOffset: const Offset(-Sizes.overflowMenu, 0),
            // Panel genişliği sabit kalsın (yoksa yazı kadar daralıp sola yaslanır).
            crossAxisUnconstrained: false,
            style: const MenuStyle(
              alignment: AlignmentDirectional.bottomEnd,
              fixedSize: WidgetStatePropertyAll(
                Size.fromWidth(Sizes.overflowMenu),
              ),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.redo2),
                onPressed: session?.canRedo ?? false ? session!.redo : null,
                child: Text(l10n.redo),
              ),
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.save),
                onPressed: _canSave(session) ? _save : null,
                child: Text(l10n.save),
              ),
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.clipboardPaste),
                onPressed: session == null ? null : _paste,
                child: Text(l10n.paste),
              ),
              MenuItemButton(
                leadingIcon: const Icon(LucideIcons.imagePlus),
                onPressed: session == null ? null : _insertImageFile,
                child: Text(l10n.insertImage),
              ),
            ],
            builder: (context, menu, _) => IconButton(
              key: const ValueKey('more'),
              tooltip: l10n.more,
              icon: const Icon(LucideIcons.ellipsisVertical),
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
            ),
          ),
        ],
      ),
    );
  }

  /// Telefon: yan menü, menü çubuğunun karşılığı.
  Widget _drawer(InkSession? session) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;

    Widget item(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      Widget? trailing,
      String? subtitle,
    }) => ListTile(
      minTileHeight: Sizes.target,
      enabled: onTap != null,
      shape: const StadiumBorder(),
      hoverColor: c.surfaceHover,
      splashColor: c.brandTint,
      leading: Icon(
        icon,
        size: 20,
        color: onTap == null ? c.inkFaint : c.inkMuted,
      ),
      title: Text(label, style: InkenText.menu),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: InkenText.caption.copyWith(color: c.inkMuted),
            ),
      trailing: trailing,
      onTap: onTap == null
          ? null
          : () {
              Navigator.pop(context);
              onTap();
            },
    );

    final mode = ref.watch(toolProvider).inputMode;
    return Drawer(
      width: Sizes.drawer,
      backgroundColor: c.surface,
      child: SafeArea(
        // Bölümler açılır kapanır (açık olanlar belge açıkken hatırlanır);
        // Ayarlar altta hep görünür.
        child: StatefulBuilder(
          builder: (context, setDrawer) {
            Widget section(String key, String label, List<Widget> items) {
              final open = _drawerOpen.contains(key);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    key: ValueKey('drawer-$key'),
                    minTileHeight: Sizes.target,
                    shape: const StadiumBorder(),
                    hoverColor: c.surfaceHover,
                    splashColor: c.brandTint,
                    title: Text(
                      label,
                      style: InkenText.label.copyWith(color: c.inkMuted),
                    ),
                    trailing: AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 20,
                        color: c.inkMuted,
                      ),
                    ),
                    onTap: () => setDrawer(
                      () =>
                          open ? _drawerOpen.remove(key) : _drawerOpen.add(key),
                    ),
                  ),
                  AnimatedSize(
                    duration: Motion.fast,
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: open
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: items,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Space.s3),
                  child: Row(
                    children: [
                      const InkenLogo(size: 40),
                      const SizedBox(width: Space.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.appTitle,
                              style: InkenText.heading.copyWith(color: c.ink),
                            ),
                            Text(
                              widget.document.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InkenText.caption.copyWith(
                                color: c.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s2),
                    children: [
                      section('file', l10n.menuFile, [
                        item(
                          LucideIcons.filePlus,
                          l10n.newDocument,
                          _newDocument,
                        ),
                        item(
                          LucideIcons.folderOpen,
                          l10n.openPdfMenu,
                          _openAnother,
                        ),
                        item(
                          LucideIcons.save,
                          l10n.save,
                          _canSave(session) ? _save : null,
                        ),
                        item(
                          LucideIcons.saveAll,
                          l10n.saveAs,
                          session == null || _saving ? null : _saveAs,
                        ),
                        item(
                          LucideIcons.fileDown,
                          l10n.exportFlattened,
                          session == null || _exporting ? null : _export,
                        ),
                        item(
                          LucideIcons.printer,
                          l10n.printDocument,
                          _actions(session).print,
                        ),
                        item(
                          LucideIcons.share2,
                          l10n.shareDocument,
                          _actions(session).share,
                        ),
                        item(
                          LucideIcons.fileText,
                          l10n.documentProperties,
                          session == null ? null : _showProperties,
                        ),
                        item(LucideIcons.x, l10n.closeDocument, _close),
                      ]),
                      section('edit', l10n.menuEdit, [
                        item(
                          LucideIcons.clipboardPaste,
                          l10n.paste,
                          session == null ? null : _paste,
                        ),
                        item(
                          LucideIcons.imagePlus,
                          l10n.insertImage,
                          session == null ? null : _insertImageFile,
                        ),
                        item(
                          LucideIcons.squareDashedMousePointer,
                          l10n.selectAll,
                          session == null ? null : _selectAll,
                        ),
                        item(
                          LucideIcons.textSelect,
                          l10n.toolTextSelect,
                          session == null
                              ? null
                              : () => _selectTool(Tool.textSelect),
                        ),
                      ]),
                      section('page', l10n.menuPage, [
                        item(
                          LucideIcons.chevronLeft,
                          l10n.previousPage,
                          () => _goPage(-1),
                        ),
                        item(
                          LucideIcons.chevronRight,
                          l10n.nextPage,
                          () => _goPage(1),
                        ),
                        item(LucideIcons.hash, l10n.goToPage, _askGoToPage),
                        item(
                          LucideIcons.search,
                          l10n.find,
                          session == null ? null : _openSearch,
                        ),
                      ]),
                      section('view', l10n.menuView, [
                        item(
                          LucideIcons.palette,
                          l10n.theme,
                          _chooseTheme,
                          subtitle: {
                            for (final (m, label) in themeChoices(l10n))
                              m: label,
                          }[ref.watch(themeModeProvider)],
                        ),
                        item(
                          LucideIcons.moon,
                          l10n.nightMode,
                          ref.read(nightModeProvider.notifier).toggle,
                          trailing: ref.watch(nightModeProvider)
                              ? Icon(LucideIcons.check, color: c.brand)
                              : null,
                        ),
                        item(
                          LucideIcons.maximize,
                          l10n.fullscreen,
                          () => _setFullscreen(true),
                        ),
                        item(
                          LucideIcons.scan,
                          l10n.fitPage,
                          _controller.fitPage,
                        ),
                        item(
                          LucideIcons.moveHorizontal,
                          l10n.fitWidth,
                          _controller.fitWidth,
                        ),
                        for (final mode in [
                          StageCover.spotlight,
                          StageCover.curtain,
                        ])
                          item(
                            stageCoverIcon(mode),
                            stageCoverLabel(l10n, mode),
                            () => _toggleCover(mode),
                            trailing: ref.watch(stageCoverProvider).mode == mode
                                ? Icon(LucideIcons.check, color: c.brand)
                                : null,
                          ),
                        item(
                          LucideIcons.hand,
                          l10n.inputMode,
                          _chooseInputMode,
                          subtitle: switch (mode) {
                            InputMode.auto => l10n.inputModeAuto,
                            InputMode.pen => l10n.inputModePen,
                            InputMode.touch => l10n.inputModeTouch,
                          },
                        ),
                      ]),
                      section('help', l10n.menuHelp, [
                        for (final (target, icon, label) in helpEntries(l10n))
                          item(
                            icon,
                            label,
                            () => openSettingsPage(context, initial: target),
                          ),
                        item(
                          LucideIcons.share2,
                          l10n.shareApp,
                          () => shareApp(context),
                        ),
                      ]),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.line),
                Padding(
                  padding: const EdgeInsets.all(Space.s2),
                  child: item(
                    LucideIcons.settings,
                    l10n.settingsMenu,
                    _openSettings,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Arama kutusu: telefonda üstte tam genişlikte; geniş ekranda sol altta
  /// (sayfa gezgininin solunda, araç kutusuyla çakışmaz).
  Widget _searchBox({required bool phone, required bool panelTab}) {
    final box = SearchBox(
      key: _searchKey,
      search: _controller.search,
      currentPage: () => _controller.currentPage,
      onClose: _closeSearch,
    );
    if (phone) {
      return Positioned(
        top: Space.s3,
        left: Space.s3,
        right: Space.s3,
        child: box,
      );
    }
    final left = (panelTab ? PanelGrip.width : 0) + Space.s3;
    return Positioned(
      left: left,
      bottom: Space.s4,
      child: LayoutBuilder(
        builder: (context, _) {
          // Ortadaki sayfa gezginine (~200 px) kadar.
          final room = MediaQuery.sizeOf(context).width / 2 - 130 - left;
          return SizedBox(width: room.clamp(220.0, 380.0), child: box);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = _session;
    // Metin seçme aracından çıkınca seçim kalmasın.
    ref.listen(toolProvider.select((t) => t.tool), (before, now) {
      if (before == Tool.textSelect && now != Tool.textSelect) {
        _controller.clearTextSelection();
      }
    });
    WindowTitle.set(
      AppLocalizations.of(context).windowTitle(widget.document.name),
    );
    final layout = InkenLayout.of(context);
    final phone = layout == InkenLayout.phone;
    if ((phone && !_phoneDock) != (_parkedTool != null)) {
      // Araç seçimi derleme sırasında değişmez; kareden sonra.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPhoneTool(phone: phone);
      });
    }
    final viewer = InkenPdfViewer(
      key: _viewerKey,
      // Inken açıklamaları gizlenmiş kopya: çizimleri katman çizer.
      data: _display ?? widget.document.displayBytes,
      password: widget.document.password,
      // Yeni düzen yeni ad: görüntüleyici belgeyi yeniden yükler.
      sourceName: _displayGen == 0
          ? widget.document.sourceName
          : '${widget.document.sourceName}#$_displayGen',
      controller: _controller,
      onLoaded: _onLoaded,
      backgroundColor: ref.watch(nightModeProvider) ? NightMode.desk : c.canvas,
      pageGap: phone ? Space.s3 : Space.s8,
      onLink: _openLink,
      linkColor: c.brand.withValues(alpha: 0.06),
      linkHoverColor: c.brand.withValues(alpha: 0.16),
      matchColor: c.accent.withValues(alpha: 0.28),
      activeMatchColor: c.accent.withValues(alpha: 0.6),
      textSelection: ref.watch(
        toolProvider.select((t) => t.tool == Tool.textSelect),
      ),
      pageColorFilter: ref.watch(nightModeProvider)
          ? NightMode.pageFilter
          : null,
    );
    // Araç kutusu: araç değişince ya da panel açıkken tam görünür.
    final dock = IdleFade(
      wakeKey: ref.watch(toolProvider.select((t) => t.tool)),
      keepAwake: ref.watch(toolOptionsProvider) != null,
      child: ToolDock(session: session),
    );
    // Sayfa panelinin sekmesi (tam ekran dışında) belgenin sol kenarında:
    // panel kapalıyken açar, açıkken panelin dışında, sağ kenarına bitişik
    // durur ve kapatır (panelin kaydırma çubuğuyla çakışmaz).
    final pagePanelOpen = ref.watch(pagePanelProvider);
    final pagePanelTab = !phone && !_fullscreen;
    // Yerleşim değişince (döndürme) belge alanı baştan kurulmasın.
    final doc = KeyedSubtree(
      key: _docKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: session == null
                ? viewer
                : InkLayer(geometry: _gate, session: session, child: viewer),
          ),
          // Ölçme araçları: çizimin üstünde, örtünün altında.
          if (session != null)
            Positioned.fill(
              child: InstrumentLayer(geometry: _gate, session: session),
            ),
          // Spot ışığı / perde: belgenin üstünde, yüzen kutuların altında.
          const Positioned.fill(child: StageCoverLayer()),
          // Sağ kenarda sayfa kaydırma çubuğu; masaüstünde yakınlaştırmanın
          // üstünde biter.
          if (ref.watch(pageScrollbarProvider))
            Positioned(
              right: 0,
              // Tam ekranda sağ üstteki çıkış düğmesinin altından başlar.
              top: _fullscreen && !phone
                  ? Space.s3 + Sizes.target + Space.s2
                  : Space.s3,
              bottom: phone ? Space.s4 : Space.s4 + Sizes.target + Space.s3,
              child: IdleFade(child: PageScrollbar(scroller: _controller)),
            ),
          if (_searchOpen) _searchBox(phone: phone, panelTab: pagePanelTab),
          if (phone)
            Positioned(
              left: 0,
              right: 0,
              bottom: Space.s4,
              child: Center(child: _PageChip(viewer: _controller)),
            )
          else ...[
            // Sol kenarda sayfa paneli sekmesi (açar / kapatır).
            if (pagePanelTab)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: PanelGrip.width,
                child: Center(
                  child: IdleFade(
                    child: PanelGrip(
                      opens: !pagePanelOpen,
                      onTap: () => ref
                          .read(pagePanelProvider.notifier)
                          .set(!pagePanelOpen),
                    ),
                  ),
                ),
              ),
            // Yüzen araç kutusu, seçilen kenarda: altta ve yanlarda sayfa
            // gezgininin üstünde biter, sağda kaydırma çubuğunu bırakır, tam
            // ekranda sağ üstteki çıkış düğmesinin altından başlar.
            dockPositioned(
              ref.watch(toolDockProvider),
              dock,
              top: _fullscreen ? Space.s3 + Sizes.target + Space.s2 : Space.s3,
              bottom: Space.s4 + Sizes.target + Space.s3,
              // Soldaki kutu panel sekmesinin yanında.
              left: pagePanelTab ? PanelGrip.width + Space.s2 : Space.s3,
              right:
                  Space.s3 +
                  (ref.watch(pageScrollbarProvider)
                      ? PageScrollbar.hitWidth
                      : 0),
            ),
            // Sayfa gezgini alt ortada, yakınlaştırma sağ altta.
            Positioned(
              left: 0,
              right: 0,
              bottom: Space.s4,
              child: Center(
                child: IdleFade(child: PageNav(viewer: _controller)),
              ),
            ),
            Positioned(
              right: Space.s4,
              bottom: Space.s4,
              child: IdleFade(
                child: ZoomControl(
                  viewer: _controller,
                  slider: MediaQuery.sizeOf(context).width >= 960,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final exitFullscreen = Positioned(
      top: Space.s3,
      right: Space.s3,
      child: IdleFade(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceRaised.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(Radii.pill),
            boxShadow: c.shadowPop,
          ),
          child: IconButton(
            key: const ValueKey('exit-fullscreen'),
            tooltip: AppLocalizations.of(context).exitFullscreen,
            icon: const Icon(LucideIcons.minimize),
            onPressed: () => _setFullscreen(false),
          ),
        ),
      ),
    );

    final Widget body;
    if (_fullscreen && !phone) {
      // Yalnızca belge ve yüzen kutular.
      body = Stack(
        children: [
          Positioned.fill(child: doc),
          exitFullscreen,
        ],
      );
    } else if (phone) {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final appBar = ListenableBuilder(
        listenable: session ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) =>
            _phoneAppBar(session, height: landscape ? 48 : Sizes.appbarM),
      );
      // Tam ekranda üst çubuk gizlenir; araç rafı kalır.
      final docArea = _fullscreen
          ? Stack(
              children: [
                Positioned.fill(child: doc),
                exitFullscreen,
              ],
            )
          : doc;
      body = landscape
          ? Row(
              children: [
                if (_phoneDock) const MobileDock(vertical: true),
                Expanded(
                  child: Column(
                    children: [
                      if (!_fullscreen) appBar,
                      Expanded(child: docArea),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                if (!_fullscreen) appBar,
                Expanded(child: docArea),
                if (_phoneDock) const MobileDock(),
              ],
            );
    } else {
      final desktop = layout == InkenLayout.desktop;
      final quickBar = ref.watch(quickBarProvider);
      // Masaüstünde menü çubuğu ve altında hızlı erişim çubuğu, tablette
      // logo menülü ince çubuk (hızlı erişim ortasında); araçların hepsi
      // yüzen kutuda.
      final chrome = DecoratedBox(
        decoration: BoxDecoration(color: c.surface, boxShadow: c.shadowBar),
        child: ListenableBuilder(
          listenable: session ?? const AlwaysStoppedAnimation(0),
          builder: (context, _) => desktop
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuBar(session),
                    if (quickBar) _quickBar(session),
                  ],
                )
              : InkToolbar(
                  leading: _logoMenu(session),
                  middle: quickBar ? _quickBar(session, framed: false) : null,
                  trailing: _statusLine(session),
                ),
        ),
      );
      // Solda sayfa küçük resimleri (açıksa).
      final docArea = ref.watch(pagePanelProvider)
          ? Row(
              children: [
                PagePanel(
                  viewer: _controller,
                  session: session,
                  night: ref.watch(nightModeProvider),
                  actions: session == null
                      ? null
                      : PagePanelActions(
                          rotate: _rotatePages,
                          insert: _insertPageAt,
                          delete: _deletePages,
                          orientation: _effectiveOrientation(session),
                          setOrientation: _setNewOrientation,
                          color: _newColor,
                          setColor: _setNewColor,
                        ),
                ),
                Expanded(child: doc),
              ],
            )
          : doc;
      // Krom belgenin üstünde çizilir: alt gölgesi sayfaya düşer.
      body = Stack(
        children: [
          Positioned.fill(
            top: desktop
                ? Sizes.menubar + (quickBar ? Sizes.quickbar + 1 : 0)
                : Sizes.appbarM,
            child: docArea,
          ),
          Positioned(top: 0, left: 0, right: 0, child: chrome),
        ],
      );
    }

    // Geri tuşu uygulamayı arka plana atmasın; belgeyi kapatsın.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: phone
            ? ListenableBuilder(
                listenable: session ?? const AlwaysStoppedAnimation(0),
                builder: (context, _) => _drawer(session),
              )
            : null,
        // Android'de durum çubuğu / kamera çentiği altına girmesin.
        body: SafeArea(
          child: PdfDropTarget(
            onPdf: _openDropped,
            onImage: session == null ? null : _insertDroppedImage,
            child: body,
          ),
        ),
      ),
    );
  }

  /// Klavye kısayolları. Odaktan bağımsız çalışır (odak düğümü menü
  /// çubuğunun ilk tıklamada açılmasını aralıklı olarak bozuyordu); metin
  /// yazılırken ve üstte diyalog varken devre dışıdır.
  /// Kısayol → komut. Tuşlar `shortcuts.dart`'taki katalogdadır (Ayarlar →
  /// Kısayollar aynı tablodan listeler).
  Map<AppShortcut, VoidCallback> get _shortcuts => {
    AppShortcut.newDocument: _newDocument,
    AppShortcut.save: _save,
    AppShortcut.open: _openAnother,
    AppShortcut.close: _close,
    AppShortcut.saveAs: _saveAs,
    AppShortcut.print: _print,
    AppShortcut.undo: () => _session?.undo(),
    AppShortcut.redo: () => _session?.redo(),
    AppShortcut.paste: _paste,
    AppShortcut.copy: _copy,
    AppShortcut.cut: _cut,
    AppShortcut.selectAll: _selectAll,
    AppShortcut.find: _openSearch,
    AppShortcut.documentProperties: _showProperties,
    AppShortcut.toolPen: () => _selectTool(Tool.pen),
    AppShortcut.toolHighlighter: () => _selectTool(Tool.highlighter),
    AppShortcut.toolEraser: () => _selectTool(Tool.eraser),
    AppShortcut.toolLaser: () => _selectTool(Tool.laser),
    AppShortcut.toolSelect: () => _selectTool(Tool.select),
    AppShortcut.toolShape: () => _selectTool(Tool.shape),
    AppShortcut.toolText: () => _selectTool(Tool.text),
    AppShortcut.spotlight: () => _toggleCover(StageCover.spotlight),
    AppShortcut.curtain: () => _toggleCover(StageCover.curtain),
    AppShortcut.deleteSelection: () => _session?.deleteSelection(),
    AppShortcut.goToPage: _askGoToPage,
    AppShortcut.rotateRight: () => _rotateCurrentPage(1),
    AppShortcut.rotateLeft: () => _rotateCurrentPage(-1),
    AppShortcut.settings: _openSettings,
    AppShortcut.escape: _escape,
    AppShortcut.fullscreen: () => _setFullscreen(!_fullscreen),
    AppShortcut.zoomIn: _controller.zoomIn,
    AppShortcut.zoomOut: _controller.zoomOut,
    AppShortcut.fitPage: _controller.fitPage,
    AppShortcut.fitWidth: _controller.fitWidth,
    AppShortcut.actualSize: () => _controller.setZoom(1),
    AppShortcut.previousPage: () => _goPage(-1),
    AppShortcut.nextPage: () => _goPage(1),
    AppShortcut.firstPage: () => _controller.goToPage(0),
    AppShortcut.lastPage: () => _controller.goToPage(_controller.pageCount - 1),
  };

  /// Boşluk basılıyken geçici el aracından önceki araç; basılı değilken
  /// `null`.
  Tool? _toolBeforeSpace;
  DateTime? _spaceDownAt;
  bool _spaceShift = false;

  /// Bundan kısa basış "dokunuş" sayılır (sayfa çevirir).
  static const _spaceTap = Duration(milliseconds: 300);

  /// Boşluk (Acrobat gibi): kısa basış sonraki sayfa (Shift ile önceki);
  /// basılı tutmak geçici el aracı, bırakınca önceki araç döner.
  bool _onSpace(KeyEvent event) {
    if (event is KeyRepeatEvent) return true;
    final tools = ref.read(toolProvider.notifier);
    if (event is KeyDownEvent) {
      if (_spaceDownAt != null) return true;
      _spaceDownAt = DateTime.now();
      _spaceShift = HardwareKeyboard.instance.isShiftPressed;
      final current = ref.read(toolProvider).tool;
      if (current != Tool.hand) {
        _toolBeforeSpace = current;
        tools.select(Tool.hand);
      }
      return true;
    }
    if (event is KeyUpEvent) {
      final down = _spaceDownAt;
      _spaceDownAt = null;
      final before = _toolBeforeSpace;
      _toolBeforeSpace = null;
      if (before != null && ref.read(toolProvider).tool == Tool.hand) {
        tools.select(before);
      }
      if (down != null && DateTime.now().difference(down) < _spaceTap) {
        _goPage(_spaceShift ? -1 : 1);
      }
      return true;
    }
    return false;
  }

  bool _onKey(KeyEvent event) {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) return _onSpace(event);
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final shortcuts = _shortcuts;
    assert(
      shortcuts.length == AppShortcut.values.length,
      'Katalogdaki her kısayol bir komuta bağlı olmalı',
    );
    final hit = matchShortcut(event, shortcuts.keys.toSet());
    if (hit == null) return false;
    shortcuts[hit]!();
    return true;
  }
}

enum _CloseChoice { cancel, discard, save }

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Telefonda kaydırırken görünen "3 / 12" rozeti; 1,5 sn sonra kaybolur.
class _PageChip extends StatefulWidget {
  const _PageChip({required this.viewer});

  final InkenViewerController viewer;

  @override
  State<_PageChip> createState() => _PageChipState();
}

class _PageChipState extends State<_PageChip> {
  int? _page;
  bool _visible = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.viewer.addListener(_changed);
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.viewer.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final page = widget.viewer.currentPage;
    if (page == _page) return;
    final first = _page == null;
    setState(() {
      _page = page;
      _visible = !first && page != null;
    });
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final page = _page;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.normal,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s3,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: c.ink.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(
            page == null ? '' : '${page + 1} / ${widget.viewer.pageCount}',
            style: InkenText.numeric.copyWith(color: c.surface),
          ),
        ),
      ),
    );
  }
}
