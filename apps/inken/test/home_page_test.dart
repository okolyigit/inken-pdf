import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/app.dart';
import 'package:inken/features/backup/backup_store.dart';
import 'package:inken/features/ink/ink_toolbar.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken_core/inken_core.dart';
import 'package:inken/features/files/document_io.dart';
import 'package:inken/features/files/recent_documents.dart';
import 'package:inken/features/files/launch_file.dart';
import 'package:inken/features/settings/language.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/theme/theme_mode.dart';
import 'package:inken/theme/ui_scale.dart';
import 'package:inken/features/viewer/app_menus.dart';
import 'package:inken/features/viewer/quick_bar.dart';

/// Dosya sistemi yerine: yalnızca [present] içindeki yollar var.
class _FakeIo extends DocumentIo {
  _FakeIo(this.present);
  final Set<String> present;

  @override
  Future<PickedDocument?> pickOpen({required String typeLabel}) async => null;

  @override
  Future<DocTarget?> pickSave({
    required String suggestedName,
    required String typeLabel,
    String? near,
    SaveFormat format = SaveFormat.pdf,
  }) async => null;

  @override
  Future<Uint8List> read(String location) async =>
      throw FileSystemException('yok', location);

  @override
  Future<void> write(String location, Uint8List bytes) async {}

  @override
  Future<DocStat?> stat(String location) async =>
      present.contains(location) ? (size: 1, modified: DateTime(2026)) : null;
}

/// Uygulama açıkken dışarıdan dosya gelir (Android "Birlikte aç").
class _ArrivingFile extends LaunchFile {
  _ArrivingFile(this._arrivals) : super(null, arrivals: _arrivals.stream);
  final StreamController<void> _arrivals;
  RecentDocument? _next;

  void send(String location) {
    _next = RecentDocument(
      location: location,
      name: location.split('/').last,
      openedAt: DateTime.now(),
      writable: false,
    );
    _arrivals.add(null);
  }

  @override
  Future<RecentDocument?> take() async {
    final n = _next;
    _next = null;
    return n;
  }
}

/// Yedek yok (gerçek klasör okuması widget testinde tamamlanmaz).
class _NoBackups extends BackupStore {
  @override
  Future<List<InkenBackup>> list() async => const [];
}

