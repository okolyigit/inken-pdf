// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Inken PDF';

  @override
  String get homeTagline => 'PDF\'i aç, kalemini seç, dersini anlat.';

  @override
  String get openPdf => 'PDF aç';

  @override
  String openPdfFailed(String error) {
    return 'Dosya açılamadı: $error';
  }

  @override
  String get passwordTitle => 'Parola gerekli';

  @override
  String passwordPrompt(String name) {
    return '“$name” parolayla korunuyor. Açmak için parolayı yazın.';
  }

  @override
  String get passwordLabel => 'Parola';

  @override
  String get passwordWrong => 'Parola yanlış. Yeniden deneyin.';

  @override
  String get passwordShow => 'Parolayı göster';

  @override
  String get passwordHide => 'Parolayı gizle';

  @override
  String get passwordOpen => 'Aç';

  @override
  String get passwordNeeded =>
      'Dosya parolayla korunuyor; parola girilmeden açılamaz.';

  @override
  String get pdfFileType => 'PDF dosyaları';

  @override
  String get closeDocument => 'Belgeyi kapat';

  @override
  String pageCount(int count) {
    return '$count sayfa';
  }

  @override
  String get toolHand => 'Kaydır';

  @override
  String get toolPen => 'Kalem';

  @override
  String get toolHighlighter => 'Fosforlu';

  @override
  String get toolEraser => 'Silgi';

  @override
  String get undo => 'Geri al';

  @override
  String get redo => 'Yinele';

  @override
  String get thicknessThin => 'İnce';

  @override
  String get thicknessMedium => 'Orta';

  @override
  String get thicknessThick => 'Kalın';

  @override
  String get inputMode => 'Dokunma davranışı';

  @override
  String get inputModeAuto => 'Otomatik (kalem görülünce parmak kaydırır)';

  @override
  String get inputModePen => 'Kalem çizer, parmak kaydırır';

  @override
  String get inputModeTouch => 'Parmak çizer, iki parmak kaydırır';

  @override
  String get save => 'Kaydet';

  @override
  String savedTo(String name) {
    return 'Kaydedildi: $name';
  }

  @override
  String savedWithSkipped(String name, int count) {
    return 'Kaydedildi: $name. $count öğe PDF\'e yazılamadı; Inken\'de duruyor ama başka okuyucularda görünmez.';
  }

  @override
  String saveFailed(String error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get unsavedChangesTitle => 'Kaydedilmemiş değişiklikler';

  @override
  String get unsavedChangesBody =>
      'Çizimleriniz kaydedilmedi. Kapatmadan önce kaydedilsin mi?';

  @override
  String get discardChanges => 'Kaydetme';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get protectedFileWarning =>
      'Bu dosya şifreli ya da imzalı. Çizimler ayrı bir kopyaya kaydedilecek.';

  @override
  String get openNewerFormat =>
      'Bu dosya Inken\'in daha yeni bir sürümüyle kaydedilmiş. Açmak için uygulamayı güncelleyin.';

  @override
  String get openCorruptData =>
      'Dosyadaki Inken çizim verisi bozuk; çizimleri kaybetmemek için dosya açılmadı.';

  @override
  String get openPageMismatch =>
      'Dosyanın sayfaları başka bir programla değiştirilmiş; Inken çizimleri eşleştirilemediği için dosya açılmadı.';

  @override
  String get recoveryTitle => 'Kaydedilmemiş çizimler bulundu';

  @override
  String recoveryBody(String name, String time) {
    return '$name dosyasındaki çizimler $time tarihinde yedeklendi ama kaydedilmedi. Geri yüklensin mi?';
  }

  @override
  String get recoveryFileChanged =>
      'Dosya bu yedekten sonra değiştirilmiş. Geri yüklerseniz yedekteki çizimler dosyadakilerin yerine geçer (geri al ile dönülebilir).';

  @override
  String recoveryFileMissing(String path) {
    return '$path bulunamadı; dosya taşınmış ya da silinmiş olabilir. Yedek geri yüklenemiyor.';
  }

  @override
  String get recoveryRestore => 'Geri yükle';

  @override
  String get recoveryDelete => 'Yedeği sil';

  @override
  String get recoveryLater => 'Sonra';

  @override
  String get exportFlattened => 'Çizimleri gömerek dışa aktar…';

  @override
  String exportFileName(String base) {
    return '$base (çizimli).pdf';
  }

  @override
  String exportedTo(String name) {
    return 'Dışa aktarıldı: $name';
  }

  @override
  String exportedWithSkipped(String name, int count) {
    return 'Dışa aktarıldı: $name. $count öğe yazılamadı; kopyada eksik.';
  }

  @override
  String exportFailed(String error) {
    return 'Dışa aktarılamadı: $error';
  }

  @override
  String get exportOntoOpenFile =>
      'Açık dosyanın üzerine dışa aktarılamaz; başka bir ad seçin.';

  @override
  String get overwriteTitle => 'Dosya zaten var';

  @override
  String overwriteBody(String name) {
    return '$name zaten var. Üzerine yazılsın mı?';
  }

  @override
  String get overwrite => 'Üzerine yaz';

  @override
  String get saveAs => 'Farklı kaydet…';

  @override
  String get saveAsOntoOriginal =>
      'Orijinal PDF\'in üzerine kaydedilmez; başka bir ad seçin.';

  @override
  String get pickerUnavailable =>
      'Bu cihazda kayıt yeri seçmek henüz desteklenmiyor.';

  @override
  String get menuFile => 'Dosya';

  @override
  String get menuEdit => 'Düzen';

  @override
  String get menuTools => 'Araçlar';

  @override
  String get openPdfMenu => 'Aç…';

  @override
  String get newDocument => 'Yeni';

  @override
  String get untitledDocument => 'Adsız.pdf';

  @override
  String get menuView => 'Görünüm';

  @override
  String get menuPage => 'Sayfa';

  @override
  String get menu => 'Menü';

  @override
  String get more => 'Daha fazla';

  @override
  String get close => 'Kapat';

  @override
  String get zoom => 'Yakınlaştırma';

  @override
  String get zoomIn => 'Yakınlaştır';

  @override
  String get zoomOut => 'Uzaklaştır';

  @override
  String get fitPage => 'Sayfaya sığdır';

  @override
  String get fitWidth => 'Genişliğe sığdır';

  @override
  String get actualSize => 'Gerçek boyut (%100)';

  @override
  String get zoomOptions => 'Yakınlaştırma seçenekleri';

  @override
  String get previousPage => 'Önceki sayfa';

  @override
  String get nextPage => 'Sonraki sayfa';

  @override
  String get statusSaved => 'Kaydedildi';

  @override
  String get statusSaving => 'Kaydediliyor…';

  @override
  String get statusUnsaved => 'Kaydedilmedi';

  @override
  String get sectionColor => 'Renk';

  @override
  String get sectionThickness => 'Kalınlık';

  @override
  String get thicknessVeryThick => 'Çok kalın';

  @override
  String toolOptions(String tool) {
    return '$tool seçenekleri';
  }

  @override
  String get colorBlack => 'Siyah';

  @override
  String get colorBlue => 'Mavi';

  @override
  String get colorRed => 'Kırmızı';

  @override
  String get colorGreen => 'Yeşil';

  @override
  String get colorOrange => 'Turuncu';

  @override
  String get colorPurple => 'Mor';

  @override
  String get colorYellow => 'Sarı';

  @override
  String get colorPink => 'Pembe';

  @override
  String get toolLaser => 'Geçici kalem';

  @override
  String get sectionEraserMode => 'Silgi türü';

  @override
  String get eraserStroke => 'Çizgi';

  @override
  String get eraserPixel => 'Piksel';

  @override
  String get sectionSize => 'Boyut';

  @override
  String get sizeSmall => 'Küçük';

  @override
  String get sizeMedium => 'Orta';

  @override
  String get sizeLarge => 'Büyük';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get goToPage => 'Sayfaya git…';

  @override
  String get find => 'Bul…';

  @override
  String get searchHint => 'Belgede ara';

  @override
  String get searchNoResults => 'Sonuç yok';

  @override
  String searchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchNext => 'Sonraki';

  @override
  String get searchPrevious => 'Önceki';

  @override
  String get searchClose => 'Aramayı kapat';

  @override
  String get searchSearching => 'Aranıyor…';

  @override
  String goToPageLabel(int count) {
    return 'Sayfa numarası (1–$count)';
  }

  @override
  String get go => 'Git';

  @override
  String windowTitle(String name) {
    return '$name – Inken PDF';
  }

  @override
  String get goToPageTitle => 'Sayfaya git';

  @override
  String get colorBrick => 'Kiremit';

  @override
  String get menuBars => 'Çubuklar ve paneller';

  @override
  String get toolDock => 'Araç kutusu';

  @override
  String get dockTop => 'Üstte';

  @override
  String get dockLeft => 'Solda';

  @override
  String get fullscreen => 'Tam ekran';

  @override
  String get exitFullscreen => 'Tam ekrandan çık (Esc)';

  @override
  String get toolSelect => 'Seç';

  @override
  String get deleteSelection => 'Seçileni sil';

  @override
  String get fadeFloating => 'Kullanılmayan kutuları soldur';

  @override
  String get pageScrollbar => 'Sayfa kaydırma çubuğu';

  @override
  String get toolShape => 'Şekil';

  @override
  String get sectionShape => 'Şekil';

  @override
  String get shapeLine => 'Çizgi';

  @override
  String get shapeArrow => 'Ok';

  @override
  String get shapeRectangle => 'Dikdörtgen';

  @override
  String get shapeEllipse => 'Elips';

  @override
  String get shapeCoordinate => 'Koordinat düzlemi';

  @override
  String get sectionInstruments => 'Ölçme araçları';

  @override
  String get instrumentRuler => 'Cetvel';

  @override
  String get instrumentSetSquare => 'Gönye';

  @override
  String get instrumentProtractor => 'İletki';

  @override
  String get instrumentCompass => 'Pergel';

  @override
  String instrumentClose(String name) {
    return '$name kapat';
  }

  @override
  String instrumentCentimeters(String value) {
    return '$value cm';
  }

  @override
  String get recentTitle => 'Son açılanlar';

  @override
  String get recentRemove => 'Listeden kaldır';

  @override
  String get recentMissing => 'Dosya bulunamadı';

  @override
  String get recentUnsaved => 'Kaydedilmemiş değişiklik';

  @override
  String recentOpenFailed(String name) {
    return '\"$name\" açılamadı. Dosya taşınmış ya da silinmiş olabilir.';
  }

  @override
  String recentToday(String time) {
    return 'Bugün $time';
  }

  @override
  String recentYesterday(String time) {
    return 'Dün $time';
  }

  @override
  String recentPages(int count) {
    return '$count sayfa';
  }

  @override
  String get introTitle => 'Neler yapabilirsin';

  @override
  String get introSubtitle => 'Araç kutusu bir PDF açınca etkinleşir.';

  @override
  String get introHide => 'Gizle';

  @override
  String get introShowSetting => 'Açılışta tanıtımı göster';

  @override
  String get introToolsHeading => 'Araçlar';

  @override
  String get introLessonHeading => 'Ders sırasında';

  @override
  String get keySpace => 'Boşluk';

  @override
  String get introPen =>
      'Kalemle yaz; basınç algılayan kalemde çizgi bastıkça kalınlaşır. Renk ve kalınlık için araca ikinci kez dokun.';

  @override
  String get introHighlighter =>
      'Metnin üzerinden geç; alttaki yazı okunur kalır.';

  @override
  String get introShape =>
      'Çizgi, ok, dikdörtgen, elips, koordinat düzlemi. Shift ile kare ve daire. Panelde cetvel, gönye, iletki ve pergel: kalem kenarlarına yaslanır.';

  @override
  String get introEraser =>
      'Dokunduğun çizgiyi ya da yalnızca üzerinden geçtiğin kısmı siler. Kalemin silgi ucu da çalışır.';

  @override
  String get introLaser =>
      'Göstererek anlat: yazdığın birkaç saniyede kaybolur, belgeye girmez.';

  @override
  String get introSelect =>
      'Dokunarak ya da dikdörtgen çizerek seç; sürükleyerek taşı, köşeden büyüt, Delete ile sil.';

  @override
  String get introHand =>
      'Sayfayı sürükleyerek kaydır. Başka araçtayken boşluğu basılı tut: geçici olarak kaydırır.';

  @override
  String get introUndo => 'Her adım geri alınır; kaydettikten sonra da.';

  @override
  String get introSave =>
      'Çizimler PDF\'in içine kaydedilir ve her PDF okuyucuda görünür. Orijinal dosyanın üzerine yazılmaz.';

  @override
  String get introExport =>
      'Çizimleri sayfaya gömülü bir kopya oluşturur; öğrencilerle paylaşmak ve yazdırmak için.';

  @override
  String get introBackupTitle => 'Otomatik yedek';

  @override
  String get introBackup =>
      'Kaydedilmemiş çizimler dakikada bir yedeklenir; uygulama kapanırsa açılışta geri yüklenir.';

  @override
  String get introFullscreen =>
      'Menüler gizlenir, yalnızca sayfa ve araç kutusu kalır. Esc ile çıkılır.';

  @override
  String get introPagesTitle => 'Sayfalar arasında';

  @override
  String get introPages =>
      'Sayfa sayfa ilerle, sağdaki çubukla hızlıca git ya da sayfa numarasına dokunup yaz.';

  @override
  String get toolText => 'Metin';

  @override
  String get introText =>
      'Sayfaya dokun ve yaz; Enter yeni satır. Var olan metne dokununca düzenlenir. Türkçe harfler ve matematik işaretleri (√ π ≤ ∞) eksiksiz.';

  @override
  String get customColor => 'Özel renk';

  @override
  String get customColorNew => 'Yeni renk';

  @override
  String get colorHue => 'Ton';

  @override
  String get colorSaturationValue => 'Doygunluk ve parlaklık';

  @override
  String get colorHex => 'Renk kodu';

  @override
  String get colorHexInvalid => 'Geçersiz kod';

  @override
  String get colorChoose => 'Seç';

  @override
  String get quickBar => 'Hızlı erişim çubuğu';

  @override
  String get settings => 'Ayarlar';

  @override
  String get settingsMenu => 'Ayarlar…';

  @override
  String get printDocument => 'Yazdır…';

  @override
  String appendPage(String template) {
    return 'Sona sayfa ekle: $template';
  }

  @override
  String get insertPage => 'Sayfa ekle';

  @override
  String get deletePage => 'Sayfayı sil';

  @override
  String get rotatePage => 'Sayfayı döndür';

  @override
  String get rotateRight => 'Sağa döndür';

  @override
  String get rotateLeft => 'Sola döndür';

  @override
  String get pageOrientation => 'Sayfa yönü';

  @override
  String get orientationPortrait => 'Dikey';

  @override
  String get orientationLandscape => 'Yatay';

  @override
  String get insertPageBefore => 'Önüne sayfa ekle';

  @override
  String get movePageUp => 'Yukarı taşı';

  @override
  String get movePageDown => 'Aşağı taşı';

  @override
  String get insertPageAfter => 'Arkasına sayfa ekle';

  @override
  String get insertPageHere => 'Buraya sayfa ekle';

  @override
  String get pageActions => 'Sayfa işlemleri';

  @override
  String pagesSelected(int count) {
    return '$count sayfa seçili';
  }

  @override
  String get clearPageSelection => 'Seçimi kaldır';

  @override
  String deletePages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sayfayı sil',
      one: 'Sayfayı sil',
    );
    return '$_temp0';
  }

  @override
  String pagesDeleted(int count) {
    return '$count sayfa silindi';
  }

  @override
  String get exportShort => 'Dışa aktar';

  @override
  String get settingsInput => 'Kalem ve dokunma';

  @override
  String get settingsShortcuts => 'Kısayollar';

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String get shortcutSpaceHold => 'Basılı tut: geçici olarak kaydır';

  @override
  String get shortcutShiftShape =>
      'Şekil çizerken basılı tut: kare, daire, 15° adımlar';

  @override
  String get shortcutTextEnter => 'Metin yazarken: yeni satır';

  @override
  String get shortcutPagesView => 'Sayfa ve görünüm';

  @override
  String get shortcutFirstPage => 'İlk sayfa';

  @override
  String get shortcutLastPage => 'Son sayfa';

  @override
  String get keyWheel => 'Tekerlek';

  @override
  String get shortcutZoomWheel => 'Yakınlaştır / uzaklaştır';

  @override
  String get shortcutEscape =>
      'Paneli kapat, seçimi bırak, spot ışığını / perdeyi kapat, tam ekrandan çık';

  @override
  String get shortcutsNote =>
      'Çoğu kısayol belge açıkken çalışır (Ctrl+O ve Ctrl+, her yerde). Metin yazarken tek harfli kısayollar devre dışıdır.';

  @override
  String get aboutDescription =>
      'Hafif ve hızlı bir PDF okuyucu; üzerine yazıp çizebilirsin. Çizimler PDF\'in içine, her okuyucuda görünecek biçimde kaydedilir. Ücretsiz, hesap gerekmez.';

  @override
  String get aboutFonts =>
      'Yazı tipleri: Figtree, Fraunces, JetBrains Mono (SIL Open Font License) ve DejaVu Sans (Bitstream Vera lisansı).';

  @override
  String get aboutAppLicense =>
      'Inken PDF özgür yazılımdır: GNU Genel Kamu Lisansı sürüm 3 ya da sonraki sürümleri (GPL-3.0-or-later) koşullarıyla kullanabilir, değiştirebilir ve dağıtabilirsin. Hiçbir garanti verilmez. Deneme sürümüdür; önemli dosyalarının bir kopyasını ayrıca sakla.';

  @override
  String get aboutLicenses => 'Lisanslar';

  @override
  String get templateBlank => 'Boş';

  @override
  String get templateGrid => 'Kareli';

  @override
  String get templateDotted => 'Noktalı';

  @override
  String get templateLined => 'Çizgili';

  @override
  String get templateCoordinate => 'Koordinat düzlemi';

  @override
  String pageDeleted(int page) {
    return '$page. sayfa silindi';
  }

  @override
  String pageLayoutFailed(String error) {
    return 'Sayfalar hazırlanamadı: $error';
  }

  @override
  String get printSent => 'Yazıcıya gönderildi';

  @override
  String printFailed(String error) {
    return 'Yazdırılamadı: $error';
  }

  @override
  String get printUnsupported =>
      'Bu yazıcı PDF kabul etmiyor. Başka bir yazıcı seç ya da dışa aktarıp bir PDF okuyucudan yazdır.';

  @override
  String get shareDocument => 'Paylaş…';

  @override
  String get shareMailed => 'Dosya yeni e-postaya eklendi';

  @override
  String get shareShown =>
      'E-posta uygulaması bulunamadı; dosya klasöründe gösteriliyor';

  @override
  String shareFailed(String error) {
    return 'Paylaşılamadı: $error';
  }

  @override
  String get shareUnsupported =>
      'Bu sistemde dosya paylaşılamıyor. Kaydedip dosyayı kendin gönderebilirsin.';

  @override
  String get phoneToolsShow => 'Çizim araçlarını göster';

  @override
  String get phoneToolsHide => 'Çizim araçlarını gizle';

  @override
  String get dropPdfHere => 'PDF\'i açmak için bırak';

  @override
  String get dropOnlyPdf => 'Yalnızca PDF dosyaları açılabilir';

  @override
  String get dockBottom => 'Altta';

  @override
  String get dockRight => 'Sağda';

  @override
  String get dockMove => 'Araç kutusunu taşı (sürükle ya da dokun)';

  @override
  String get spotlight => 'Spot ışığı';

  @override
  String get curtain => 'Perde';

  @override
  String get spotlightResize =>
      'Büyüt / küçült (sürükle; tekerlek ya da iki parmak da olur)';

  @override
  String get spotlightClose => 'Spot ışığını kapat (Esc)';

  @override
  String get curtainClose => 'Perdeyi kapat (Esc)';

  @override
  String get curtainHint => 'Aşağı çekerek aç';

  @override
  String get introSpotlight =>
      'Sayfanın bir yerini aydınlat, gerisini karart. Karartıyı sürükleyerek ışığı gezdir; ışığın içinde yazmaya devam et.';

  @override
  String get introCurtain =>
      'Sayfayı örtüp aşağı çektikçe satır satır göster; yanıtı sona sakla.';

  @override
  String get paste => 'Yapıştır';

  @override
  String get insertImage => 'Görsel ekle…';

  @override
  String get imageFileType => 'Görseller';

  @override
  String get clipboardNoImage =>
      'Panoda görsel yok. Bir görseli ya da ekran görüntüsünü kopyalayıp yeniden dene.';

  @override
  String get imageUnreadable => 'Görsel açılamadı';

  @override
  String get dropOnlyPdfOrImage =>
      'Yalnızca PDF ve görsel dosyaları bırakılabilir';

  @override
  String get dropPdfOrImageHere => 'PDF\'i ya da görseli bırak';

  @override
  String get introImageTitle => 'Görsel';

  @override
  String get introImage =>
      'Kopyaladığın görseli ya da ekran görüntüsünü Ctrl+V ile yapıştır; seçili gelir, köşesinden büyütüp küçült. Dosyadan da eklenir, pencereye sürüklenir.';

  @override
  String get stageCover => 'Spot ışığı / perde';

  @override
  String get menuHelp => 'Yardım';

  @override
  String get aboutApp => 'Hakkında Inken PDF';

  @override
  String get settingsInfo => 'Uygulama bilgileri';

  @override
  String get keyboardShortcuts => 'Klavye kısayolları';

  @override
  String get guideMenu => 'Başlarken';

  @override
  String get guideFileName => 'Başlarken.pdf';

  @override
  String versionWithBuild(String version, String build) {
    return '$version (derleme $build)';
  }

  @override
  String aboutVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get aboutRepository => 'GitHub\'da Inken PDF';

  @override
  String get aboutRepositoryHint => 'Kaynak, sürümler ve geri bildirim';

  @override
  String get shareApp => 'Inken PDF\'i paylaş';

  @override
  String shareAppText(String url) {
    return 'Inken PDF: hafif, hızlı ve ücretsiz PDF okuyucu; üzerine yazıp çizebilirsin. Hesap gerekmez, açık kaynak: $url';
  }

  @override
  String get shareAppCopied => 'Tanıtım metni ve bağlantı panoya kopyalandı';

  @override
  String linkOpenFailed(String url) {
    return 'Bağlantı açılamadı: $url';
  }

  @override
  String get linkOpenTitle => 'Bağlantı açılsın mı?';

  @override
  String linkOpenBody(String url) {
    return '$url adresi tarayıcıda açılacak.';
  }

  @override
  String get linkOpen => 'Aç';

  @override
  String get infoIntro =>
      'Bir sorun bildirirken bu bilgileri ekle; neyin nerede olduğunu bulmayı kolaylaştırır.';

  @override
  String get infoCopy => 'Kopyala';

  @override
  String get infoCopied => 'Uygulama bilgileri panoya kopyalandı';

  @override
  String get infoVersion => 'Sürüm';

  @override
  String get infoPlatform => 'İşletim sistemi';

  @override
  String get infoDart => 'Dart';

  @override
  String get infoPdfEngine => 'PDF motoru';

  @override
  String get infoFormat => 'Kayıt formatı (inken.json)';

  @override
  String get infoLanguage => 'Dil';

  @override
  String get infoScreen => 'Ekran';

  @override
  String get infoStylusSeen => 'Kalem algılandı';

  @override
  String get infoDataFolder => 'Veri klasörü (ayarlar, yedekler)';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get language => 'Dil';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get toolHighlighterShort => 'Fosforlu';

  @override
  String get toolLaserShort => 'Geçici';

  @override
  String get copy => 'Kopyala';

  @override
  String get cut => 'Kes';

  @override
  String get selectAll => 'Tümünü seç';

  @override
  String recolorSelection(String color) {
    return 'Seçilenin rengi: $color';
  }

  @override
  String get clipboardMarker => 'Inken PDF öğeleri';

  @override
  String get selectionBar => 'Seçim';

  @override
  String get pagePanel => 'Sayfa küçük resimleri';

  @override
  String get pagePanelTitle => 'Sayfalar';

  @override
  String get pagePanelPages => 'Sayfalar';

  @override
  String get outline => 'İçindekiler';

  @override
  String get outlineEmpty => 'Bu belgede içindekiler yok.';

  @override
  String get outlineExpand => 'Alt başlıkları göster';

  @override
  String get outlineCollapse => 'Alt başlıkları gizle';

  @override
  String pageThumbnail(int page) {
    return 'Sayfa $page';
  }

  @override
  String get uiScale => 'Arayüz boyutu';

  @override
  String get uiScaleNormal => 'Normal';

  @override
  String get uiScaleLarge => 'Büyük';

  @override
  String get uiScaleLarger => 'Akıllı tahta';

  @override
  String get pagePanelClose => 'Sayfa panelini kapat';

  @override
  String get pagePanelOpen => 'Sayfa panelini aç';

  @override
  String get documentProperties => 'Belge özellikleri…';

  @override
  String get propertiesTitle => 'Belge özellikleri';

  @override
  String get propFile => 'Dosya';

  @override
  String get propLocation => 'Konum';

  @override
  String get propNotSaved => 'Henüz kaydedilmedi';

  @override
  String get propFileSize => 'Dosya boyutu';

  @override
  String get propTitle => 'Başlık';

  @override
  String get propAuthor => 'Yazar';

  @override
  String get propSubject => 'Konu';

  @override
  String get propKeywords => 'Anahtar sözcükler';

  @override
  String get propCreator => 'Oluşturan uygulama';

  @override
  String get propProducer => 'PDF üreticisi';

  @override
  String get propCreated => 'Oluşturulma';

  @override
  String get propModified => 'Değiştirilme';

  @override
  String get propVersion => 'PDF sürümü';

  @override
  String get propPages => 'Sayfa sayısı';

  @override
  String get propPageSize => 'Sayfa boyutu (bu sayfa)';

  @override
  String get propSecurity => 'Güvenlik';

  @override
  String get propPasswordProtected => 'Parolalı';

  @override
  String get propSigned => 'Dijital imzalı';

  @override
  String get propNoSecurity => 'Yok';

  @override
  String get propUnreadable => 'Bilgiler okunamadı.';

  @override
  String get propSectionDocument => 'Belge';

  @override
  String get propSectionFile => 'Dosya ve sayfalar';

  @override
  String get nightMode => 'Gece modu';

  @override
  String get pageColorWhite => 'Beyaz';

  @override
  String get pageColorBlack => 'Siyah';

  @override
  String get pageColorStraw => 'Saman kâğıdı';

  @override
  String get toolTextSelect => 'Metin seç';

  @override
  String get textCopied => 'Metin kopyalandı';

  @override
  String get textCopyNotAllowed => 'Bu belge metin kopyalamaya izin vermiyor.';

  @override
  String get copyText => 'Metni kopyala';

  @override
  String get bugReport => 'Hata bildir';

  @override
  String get bugReportTitle => 'Hatayı nasıl bildirmek istersin?';

  @override
  String get bugReportEmail => 'E-posta ile';

  @override
  String bugReportEmailHint(String email) {
    return '$email adresine. Hesap gerekmez; ekran görüntüsü de ekleyebilirsin.';
  }

  @override
  String get bugReportGitHub => 'GitHub\'da';

  @override
  String get bugReportGitHubHint =>
      'GitHub hesabı gerekir. Bildirim herkese açık görünür, gelişmesini oradan izleyebilirsin.';

  @override
  String get bugReportSubject => 'Inken PDF hata bildirimi';

  @override
  String get bugReportWhat => 'Ne oldu?';

  @override
  String get bugReportExpected => 'Ne olmasını bekliyordun?';

  @override
  String get bugReportSteps => 'Nasıl tekrarlanır?';

  @override
  String bugReportCopiedEmail(String email) {
    return 'E-posta uygulaması açılamadı. Bildirim metni panoya kopyalandı; $email adresine gönderebilirsin.';
  }

  @override
  String bugReportCopiedGitHub(String url) {
    return 'Tarayıcı açılamadı. Bildirim metni panoya kopyalandı; $url/issues adresine yapıştırabilirsin.';
  }

  @override
  String get aboutPrivacy =>
      'Gizlilik: Inken PDF hiçbir veri toplamaz ve internete bağlanmaz. Ayarların, son belgelerin ve yedeklerin yalnızca bu cihazda kalır.';

  @override
  String get sectionSelect => 'Neyi seçeceksin';

  @override
  String get selectDrawings => 'Çizimler';

  @override
  String get selectText => 'Metin';

  @override
  String get opacity => 'Opaklık';

  @override
  String percent(int value) {
    return '%$value';
  }

  @override
  String get editImage => 'Görseli düzenle';

  @override
  String get imageEditHint =>
      'Köşe ve kenarlardan sürükleyerek kırp; çerçevenin içinden tutup kaydır.';

  @override
  String get cropRatio => 'Kırpma oranı';

  @override
  String get cropFree => 'Serbest';

  @override
  String get cropOriginal => 'Orijinal';

  @override
  String get imageSizeOnPage => 'Sayfadaki boyut';

  @override
  String get imageWidth => 'Genişlik';

  @override
  String get imageHeight => 'Yükseklik';

  @override
  String get unitCm => 'cm';

  @override
  String get aspectLocked => 'En-boy oranı kilitli';

  @override
  String get aspectUnlocked => 'En-boy oranı serbest';

  @override
  String get aspectHint => 'Kilitliyken en-boy oranı korunur.';

  @override
  String get rotate => 'Döndür';

  @override
  String get rotateLeftShort => 'Sola';

  @override
  String get rotateRightShort => 'Sağa';

  @override
  String get resetEdits => 'Sıfırla';

  @override
  String get applyEdits => 'Uygula';

  @override
  String get printTitle => 'Yazdır';

  @override
  String get printPrinter => 'Yazıcı';

  @override
  String get printNoPrinter => 'Yazıcı bulunamadı';

  @override
  String get printDefaultPrinter => 'varsayılan yazıcı';

  @override
  String get printCopies => 'Kopya';

  @override
  String get printPages => 'Sayfalar';

  @override
  String get printPagesAll => 'Tümü';

  @override
  String get printPagesCurrent => 'Geçerli sayfa';

  @override
  String get printPagesCurrentShort => 'Geçerli';

  @override
  String get printPagesRange => 'Aralık';

  @override
  String get printRangeHint => 'ör. 1-3, 5';

  @override
  String printRangeInvalid(int count) {
    return 'Geçersiz aralık (1–$count)';
  }

  @override
  String get printSize => 'Boyut';

  @override
  String get printFit => 'Sayfaya sığdır';

  @override
  String get printActual => 'Gerçek boyut';

  @override
  String get printDrawings => 'Çizimleri yazdır';

  @override
  String get printMore => 'Diğer seçenekler';

  @override
  String get printColor => 'Renk';

  @override
  String get printColorOn => 'Renkli';

  @override
  String get printGray => 'Gri tonlamalı';

  @override
  String get printDuplex => 'Çift taraflı';

  @override
  String get printDuplexOff => 'Kapalı';

  @override
  String get printDuplexLong => 'Uzun kenardan çevir';

  @override
  String get printDuplexShort => 'Kısa kenardan çevir';

  @override
  String get printPaper => 'Kâğıt';

  @override
  String get printOrientation => 'Yönlendirme';

  @override
  String get printOrientationAuto => 'Otomatik';

  @override
  String get printPortrait => 'Dikey';

  @override
  String get printLandscape => 'Yatay';

  @override
  String get printOrientationHint =>
      'Otomatik: yatay sayfalar kâğıda sığacak şekilde döndürülür.';

  @override
  String get printCollate => 'Kopyaları harmanla';

  @override
  String get printReverse => 'Sayfaları ters sırala';

  @override
  String get printProperties => 'Yazıcı özellikleri…';

  @override
  String get printPropertiesHint =>
      'Yazıcının kendi ayar penceresi: baskı kalitesi, kâğıt türü.';

  @override
  String printSummary(int pages, int copies) {
    return '$pages sayfa · $copies kopya';
  }

  @override
  String get printContinue => 'Devam';

  @override
  String get printAndroidHint =>
      'Yazıcı, kopya sayısı ve renk bir sonraki ekranda seçilir.';

  @override
  String get printPreparing => 'Hazırlanıyor…';

  @override
  String printPreviewLabel(int page) {
    return 'Sayfa $page önizlemesi';
  }

  @override
  String get printDecrease => 'Azalt';

  @override
  String get printIncrease => 'Artır';

  @override
  String get printPrevPage => 'Önceki sayfa';

  @override
  String get printNextPage => 'Sonraki sayfa';

  @override
  String get captureRegion => 'Bölge yakala';

  @override
  String get captureHint =>
      'Yakalamak istediğin alanı çerçeve içine al; sayfanın tamamı için sayfaya dokun.';

  @override
  String get captureBar => 'Yakalama';

  @override
  String get captureSave => 'Kaydet…';

  @override
  String get captureShare => 'Paylaş…';

  @override
  String get captureToNewPage => 'Yeni sayfaya al';

  @override
  String get captureToNewPageHint =>
      'Yakalanan alanı arkasına eklenen boş sayfanın üstüne koyar; altında çözebilirsin.';

  @override
  String get captureCopied => 'Görsel panoya kopyalandı';

  @override
  String get captureCopyUnsupported =>
      'Bu sistemde panoya görsel kopyalanamıyor; kaydedip paylaşabilirsin.';

  @override
  String captureFailed(String error) {
    return 'Görüntü alınamadı: $error';
  }

  @override
  String captureFileName(String base, int page) {
    return '$base - sayfa $page.png';
  }

  @override
  String get pngFileType => 'PNG görseli';

  @override
  String get sharePageImage => 'Sayfayı görsel olarak paylaş…';
}