/// Menü çubuğundaki başlık (tanıtımda aynı sözcük geçebilir).
Finder _menu(String label) =>
    find.descendant(of: find.byType(MenuBar), matching: find.text(label));

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('inken_home'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> pump(
    WidgetTester t, {
    List<RecentDocument> recents = const [],
    SettingsStore? settings,
    Set<String> present = const {},
    Size size = const Size(1280, 800),
    String? launch,
    LaunchFile? launchFile,
  }) async {
    t.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final container = ProviderContainer(
      overrides: [
        recentStoreProvider.overrideWithValue(RecentStore.memory(recents)),
        settingsStoreProvider.overrideWithValue(
          settings ?? SettingsStore.memory(),
        ),
        documentIoProvider.overrideWithValue(_FakeIo(present)),
        backupStoreProvider.overrideWithValue(_NoBackups()),
        launchFileProvider.overrideWithValue(launchFile ?? LaunchFile(launch)),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: container, child: const InkenApp()),
    );
    await t.pumpAndSettle();
    return container;
  }

  RecentDocument recent(String name, {DateTime? at, int pages = 12}) =>
      RecentDocument(
        location: '/belgeler/$name',
        name: name,
        openedAt: at ?? DateTime.now(),
        pageCount: pages,
      );

  testWidgets('son belge yoksa karşılama; masaüstünde menü çubuğu', (t) async {
    await pump(t);
    expect(find.text('PDF aç'), findsOneWidget);
    expect(find.text('Son açılanlar'), findsNothing);
    expect(find.byType(MenuBar), findsOneWidget);
    expect(_menu('Görünüm'), findsOneWidget);
  });

  testWidgets('son belgeler kart olarak, sırayla; bulunamayan soluk', (
    t,
  ) async {
    await pump(
      t,
      recents: [
        recent('limit.pdf'),
        recent(
          'turev.pdf',
          at: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      present: {'/belgeler/limit.pdf'},
    );
    expect(find.text('Son açılanlar'), findsOneWidget);
    expect(find.text('limit.pdf'), findsOneWidget);
    expect(find.text('turev.pdf'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('limit.pdf')).dx,
      lessThan(t.getTopLeft(find.text('turev.pdf')).dx),
    );
    expect(find.textContaining('Bugün'), findsOneWidget);
    expect(find.text('Dosya bulunamadı'), findsOneWidget);
  });

  testWidgets('açılamayan belge: uyarı ve listeden kaldırma', (t) async {
    final c = await pump(t, recents: [recent('yok.pdf')]);
    await t.tap(find.text('yok.pdf'));
    await t.pumpAndSettle();
    expect(find.textContaining('"yok.pdf" açılamadı'), findsOneWidget);
    await t.tap(find.text('Listeden kaldır'));
    await t.pumpAndSettle();
    expect(c.read(recentDocumentsProvider), isEmpty);
    expect(find.text('yok.pdf'), findsNothing);
  });

  testWidgets('belge açmadan tema değişir ve ayarlara yazılır', (t) async {
    final settings = SettingsStore.memory();
    final c = await pump(t, settings: settings);
    await t.tap(_menu('Görünüm'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tema'));
    await t.pumpAndSettle();
    await t.tap(find.text('Koyu'));
    await t.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(settings.get<String>('theme'), 'dark');
  });

  test(
    'ayarlar dosyaya yazılır ve yeniden okunur; bozuk dosya yok sayılır',
    () async {
      final s = await SettingsStore.load(directory: dir);
      s
        ..put('theme', 'dark')
        ..put('pageScrollbar', false);
      await s.flush();
      final again = await SettingsStore.load(directory: dir);
      expect(
        again.getEnum('theme', ThemeMode.values, ThemeMode.system),
        ThemeMode.dark,
      );
      expect(again.get<bool>('pageScrollbar'), isFalse);

      File('${dir.path}/settings.json').writeAsStringSync('{bozuk');
      final broken = await SettingsStore.load(directory: dir);
      expect(broken.get<String>('theme'), isNull);
    },
  );

  test('son belgeler dosyaya yazılır ve yeniden okunur', () async {
    final store = await RecentStore.load(directory: dir);
    final r = RecentDocument(
      location: '/a/ders.pdf',
      name: 'ders.pdf',
      openedAt: DateTime.utc(2026, 11, 12, 10),
      writable: false,
      pageCount: 7,
    );
    store.save([r]);
    await store.flush();
    final again = await RecentStore.load(directory: dir);
    final back = again.initial.single;
    expect(
      (back.location, back.name, back.openedAt, back.writable, back.pageCount),
      (r.location, r.name, r.openedAt, false, 7),
    );
  });

  testWidgets('telefonda logo menüsü; araç rafı yok (belgede açılır)', (
    t,
  ) async {
    await pump(t, size: const Size(400, 800), recents: [recent('a.pdf')]);
    expect(find.byType(MenuBar), findsNothing);
    expect(find.byKey(const ValueKey('app-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-pen')), findsNothing);
  });

  testWidgets('tam menü görünür; belgeye bağlı komutlar pasif', (t) async {
    await pump(t);
    for (final m in ['Dosya', 'Düzen', 'Görünüm', 'Sayfa', 'Araçlar']) {
      expect(_menu(m), findsOneWidget, reason: m);
    }
    await t.tap(_menu('Dosya'));
    await t.pumpAndSettle();
    MenuItemButton item(String label) => t.widget<MenuItemButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(item('Yeni').onPressed, isNotNull);
    expect(item('Aç…').onPressed, isNotNull);
    expect(item('Kaydet').onPressed, isNull);
    expect(item('Belgeyi kapat').onPressed, isNull);
  });

  testWidgets('araç kutusu pasif; tanıtım kartları görünür, gizlenebilir', (
    t,
  ) async {
    final settings = SettingsStore.memory();
    final c = await pump(t, settings: settings);
    expect(find.byType(ToolDock), findsOneWidget);
    // Pasif: dokunmak aracı değiştirmez, kısayol da çalışmaz.
    await t.tap(
      find.byKey(const ValueKey('tool-highlighter')),
      warnIfMissed: false,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.keyE);
    await t.pump();
    expect(c.read(toolProvider).tool, Tool.pen);

    expect(find.byKey(const ValueKey('home-intro')), findsOneWidget);
    for (final k in [
      'pen',
      'highlighter',
      'shape',
      'text',
      'eraser',
      'laser',
      'select',
      'hand',
      'undo',
      'save',
      'export',
      'backup',
      'fullscreen',
      'pages',
    ]) {
      expect(find.byKey(ValueKey('intro-$k')), findsOneWidget, reason: k);
    }
    await t.ensureVisible(find.byKey(const ValueKey('intro-hide')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('intro-hide')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-intro')), findsNothing);
    expect(settings.get<bool>('homeIntro'), isFalse);
    // Görünüm menüsünden geri gelir.
    await t.tap(_menu('Görünüm'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('menu-bars')));
    await t.pumpAndSettle();
    await t.tap(find.text('Açılışta tanıtımı göster'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-intro')), findsOneWidget);
  });

  testWidgets('menüde araçlar pasif', (t) async {
    await pump(t);
    await t.tap(_menu('Araçlar'));
    await t.pumpAndSettle();
    final pen = t.widget<RadioMenuButton<Tool>>(
      find.ancestor(
        of: find.text('Kalem'),
        matching: find.byType(RadioMenuButton<Tool>),
      ),
    );
    expect(pen.onChanged, isNull);
  });

  group('hızlı erişim çubuğu', () {
    IconButton quick(WidgetTester t, String id) =>
        t.widget<IconButton>(find.byKey(ValueKey('quick-$id')));

    testWidgets('masaüstünde menünün altında; belgeye bağlılar pasif', (
      t,
    ) async {
      await pump(t);
      final bar = find.byKey(const ValueKey('quick-bar'));
      expect(bar, findsOneWidget);
      expect(t.getTopLeft(bar).dy, t.getBottomLeft(find.byType(AppMenuBar)).dy);
      expect(quick(t, 'open').onPressed, isNotNull);
      expect(quick(t, 'settings').onPressed, isNotNull);
      for (final id in [
        'save',
        'export',
        'print',
        'insert-page',
        'delete-page',
        'go-to-page',
        'fullscreen',
      ]) {
        expect(quick(t, id).onPressed, isNull, reason: id);
      }
      // Düğmeler tam dokunma hedefi.
      expect(t.getSize(find.byKey(const ValueKey('quick-save'))).height, 48);
    });

    testWidgets('ayarlar sayfası: sekmeler, kalıcı ayarlar, kısayollar', (
      t,
    ) async {
      final settings = SettingsStore.memory();
      final c = await pump(t, settings: settings);
      await t.tap(find.byKey(const ValueKey('quick-settings')));
      await t.pumpAndSettle();
      // Geniş ekranda sol sütunda beş sekme.
      for (final s in ['appearance', 'input', 'shortcuts', 'about', 'info']) {
        expect(find.byKey(ValueKey('settings-tab-$s')), findsOneWidget);
      }
      expect(
        t.getCenter(find.byKey(const ValueKey('settings-tab-input'))).dx,
        lessThan(240),
      );

      await t.tap(find.byKey(const ValueKey('setting-quick-bar')));
      await t.pumpAndSettle();
      expect(c.read(quickBarProvider), isFalse);
      expect(settings.get<bool>('quickBar'), isFalse);

      await t.tap(find.byKey(const ValueKey('seg-ThemeMode.dark')));
      await t.pumpAndSettle();
      expect(c.read(themeModeProvider), ThemeMode.dark);

      await t.tap(find.byKey(const ValueKey('settings-tab-input')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('setting-input-touch')));
      await t.pumpAndSettle();
      expect(c.read(toolProvider).inputMode, InputMode.touch);
      expect(settings.get<String>('inputMode'), 'touch');

      await t.tap(find.byKey(const ValueKey('settings-tab-shortcuts')));
      await t.pumpAndSettle();
      expect(find.text('Farklı kaydet…'), findsOneWidget);
      expect(find.text('Page Down'), findsOneWidget);
      expect(find.text('F11'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('settings-tab-about')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-licenses')), findsOneWidget);
      expect(find.byKey(const ValueKey('about-version')), findsOneWidget);
      expect(
        find.text('https://github.com/okolyigit/inken-pdf'),
        findsOneWidget,
      );

      // Hakkında → Uygulama bilgileri; Kopyala panoya düz metin yazar.
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.tap(find.byKey(const ValueKey('about-info')));
      await t.pumpAndSettle();
      expect(find.text('PDF motoru'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('info-copy')));
      await t.pumpAndSettle();
      expect(copied, startsWith('Inken PDF\nSürüm: '));
      expect(copied, contains('PDF motoru: pdfrx '));
      expect(
        copied,
        contains('Kayıt formatı (inken.json): $currentFormatVersion'),
      );
      expect(find.text('Uygulama bilgileri panoya kopyalandı'), findsOneWidget);

      // Esc kapatır; çubuk kapalı kaldı.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-tab-about')), findsNothing);
      expect(find.byKey(const ValueKey('quick-bar')), findsNothing);
    });

    testWidgets('dil: sistem Türkçeyken İngilizce seçilir, kalıcı', (t) async {
      final settings = SettingsStore.memory();
      final c = await pump(t, settings: settings);
      expect(find.widgetWithText(SubmenuButton, 'Dosya'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('quick-settings')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('seg-AppLanguage.en')));
      await t.pumpAndSettle();
      expect(c.read(appLanguageProvider), AppLanguage.en);
      expect(settings.get<String>('language'), 'en');
      // Ayarlar sayfası anında İngilizce; dil adları her dilde aynı.
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.widgetWithText(SubmenuButton, 'File'), findsOneWidget);

      // Görünüm menüsünden Sistem'e dönülür: sistem Türkçe.
      await t.tap(find.widgetWithText(SubmenuButton, 'View'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('menu-language')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('menu-language-system')).first);
      await t.pumpAndSettle();
      expect(find.widgetWithText(SubmenuButton, 'Dosya'), findsOneWidget);
      expect(settings.get<String>('language'), 'system');
    });

    testWidgets('kaydedilmiş dil açılışta geçerli', (t) async {
      await pump(t, settings: SettingsStore.memory({'language': 'en'}));
      expect(find.widgetWithText(SubmenuButton, 'File'), findsOneWidget);
    });

    testWidgets('arayüz boyutu: her şey büyür, dokunuşlar doğru yere', (
      t,
    ) async {
      // Akıllı tahta: 1920 geniş ekran, %150 → 1280 mantıksal (masaüstü).
      final settings = SettingsStore.memory({'uiScale': 'larger'});
      final c = await pump(t, settings: settings, size: const Size(1920, 1080));
      // Ekranda 1,5 kat: 48'lik düğme 72.
      final save = t.getRect(find.byKey(const ValueKey('quick-save')));
      expect(save.height, closeTo(72, 0.01));
      // Uyarlanabilir yerleşim küçülen mantıksal genişliğe göre: 1920 / 1,5.
      final ctx = t.element(find.byKey(const ValueKey('quick-save')));
      expect(MediaQuery.sizeOf(ctx).width, closeTo(1920 / 1.5, 0.01));
      expect(MediaQuery.devicePixelRatioOf(ctx), closeTo(1.5, 0.01));
      // Dokunma ters dönüşümle: ayarlar açılır.
      await t.tap(find.byKey(const ValueKey('quick-settings')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('setting-ui-scale')), findsOneWidget);
      // Normal'e dönülür; kalıcı.
      await t.tap(find.byKey(const ValueKey('seg-UiScale.normal')));
      await t.pumpAndSettle();
      expect(c.read(uiScaleProvider), UiScale.normal);
      expect(settings.get<String>('uiScale'), 'normal');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const ValueKey('quick-save'))).height,
        closeTo(48, 0.01),
      );
    });

    testWidgets('Yardım menüsü: kısayollar, bilgiler, hakkında', (t) async {
      await pump(t);
      await t.tap(find.widgetWithText(SubmenuButton, 'Yardım'));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('help-guide')),
          matching: find.text('Başlarken'),
        ),
        findsOneWidget,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      for (final (key, check) in [
        ('help-shortcuts', 'Page Down'),
        ('help-info', 'PDF motoru'),
        ('help-about', 'https://github.com/okolyigit/inken-pdf'),
      ]) {
        await t.tap(find.widgetWithText(SubmenuButton, 'Yardım'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
        expect(find.text(check), findsOneWidget, reason: key);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
      }
    });

    testWidgets('dar ekranda sekmeler üstte', (t) async {
      await pump(t, size: const Size(400, 800));
      await t.tap(find.byKey(const ValueKey('app-menu')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(SubmenuButton, 'Düzen'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(MenuItemButton, 'Ayarlar…'));
      await t.pumpAndSettle();
      final a = t.getCenter(
        find.byKey(const ValueKey('settings-tab-appearance')),
      );
      final b = t.getCenter(find.byKey(const ValueKey('settings-tab-input')));
      expect(a.dy, b.dy);
      expect(b.dx, greaterThan(a.dx));
      // Uygulama bilgileri dar ekranda taşmadan (etiket değerin üstünde).
      // Sekme satırı yana kayar; son sekme kaydırılarak bulunur.
      await t.ensureVisible(find.byKey(const ValueKey('settings-tab-info')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('settings-tab-info')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final label = t.getRect(find.text('PDF motoru'));
      final value = t.getRect(find.byKey(const ValueKey('info-row-3')));
      expect(value.top, greaterThanOrEqualTo(label.bottom));
    });

    testWidgets('Ctrl+, ayarları açar; kapalı çubuk açılışta kapalı', (
      t,
    ) async {
      await pump(t, settings: SettingsStore.memory({'quickBar': false}));
      expect(find.byKey(const ValueKey('quick-bar')), findsNothing);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.comma);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-close')), findsOneWidget);
    });

    testWidgets('tablette üst çubuğun içinde', (t) async {
      await pump(t, size: const Size(900, 700));
      expect(find.byType(MenuBar), findsNothing);
      expect(find.byKey(const ValueKey('quick-settings')), findsOneWidget);
    });
  });

  testWidgets('PDF ile başlatılınca açmayı dener; açılamazsa söyler', (
    t,
  ) async {
    await pump(t, launch: '/belgeler/ödev.pdf');
    await t.pumpAndSettle();
    expect(find.textContaining('"ödev.pdf" açılamadı'), findsOneWidget);
  });

  testWidgets('uygulama açıkken gelen PDF açılmaya çalışılır', (t) async {
    final arrivals = StreamController<void>.broadcast();
    addTearDown(arrivals.close);
    final launch = _ArrivingFile(arrivals);
    await pump(t, launchFile: launch);
    expect(find.textContaining('açılamadı'), findsNothing);
    launch.send('content://indirilenler/sinav.pdf');
    await t.pumpAndSettle();
    expect(find.textContaining('"sinav.pdf" açılamadı'), findsOneWidget);
  });
}
