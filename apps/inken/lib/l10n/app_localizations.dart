import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF'**
  String get appTitle;

  /// No description provided for @homeTagline.
  ///
  /// In tr, this message translates to:
  /// **'PDF\'i aç, kalemini seç, dersini anlat.'**
  String get homeTagline;

  /// No description provided for @openPdf.
  ///
  /// In tr, this message translates to:
  /// **'PDF aç'**
  String get openPdf;

  /// No description provided for @openPdfFailed.
  ///
  /// In tr, this message translates to:
  /// **'Dosya açılamadı: {error}'**
  String openPdfFailed(String error);

  /// No description provided for @passwordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Parola gerekli'**
  String get passwordTitle;

  /// No description provided for @passwordPrompt.
  ///
  /// In tr, this message translates to:
  /// **'“{name}” parolayla korunuyor. Açmak için parolayı yazın.'**
  String passwordPrompt(String name);

  /// No description provided for @passwordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Parola'**
  String get passwordLabel;

  /// No description provided for @passwordWrong.
  ///
  /// In tr, this message translates to:
  /// **'Parola yanlış. Yeniden deneyin.'**
  String get passwordWrong;

  /// No description provided for @passwordShow.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı göster'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı gizle'**
  String get passwordHide;

  /// No description provided for @passwordOpen.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get passwordOpen;

  /// No description provided for @passwordNeeded.
  ///
  /// In tr, this message translates to:
  /// **'Dosya parolayla korunuyor; parola girilmeden açılamaz.'**
  String get passwordNeeded;

  /// No description provided for @pdfFileType.
  ///
  /// In tr, this message translates to:
  /// **'PDF dosyaları'**
  String get pdfFileType;

  /// No description provided for @closeDocument.
  ///
  /// In tr, this message translates to:
  /// **'Belgeyi kapat'**
  String get closeDocument;

  /// No description provided for @pageCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} sayfa'**
  String pageCount(int count);

  /// No description provided for @toolHand.
  ///
  /// In tr, this message translates to:
  /// **'Kaydır'**
  String get toolHand;

  /// No description provided for @toolPen.
  ///
  /// In tr, this message translates to:
  /// **'Kalem'**
  String get toolPen;

  /// No description provided for @toolHighlighter.
  ///
  /// In tr, this message translates to:
  /// **'Fosforlu'**
  String get toolHighlighter;

  /// No description provided for @toolEraser.
  ///
  /// In tr, this message translates to:
  /// **'Silgi'**
  String get toolEraser;

  /// No description provided for @undo.
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In tr, this message translates to:
  /// **'Yinele'**
  String get redo;

  /// No description provided for @thicknessThin.
  ///
  /// In tr, this message translates to:
  /// **'İnce'**
  String get thicknessThin;

  /// No description provided for @thicknessMedium.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get thicknessMedium;

  /// No description provided for @thicknessThick.
  ///
  /// In tr, this message translates to:
  /// **'Kalın'**
  String get thicknessThick;

  /// No description provided for @inputMode.
  ///
  /// In tr, this message translates to:
  /// **'Dokunma davranışı'**
  String get inputMode;

  /// No description provided for @inputModeAuto.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik (kalem görülünce parmak kaydırır)'**
  String get inputModeAuto;

  /// No description provided for @inputModePen.
  ///
  /// In tr, this message translates to:
  /// **'Kalem çizer, parmak kaydırır'**
  String get inputModePen;

  /// No description provided for @inputModeTouch.
  ///
  /// In tr, this message translates to:
  /// **'Parmak çizer, iki parmak kaydırır'**
  String get inputModeTouch;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @savedTo.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi: {name}'**
  String savedTo(String name);

  /// No description provided for @savedWithSkipped.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi: {name}. {count} öğe PDF\'e yazılamadı; Inken\'de duruyor ama başka okuyucularda görünmez.'**
  String savedWithSkipped(String name, int count);

  /// No description provided for @saveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi: {error}'**
  String saveFailed(String error);

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmemiş değişiklikler'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In tr, this message translates to:
  /// **'Çizimleriniz kaydedilmedi. Kapatmadan önce kaydedilsin mi?'**
  String get unsavedChangesBody;

  /// No description provided for @discardChanges.
  ///
  /// In tr, this message translates to:
  /// **'Kaydetme'**
  String get discardChanges;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @protectedFileWarning.
  ///
  /// In tr, this message translates to:
  /// **'Bu dosya şifreli ya da imzalı. Çizimler ayrı bir kopyaya kaydedilecek.'**
  String get protectedFileWarning;

  /// No description provided for @openNewerFormat.
  ///
  /// In tr, this message translates to:
  /// **'Bu dosya Inken\'in daha yeni bir sürümüyle kaydedilmiş. Açmak için uygulamayı güncelleyin.'**
  String get openNewerFormat;

  /// No description provided for @openCorruptData.
  ///
  /// In tr, this message translates to:
  /// **'Dosyadaki Inken çizim verisi bozuk; çizimleri kaybetmemek için dosya açılmadı.'**
  String get openCorruptData;

  /// No description provided for @openPageMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Dosyanın sayfaları başka bir programla değiştirilmiş; Inken çizimleri eşleştirilemediği için dosya açılmadı.'**
  String get openPageMismatch;

  /// No description provided for @recoveryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmemiş çizimler bulundu'**
  String get recoveryTitle;

  /// No description provided for @recoveryBody.
  ///
  /// In tr, this message translates to:
  /// **'{name} dosyasındaki çizimler {time} tarihinde yedeklendi ama kaydedilmedi. Geri yüklensin mi?'**
  String recoveryBody(String name, String time);

  /// No description provided for @recoveryFileChanged.
  ///
  /// In tr, this message translates to:
  /// **'Dosya bu yedekten sonra değiştirilmiş. Geri yüklerseniz yedekteki çizimler dosyadakilerin yerine geçer (geri al ile dönülebilir).'**
  String get recoveryFileChanged;

  /// No description provided for @recoveryFileMissing.
  ///
  /// In tr, this message translates to:
  /// **'{path} bulunamadı; dosya taşınmış ya da silinmiş olabilir. Yedek geri yüklenemiyor.'**
  String recoveryFileMissing(String path);

  /// No description provided for @recoveryRestore.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükle'**
  String get recoveryRestore;

  /// No description provided for @recoveryDelete.
  ///
  /// In tr, this message translates to:
  /// **'Yedeği sil'**
  String get recoveryDelete;

  /// No description provided for @recoveryLater.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get recoveryLater;

  /// No description provided for @exportFlattened.
  ///
  /// In tr, this message translates to:
  /// **'Çizimleri gömerek dışa aktar…'**
  String get exportFlattened;

  /// No description provided for @exportFileName.
  ///
  /// In tr, this message translates to:
  /// **'{base} (çizimli).pdf'**
  String exportFileName(String base);

  /// No description provided for @exportedTo.
  ///
  /// In tr, this message translates to:
  /// **'Dışa aktarıldı: {name}'**
  String exportedTo(String name);

  /// No description provided for @exportedWithSkipped.
  ///
  /// In tr, this message translates to:
  /// **'Dışa aktarıldı: {name}. {count} öğe yazılamadı; kopyada eksik.'**
  String exportedWithSkipped(String name, int count);

  /// No description provided for @exportFailed.
  ///
  /// In tr, this message translates to:
  /// **'Dışa aktarılamadı: {error}'**
  String exportFailed(String error);

  /// No description provided for @exportOntoOpenFile.
  ///
  /// In tr, this message translates to:
  /// **'Açık dosyanın üzerine dışa aktarılamaz; başka bir ad seçin.'**
  String get exportOntoOpenFile;

  /// No description provided for @overwriteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dosya zaten var'**
  String get overwriteTitle;

  /// No description provided for @overwriteBody.
  ///
  /// In tr, this message translates to:
  /// **'{name} zaten var. Üzerine yazılsın mı?'**
  String overwriteBody(String name);

  /// No description provided for @overwrite.
  ///
  /// In tr, this message translates to:
  /// **'Üzerine yaz'**
  String get overwrite;

  /// No description provided for @saveAs.
  ///
  /// In tr, this message translates to:
  /// **'Farklı kaydet…'**
  String get saveAs;

  /// No description provided for @saveAsOntoOriginal.
  ///
  /// In tr, this message translates to:
  /// **'Orijinal PDF\'in üzerine kaydedilmez; başka bir ad seçin.'**
  String get saveAsOntoOriginal;

  /// No description provided for @pickerUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda kayıt yeri seçmek henüz desteklenmiyor.'**
  String get pickerUnavailable;

  /// No description provided for @menuFile.
  ///
  /// In tr, this message translates to:
  /// **'Dosya'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzen'**
  String get menuEdit;

  /// No description provided for @menuTools.
  ///
  /// In tr, this message translates to:
  /// **'Araçlar'**
  String get menuTools;

  /// No description provided for @openPdfMenu.
  ///
  /// In tr, this message translates to:
  /// **'Aç…'**
  String get openPdfMenu;

  /// Dosya menüsü: tek boş sayfalık yeni PDF oluşturur.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get newDocument;

  /// Yeni belgenin adı (ilk kayıtta önerilen dosya adı).
  ///
  /// In tr, this message translates to:
  /// **'Adsız.pdf'**
  String get untitledDocument;

  /// No description provided for @menuView.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get menuView;

  /// No description provided for @menuPage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa'**
  String get menuPage;

  /// No description provided for @menu.
  ///
  /// In tr, this message translates to:
  /// **'Menü'**
  String get menu;

  /// No description provided for @more.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get more;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @zoom.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlaştırma'**
  String get zoom;

  /// No description provided for @zoomIn.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlaştır'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In tr, this message translates to:
  /// **'Uzaklaştır'**
  String get zoomOut;

  /// No description provided for @fitPage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaya sığdır'**
  String get fitPage;

  /// No description provided for @fitWidth.
  ///
  /// In tr, this message translates to:
  /// **'Genişliğe sığdır'**
  String get fitWidth;

  /// No description provided for @actualSize.
  ///
  /// In tr, this message translates to:
  /// **'Gerçek boyut (%100)'**
  String get actualSize;

  /// No description provided for @zoomOptions.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlaştırma seçenekleri'**
  String get zoomOptions;

  /// No description provided for @previousPage.
  ///
  /// In tr, this message translates to:
  /// **'Önceki sayfa'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki sayfa'**
  String get nextPage;

  /// No description provided for @statusSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedildi'**
  String get statusSaved;

  /// No description provided for @statusSaving.
  ///
  /// In tr, this message translates to:
  /// **'Kaydediliyor…'**
  String get statusSaving;

  /// No description provided for @statusUnsaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmedi'**
  String get statusUnsaved;

  /// No description provided for @sectionColor.
  ///
  /// In tr, this message translates to:
  /// **'Renk'**
  String get sectionColor;

  /// No description provided for @sectionThickness.
  ///
  /// In tr, this message translates to:
  /// **'Kalınlık'**
  String get sectionThickness;

  /// No description provided for @thicknessVeryThick.
  ///
  /// In tr, this message translates to:
  /// **'Çok kalın'**
  String get thicknessVeryThick;

  /// No description provided for @toolOptions.
  ///
  /// In tr, this message translates to:
  /// **'{tool} seçenekleri'**
  String toolOptions(String tool);

  /// No description provided for @colorBlack.
  ///
  /// In tr, this message translates to:
  /// **'Siyah'**
  String get colorBlack;

  /// No description provided for @colorBlue.
  ///
  /// In tr, this message translates to:
  /// **'Mavi'**
  String get colorBlue;

  /// No description provided for @colorRed.
  ///
  /// In tr, this message translates to:
  /// **'Kırmızı'**
  String get colorRed;

  /// No description provided for @colorGreen.
  ///
  /// In tr, this message translates to:
  /// **'Yeşil'**
  String get colorGreen;

  /// No description provided for @colorOrange.
  ///
  /// In tr, this message translates to:
  /// **'Turuncu'**
  String get colorOrange;

  /// No description provided for @colorPurple.
  ///
  /// In tr, this message translates to:
  /// **'Mor'**
  String get colorPurple;

  /// No description provided for @colorYellow.
  ///
  /// In tr, this message translates to:
  /// **'Sarı'**
  String get colorYellow;

  /// No description provided for @colorPink.
  ///
  /// In tr, this message translates to:
  /// **'Pembe'**
  String get colorPink;

  /// No description provided for @toolLaser.
  ///
  /// In tr, this message translates to:
  /// **'Geçici kalem'**
  String get toolLaser;

  /// No description provided for @sectionEraserMode.
  ///
  /// In tr, this message translates to:
  /// **'Silgi türü'**
  String get sectionEraserMode;

  /// No description provided for @eraserStroke.
  ///
  /// In tr, this message translates to:
  /// **'Çizgi'**
  String get eraserStroke;

  /// No description provided for @eraserPixel.
  ///
  /// In tr, this message translates to:
  /// **'Piksel'**
  String get eraserPixel;

  /// No description provided for @sectionSize.
  ///
  /// In tr, this message translates to:
  /// **'Boyut'**
  String get sectionSize;

  /// No description provided for @sizeSmall.
  ///
  /// In tr, this message translates to:
  /// **'Küçük'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In tr, this message translates to:
  /// **'Büyük'**
  String get sizeLarge;

  /// No description provided for @theme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @goToPage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaya git…'**
  String get goToPage;

  /// No description provided for @find.
  ///
  /// In tr, this message translates to:
  /// **'Bul…'**
  String get find;

  /// No description provided for @searchHint.
  ///
  /// In tr, this message translates to:
  /// **'Belgede ara'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç yok'**
  String get searchNoResults;

  /// No description provided for @searchCount.
  ///
  /// In tr, this message translates to:
  /// **'{current} / {total}'**
  String searchCount(int current, int total);

  /// No description provided for @searchNext.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki'**
  String get searchNext;

  /// No description provided for @searchPrevious.
  ///
  /// In tr, this message translates to:
  /// **'Önceki'**
  String get searchPrevious;

  /// No description provided for @searchClose.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı kapat'**
  String get searchClose;

  /// No description provided for @searchSearching.
  ///
  /// In tr, this message translates to:
  /// **'Aranıyor…'**
  String get searchSearching;

  /// No description provided for @goToPageLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa numarası (1–{count})'**
  String goToPageLabel(int count);

  /// No description provided for @go.
  ///
  /// In tr, this message translates to:
  /// **'Git'**
  String get go;

  /// No description provided for @windowTitle.
  ///
  /// In tr, this message translates to:
  /// **'{name} – Inken PDF'**
  String windowTitle(String name);

  /// No description provided for @goToPageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaya git'**
  String get goToPageTitle;

  /// No description provided for @colorBrick.
  ///
  /// In tr, this message translates to:
  /// **'Kiremit'**
  String get colorBrick;

  /// No description provided for @menuBars.
  ///
  /// In tr, this message translates to:
  /// **'Çubuklar ve paneller'**
  String get menuBars;

  /// No description provided for @toolDock.
  ///
  /// In tr, this message translates to:
  /// **'Araç kutusu'**
  String get toolDock;

  /// No description provided for @dockTop.
  ///
  /// In tr, this message translates to:
  /// **'Üstte'**
  String get dockTop;

  /// No description provided for @dockLeft.
  ///
  /// In tr, this message translates to:
  /// **'Solda'**
  String get dockLeft;

  /// No description provided for @fullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Tam ekran'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Tam ekrandan çık (Esc)'**
  String get exitFullscreen;

  /// No description provided for @toolSelect.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get toolSelect;

  /// No description provided for @deleteSelection.
  ///
  /// In tr, this message translates to:
  /// **'Seçileni sil'**
  String get deleteSelection;

  /// No description provided for @fadeFloating.
  ///
  /// In tr, this message translates to:
  /// **'Kullanılmayan kutuları soldur'**
  String get fadeFloating;

  /// No description provided for @pageScrollbar.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa kaydırma çubuğu'**
  String get pageScrollbar;

  /// No description provided for @toolShape.
  ///
  /// In tr, this message translates to:
  /// **'Şekil'**
  String get toolShape;

  /// No description provided for @sectionShape.
  ///
  /// In tr, this message translates to:
  /// **'Şekil'**
  String get sectionShape;

  /// No description provided for @shapeLine.
  ///
  /// In tr, this message translates to:
  /// **'Çizgi'**
  String get shapeLine;

  /// No description provided for @shapeArrow.
  ///
  /// In tr, this message translates to:
  /// **'Ok'**
  String get shapeArrow;

  /// No description provided for @shapeRectangle.
  ///
  /// In tr, this message translates to:
  /// **'Dikdörtgen'**
  String get shapeRectangle;

  /// No description provided for @shapeEllipse.
  ///
  /// In tr, this message translates to:
  /// **'Elips'**
  String get shapeEllipse;

  /// No description provided for @shapeCoordinate.
  ///
  /// In tr, this message translates to:
  /// **'Koordinat düzlemi'**
  String get shapeCoordinate;

  /// No description provided for @sectionInstruments.
  ///
  /// In tr, this message translates to:
  /// **'Ölçme araçları'**
  String get sectionInstruments;

  /// No description provided for @instrumentRuler.
  ///
  /// In tr, this message translates to:
  /// **'Cetvel'**
  String get instrumentRuler;

  /// No description provided for @instrumentSetSquare.
  ///
  /// In tr, this message translates to:
  /// **'Gönye'**
  String get instrumentSetSquare;

  /// No description provided for @instrumentProtractor.
  ///
  /// In tr, this message translates to:
  /// **'İletki'**
  String get instrumentProtractor;

  /// No description provided for @instrumentCompass.
  ///
  /// In tr, this message translates to:
  /// **'Pergel'**
  String get instrumentCompass;

  /// No description provided for @instrumentClose.
  ///
  /// In tr, this message translates to:
  /// **'{name} kapat'**
  String instrumentClose(String name);

  /// No description provided for @instrumentCentimeters.
  ///
  /// In tr, this message translates to:
  /// **'{value} cm'**
  String instrumentCentimeters(String value);

  /// No description provided for @recentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Son açılanlar'**
  String get recentTitle;

  /// No description provided for @recentRemove.
  ///
  /// In tr, this message translates to:
  /// **'Listeden kaldır'**
  String get recentRemove;

  /// No description provided for @recentMissing.
  ///
  /// In tr, this message translates to:
  /// **'Dosya bulunamadı'**
  String get recentMissing;

  /// No description provided for @recentUnsaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmemiş değişiklik'**
  String get recentUnsaved;

  /// No description provided for @recentOpenFailed.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" açılamadı. Dosya taşınmış ya da silinmiş olabilir.'**
  String recentOpenFailed(String name);

  /// No description provided for @recentToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün {time}'**
  String recentToday(String time);

  /// No description provided for @recentYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün {time}'**
  String recentYesterday(String time);

  /// No description provided for @recentPages.
  ///
  /// In tr, this message translates to:
  /// **'{count} sayfa'**
  String recentPages(int count);

  /// No description provided for @introTitle.
  ///
  /// In tr, this message translates to:
  /// **'Neler yapabilirsin'**
  String get introTitle;

  /// No description provided for @introSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Araç kutusu bir PDF açınca etkinleşir.'**
  String get introSubtitle;

  /// No description provided for @introHide.
  ///
  /// In tr, this message translates to:
  /// **'Gizle'**
  String get introHide;

  /// No description provided for @introShowSetting.
  ///
  /// In tr, this message translates to:
  /// **'Açılışta tanıtımı göster'**
  String get introShowSetting;

  /// No description provided for @introToolsHeading.
  ///
  /// In tr, this message translates to:
  /// **'Araçlar'**
  String get introToolsHeading;

  /// No description provided for @introLessonHeading.
  ///
  /// In tr, this message translates to:
  /// **'Ders sırasında'**
  String get introLessonHeading;

  /// No description provided for @keySpace.
  ///
  /// In tr, this message translates to:
  /// **'Boşluk'**
  String get keySpace;

  /// No description provided for @introPen.
  ///
  /// In tr, this message translates to:
  /// **'Kalemle yaz; basınç algılayan kalemde çizgi bastıkça kalınlaşır. Renk ve kalınlık için araca ikinci kez dokun.'**
  String get introPen;

  /// No description provided for @introHighlighter.
  ///
  /// In tr, this message translates to:
  /// **'Metnin üzerinden geç; alttaki yazı okunur kalır.'**
  String get introHighlighter;

  /// No description provided for @introShape.
  ///
  /// In tr, this message translates to:
  /// **'Çizgi, ok, dikdörtgen, elips, koordinat düzlemi. Shift ile kare ve daire. Panelde cetvel, gönye, iletki ve pergel: kalem kenarlarına yaslanır.'**
  String get introShape;

  /// No description provided for @introEraser.
  ///
  /// In tr, this message translates to:
  /// **'Dokunduğun çizgiyi ya da yalnızca üzerinden geçtiğin kısmı siler. Kalemin silgi ucu da çalışır.'**
  String get introEraser;

  /// No description provided for @introLaser.
  ///
  /// In tr, this message translates to:
  /// **'Göstererek anlat: yazdığın birkaç saniyede kaybolur, belgeye girmez.'**
  String get introLaser;

  /// No description provided for @introSelect.
  ///
  /// In tr, this message translates to:
  /// **'Dokunarak ya da dikdörtgen çizerek seç; sürükleyerek taşı, köşeden büyüt, Delete ile sil.'**
  String get introSelect;

  /// No description provided for @introHand.
  ///
  /// In tr, this message translates to:
  /// **'Sayfayı sürükleyerek kaydır. Başka araçtayken boşluğu basılı tut: geçici olarak kaydırır.'**
  String get introHand;

  /// No description provided for @introUndo.
  ///
  /// In tr, this message translates to:
  /// **'Her adım geri alınır; kaydettikten sonra da.'**
  String get introUndo;

  /// No description provided for @introSave.
  ///
  /// In tr, this message translates to:
  /// **'Çizimler PDF\'in içine kaydedilir ve her PDF okuyucuda görünür. Orijinal dosyanın üzerine yazılmaz.'**
  String get introSave;

  /// No description provided for @introExport.
  ///
  /// In tr, this message translates to:
  /// **'Çizimleri sayfaya gömülü bir kopya oluşturur; öğrencilerle paylaşmak ve yazdırmak için.'**
  String get introExport;

  /// No description provided for @introBackupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik yedek'**
  String get introBackupTitle;

  /// No description provided for @introBackup.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmemiş çizimler dakikada bir yedeklenir; uygulama kapanırsa açılışta geri yüklenir.'**
  String get introBackup;

  /// No description provided for @introFullscreen.
  ///
  /// In tr, this message translates to:
  /// **'Menüler gizlenir, yalnızca sayfa ve araç kutusu kalır. Esc ile çıkılır.'**
  String get introFullscreen;

  /// No description provided for @introPagesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sayfalar arasında'**
  String get introPagesTitle;

  /// No description provided for @introPages.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa sayfa ilerle, sağdaki çubukla hızlıca git ya da sayfa numarasına dokunup yaz.'**
  String get introPages;

  /// No description provided for @toolText.
  ///
  /// In tr, this message translates to:
  /// **'Metin'**
  String get toolText;

  /// No description provided for @introText.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaya dokun ve yaz; Enter yeni satır. Var olan metne dokununca düzenlenir. Türkçe harfler ve matematik işaretleri (√ π ≤ ∞) eksiksiz.'**
  String get introText;

  /// No description provided for @customColor.
  ///
  /// In tr, this message translates to:
  /// **'Özel renk'**
  String get customColor;

  /// No description provided for @customColorNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni renk'**
  String get customColorNew;

  /// No description provided for @colorHue.
  ///
  /// In tr, this message translates to:
  /// **'Ton'**
  String get colorHue;

  /// No description provided for @colorSaturationValue.
  ///
  /// In tr, this message translates to:
  /// **'Doygunluk ve parlaklık'**
  String get colorSaturationValue;

  /// No description provided for @colorHex.
  ///
  /// In tr, this message translates to:
  /// **'Renk kodu'**
  String get colorHex;

  /// No description provided for @colorHexInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz kod'**
  String get colorHexInvalid;

  /// No description provided for @colorChoose.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get colorChoose;

  /// No description provided for @quickBar.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı erişim çubuğu'**
  String get quickBar;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @settingsMenu.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar…'**
  String get settingsMenu;

  /// No description provided for @printDocument.
  ///
  /// In tr, this message translates to:
  /// **'Yazdır…'**
  String get printDocument;

  /// No description provided for @appendPage.
  ///
  /// In tr, this message translates to:
  /// **'Sona sayfa ekle: {template}'**
  String appendPage(String template);

  /// No description provided for @insertPage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa ekle'**
  String get insertPage;

  /// No description provided for @deletePage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfayı sil'**
  String get deletePage;

  /// No description provided for @rotatePage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfayı döndür'**
  String get rotatePage;

  /// No description provided for @rotateRight.
  ///
  /// In tr, this message translates to:
  /// **'Sağa döndür'**
  String get rotateRight;

  /// No description provided for @rotateLeft.
  ///
  /// In tr, this message translates to:
  /// **'Sola döndür'**
  String get rotateLeft;

  /// No description provided for @pageOrientation.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa yönü'**
  String get pageOrientation;

  /// No description provided for @orientationPortrait.
  ///
  /// In tr, this message translates to:
  /// **'Dikey'**
  String get orientationPortrait;

  /// No description provided for @orientationLandscape.
  ///
  /// In tr, this message translates to:
  /// **'Yatay'**
  String get orientationLandscape;

  /// No description provided for @insertPageBefore.
  ///
  /// In tr, this message translates to:
  /// **'Önüne sayfa ekle'**
  String get insertPageBefore;

  /// No description provided for @insertPageAfter.
  ///
  /// In tr, this message translates to:
  /// **'Arkasına sayfa ekle'**
  String get insertPageAfter;

  /// No description provided for @insertPageHere.
  ///
  /// In tr, this message translates to:
  /// **'Buraya sayfa ekle'**
  String get insertPageHere;

  /// No description provided for @pageActions.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa işlemleri'**
  String get pageActions;

  /// No description provided for @pagesSelected.
  ///
  /// In tr, this message translates to:
  /// **'{count} sayfa seçili'**
  String pagesSelected(int count);

  /// No description provided for @clearPageSelection.
  ///
  /// In tr, this message translates to:
  /// **'Seçimi kaldır'**
  String get clearPageSelection;

  /// No description provided for @deletePages.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, =1{Sayfayı sil} other{{count} sayfayı sil}}'**
  String deletePages(int count);

  /// No description provided for @pagesDeleted.
  ///
  /// In tr, this message translates to:
  /// **'{count} sayfa silindi'**
  String pagesDeleted(int count);

  /// No description provided for @exportShort.
  ///
  /// In tr, this message translates to:
  /// **'Dışa aktar'**
  String get exportShort;

  /// No description provided for @settingsInput.
  ///
  /// In tr, this message translates to:
  /// **'Kalem ve dokunma'**
  String get settingsInput;

  /// No description provided for @settingsShortcuts.
  ///
  /// In tr, this message translates to:
  /// **'Kısayollar'**
  String get settingsShortcuts;

  /// No description provided for @settingsAbout.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get settingsAbout;

  /// No description provided for @shortcutSpaceHold.
  ///
  /// In tr, this message translates to:
  /// **'Basılı tut: geçici olarak kaydır'**
  String get shortcutSpaceHold;

  /// No description provided for @shortcutShiftShape.
  ///
  /// In tr, this message translates to:
  /// **'Şekil çizerken basılı tut: kare, daire, 15° adımlar'**
  String get shortcutShiftShape;

  /// No description provided for @shortcutTextEnter.
  ///
  /// In tr, this message translates to:
  /// **'Metin yazarken: yeni satır'**
  String get shortcutTextEnter;

  /// No description provided for @shortcutPagesView.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa ve görünüm'**
  String get shortcutPagesView;

  /// No description provided for @shortcutFirstPage.
  ///
  /// In tr, this message translates to:
  /// **'İlk sayfa'**
  String get shortcutFirstPage;

  /// No description provided for @shortcutLastPage.
  ///
  /// In tr, this message translates to:
  /// **'Son sayfa'**
  String get shortcutLastPage;

  /// No description provided for @keyWheel.
  ///
  /// In tr, this message translates to:
  /// **'Tekerlek'**
  String get keyWheel;

  /// No description provided for @shortcutZoomWheel.
  ///
  /// In tr, this message translates to:
  /// **'Yakınlaştır / uzaklaştır'**
  String get shortcutZoomWheel;

  /// No description provided for @shortcutEscape.
  ///
  /// In tr, this message translates to:
  /// **'Paneli kapat, seçimi bırak, spot ışığını / perdeyi kapat, tam ekrandan çık'**
  String get shortcutEscape;

  /// No description provided for @shortcutsNote.
  ///
  /// In tr, this message translates to:
  /// **'Çoğu kısayol belge açıkken çalışır (Ctrl+O ve Ctrl+, her yerde). Metin yazarken tek harfli kısayollar devre dışıdır.'**
  String get shortcutsNote;

  /// No description provided for @aboutDescription.
  ///
  /// In tr, this message translates to:
  /// **'Hafif ve hızlı bir PDF okuyucu; üzerine yazıp çizebilirsin. Çizimler PDF\'in içine, her okuyucuda görünecek biçimde kaydedilir. Ücretsiz, hesap gerekmez.'**
  String get aboutDescription;

  /// No description provided for @aboutFonts.
  ///
  /// In tr, this message translates to:
  /// **'Yazı tipleri: Figtree, Fraunces, JetBrains Mono (SIL Open Font License) ve DejaVu Sans (Bitstream Vera lisansı).'**
  String get aboutFonts;

  /// Hakkında: uygulamanın kendi lisansı.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF özgür yazılımdır: GNU Genel Kamu Lisansı sürüm 3 ya da sonraki sürümleri (GPL-3.0-or-later) koşullarıyla kullanabilir, değiştirebilir ve dağıtabilirsin. Hiçbir garanti verilmez. Deneme sürümüdür; önemli dosyalarının bir kopyasını ayrıca sakla.'**
  String get aboutAppLicense;

  /// No description provided for @aboutLicenses.
  ///
  /// In tr, this message translates to:
  /// **'Lisanslar'**
  String get aboutLicenses;

  /// No description provided for @templateBlank.
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get templateBlank;

  /// No description provided for @templateGrid.
  ///
  /// In tr, this message translates to:
  /// **'Kareli'**
  String get templateGrid;

  /// No description provided for @templateDotted.
  ///
  /// In tr, this message translates to:
  /// **'Noktalı'**
  String get templateDotted;

  /// No description provided for @templateLined.
  ///
  /// In tr, this message translates to:
  /// **'Çizgili'**
  String get templateLined;

  /// No description provided for @templateCoordinate.
  ///
  /// In tr, this message translates to:
  /// **'Koordinat düzlemi'**
  String get templateCoordinate;

  /// No description provided for @pageDeleted.
  ///
  /// In tr, this message translates to:
  /// **'{page}. sayfa silindi'**
  String pageDeleted(int page);

  /// No description provided for @pageLayoutFailed.
  ///
  /// In tr, this message translates to:
  /// **'Sayfalar hazırlanamadı: {error}'**
  String pageLayoutFailed(String error);

  /// No description provided for @printSent.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcıya gönderildi'**
  String get printSent;

  /// No description provided for @printFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yazdırılamadı: {error}'**
  String printFailed(String error);

  /// No description provided for @printUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu yazıcı PDF kabul etmiyor. Başka bir yazıcı seç ya da dışa aktarıp bir PDF okuyucudan yazdır.'**
  String get printUnsupported;

  /// Belgeyi (çizimleriyle, düzenlenebilir PDF) sistemin paylaşma yoluna verir.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş…'**
  String get shareDocument;

  /// No description provided for @shareMailed.
  ///
  /// In tr, this message translates to:
  /// **'Dosya yeni e-postaya eklendi'**
  String get shareMailed;

  /// No description provided for @shareShown.
  ///
  /// In tr, this message translates to:
  /// **'E-posta uygulaması bulunamadı; dosya klasöründe gösteriliyor'**
  String get shareShown;

  /// No description provided for @shareFailed.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşılamadı: {error}'**
  String shareFailed(String error);

  /// No description provided for @shareUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu sistemde dosya paylaşılamıyor. Kaydedip dosyayı kendin gönderebilirsin.'**
  String get shareUnsupported;

  /// No description provided for @phoneToolsShow.
  ///
  /// In tr, this message translates to:
  /// **'Çizim araçlarını göster'**
  String get phoneToolsShow;

  /// No description provided for @phoneToolsHide.
  ///
  /// In tr, this message translates to:
  /// **'Çizim araçlarını gizle'**
  String get phoneToolsHide;

  /// No description provided for @dropPdfHere.
  ///
  /// In tr, this message translates to:
  /// **'PDF\'i açmak için bırak'**
  String get dropPdfHere;

  /// No description provided for @dropOnlyPdf.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca PDF dosyaları açılabilir'**
  String get dropOnlyPdf;

  /// No description provided for @dockBottom.
  ///
  /// In tr, this message translates to:
  /// **'Altta'**
  String get dockBottom;

  /// No description provided for @dockRight.
  ///
  /// In tr, this message translates to:
  /// **'Sağda'**
  String get dockRight;

  /// No description provided for @dockMove.
  ///
  /// In tr, this message translates to:
  /// **'Araç kutusunu taşı (sürükle ya da dokun)'**
  String get dockMove;

  /// No description provided for @spotlight.
  ///
  /// In tr, this message translates to:
  /// **'Spot ışığı'**
  String get spotlight;

  /// No description provided for @curtain.
  ///
  /// In tr, this message translates to:
  /// **'Perde'**
  String get curtain;

  /// No description provided for @spotlightResize.
  ///
  /// In tr, this message translates to:
  /// **'Büyüt / küçült (sürükle; tekerlek ya da iki parmak da olur)'**
  String get spotlightResize;

  /// No description provided for @spotlightClose.
  ///
  /// In tr, this message translates to:
  /// **'Spot ışığını kapat (Esc)'**
  String get spotlightClose;

  /// No description provided for @curtainClose.
  ///
  /// In tr, this message translates to:
  /// **'Perdeyi kapat (Esc)'**
  String get curtainClose;

  /// No description provided for @curtainHint.
  ///
  /// In tr, this message translates to:
  /// **'Aşağı çekerek aç'**
  String get curtainHint;

  /// No description provided for @introSpotlight.
  ///
  /// In tr, this message translates to:
  /// **'Sayfanın bir yerini aydınlat, gerisini karart. Karartıyı sürükleyerek ışığı gezdir; ışığın içinde yazmaya devam et.'**
  String get introSpotlight;

  /// No description provided for @introCurtain.
  ///
  /// In tr, this message translates to:
  /// **'Sayfayı örtüp aşağı çektikçe satır satır göster; yanıtı sona sakla.'**
  String get introCurtain;

  /// No description provided for @paste.
  ///
  /// In tr, this message translates to:
  /// **'Yapıştır'**
  String get paste;

  /// No description provided for @insertImage.
  ///
  /// In tr, this message translates to:
  /// **'Görsel ekle…'**
  String get insertImage;

  /// No description provided for @imageFileType.
  ///
  /// In tr, this message translates to:
  /// **'Görseller'**
  String get imageFileType;

  /// No description provided for @clipboardNoImage.
  ///
  /// In tr, this message translates to:
  /// **'Panoda görsel yok. Bir görseli ya da ekran görüntüsünü kopyalayıp yeniden dene.'**
  String get clipboardNoImage;

  /// No description provided for @imageUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel açılamadı'**
  String get imageUnreadable;

  /// No description provided for @dropOnlyPdfOrImage.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca PDF ve görsel dosyaları bırakılabilir'**
  String get dropOnlyPdfOrImage;

  /// No description provided for @dropPdfOrImageHere.
  ///
  /// In tr, this message translates to:
  /// **'PDF\'i ya da görseli bırak'**
  String get dropPdfOrImageHere;

  /// No description provided for @introImageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görsel'**
  String get introImageTitle;

  /// No description provided for @introImage.
  ///
  /// In tr, this message translates to:
  /// **'Kopyaladığın görseli ya da ekran görüntüsünü Ctrl+V ile yapıştır; seçili gelir, köşesinden büyütüp küçült. Dosyadan da eklenir, pencereye sürüklenir.'**
  String get introImage;

  /// No description provided for @stageCover.
  ///
  /// In tr, this message translates to:
  /// **'Spot ışığı / perde'**
  String get stageCover;

  /// No description provided for @menuHelp.
  ///
  /// In tr, this message translates to:
  /// **'Yardım'**
  String get menuHelp;

  /// No description provided for @aboutApp.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında Inken PDF'**
  String get aboutApp;

  /// No description provided for @settingsInfo.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama bilgileri'**
  String get settingsInfo;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In tr, this message translates to:
  /// **'Klavye kısayolları'**
  String get keyboardShortcuts;

  /// Yardım menüsünde tanıtım PDF'ini açan öğe; ilk kurulumda da kendiliğinden açılır.
  ///
  /// In tr, this message translates to:
  /// **'Başlarken'**
  String get guideMenu;

  /// Tanıtım PDF'inin gösterilen ve kaydederken önerilen adı.
  ///
  /// In tr, this message translates to:
  /// **'Başlarken.pdf'**
  String get guideFileName;

  /// No description provided for @versionWithBuild.
  ///
  /// In tr, this message translates to:
  /// **'{version} (derleme {build})'**
  String versionWithBuild(String version, String build);

  /// No description provided for @aboutVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutRepository.
  ///
  /// In tr, this message translates to:
  /// **'GitHub\'da Inken PDF'**
  String get aboutRepository;

  /// No description provided for @aboutRepositoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak, sürümler ve geri bildirim'**
  String get aboutRepositoryHint;

  /// No description provided for @shareApp.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF\'i paylaş'**
  String get shareApp;

  /// No description provided for @shareAppText.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF: hafif, hızlı ve ücretsiz PDF okuyucu; üzerine yazıp çizebilirsin. Hesap gerekmez, açık kaynak: {url}'**
  String shareAppText(String url);

  /// No description provided for @shareAppCopied.
  ///
  /// In tr, this message translates to:
  /// **'Tanıtım metni ve bağlantı panoya kopyalandı'**
  String get shareAppCopied;

  /// No description provided for @linkOpenFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı açılamadı: {url}'**
  String linkOpenFailed(String url);

  /// No description provided for @linkOpenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı açılsın mı?'**
  String get linkOpenTitle;

  /// No description provided for @linkOpenBody.
  ///
  /// In tr, this message translates to:
  /// **'{url} adresi tarayıcıda açılacak.'**
  String linkOpenBody(String url);

  /// No description provided for @linkOpen.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get linkOpen;

  /// No description provided for @infoIntro.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorun bildirirken bu bilgileri ekle; neyin nerede olduğunu bulmayı kolaylaştırır.'**
  String get infoIntro;

  /// No description provided for @infoCopy.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get infoCopy;

  /// No description provided for @infoCopied.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama bilgileri panoya kopyalandı'**
  String get infoCopied;

  /// No description provided for @infoVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm'**
  String get infoVersion;

  /// No description provided for @infoPlatform.
  ///
  /// In tr, this message translates to:
  /// **'İşletim sistemi'**
  String get infoPlatform;

  /// No description provided for @infoDart.
  ///
  /// In tr, this message translates to:
  /// **'Dart'**
  String get infoDart;

  /// No description provided for @infoPdfEngine.
  ///
  /// In tr, this message translates to:
  /// **'PDF motoru'**
  String get infoPdfEngine;

  /// No description provided for @infoFormat.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt formatı (inken.json)'**
  String get infoFormat;

  /// No description provided for @infoLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get infoLanguage;

  /// No description provided for @infoScreen.
  ///
  /// In tr, this message translates to:
  /// **'Ekran'**
  String get infoScreen;

  /// No description provided for @infoStylusSeen.
  ///
  /// In tr, this message translates to:
  /// **'Kalem algılandı'**
  String get infoStylusSeen;

  /// No description provided for @infoDataFolder.
  ///
  /// In tr, this message translates to:
  /// **'Veri klasörü (ayarlar, yedekler)'**
  String get infoDataFolder;

  /// No description provided for @yes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get no;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get languageSystem;

  /// No description provided for @languageTurkish.
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In tr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsAppearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get settingsAppearance;

  /// No description provided for @toolHighlighterShort.
  ///
  /// In tr, this message translates to:
  /// **'Fosforlu'**
  String get toolHighlighterShort;

  /// No description provided for @toolLaserShort.
  ///
  /// In tr, this message translates to:
  /// **'Geçici'**
  String get toolLaserShort;

  /// No description provided for @copy.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In tr, this message translates to:
  /// **'Kes'**
  String get cut;

  /// No description provided for @selectAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü seç'**
  String get selectAll;

  /// No description provided for @recolorSelection.
  ///
  /// In tr, this message translates to:
  /// **'Seçilenin rengi: {color}'**
  String recolorSelection(String color);

  /// No description provided for @clipboardMarker.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF öğeleri'**
  String get clipboardMarker;

  /// No description provided for @selectionBar.
  ///
  /// In tr, this message translates to:
  /// **'Seçim'**
  String get selectionBar;

  /// No description provided for @pagePanel.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa küçük resimleri'**
  String get pagePanel;

  /// No description provided for @pagePanelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sayfalar'**
  String get pagePanelTitle;

  /// No description provided for @pagePanelPages.
  ///
  /// In tr, this message translates to:
  /// **'Sayfalar'**
  String get pagePanelPages;

  /// No description provided for @outline.
  ///
  /// In tr, this message translates to:
  /// **'İçindekiler'**
  String get outline;

  /// No description provided for @outlineEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu belgede içindekiler yok.'**
  String get outlineEmpty;

  /// No description provided for @outlineExpand.
  ///
  /// In tr, this message translates to:
  /// **'Alt başlıkları göster'**
  String get outlineExpand;

  /// No description provided for @outlineCollapse.
  ///
  /// In tr, this message translates to:
  /// **'Alt başlıkları gizle'**
  String get outlineCollapse;

  /// No description provided for @pageThumbnail.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa {page}'**
  String pageThumbnail(int page);

  /// No description provided for @uiScale.
  ///
  /// In tr, this message translates to:
  /// **'Arayüz boyutu'**
  String get uiScale;

  /// No description provided for @uiScaleNormal.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get uiScaleNormal;

  /// No description provided for @uiScaleLarge.
  ///
  /// In tr, this message translates to:
  /// **'Büyük'**
  String get uiScaleLarge;

  /// No description provided for @uiScaleLarger.
  ///
  /// In tr, this message translates to:
  /// **'Akıllı tahta'**
  String get uiScaleLarger;

  /// No description provided for @pagePanelClose.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa panelini kapat'**
  String get pagePanelClose;

  /// No description provided for @pagePanelOpen.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa panelini aç'**
  String get pagePanelOpen;

  /// No description provided for @documentProperties.
  ///
  /// In tr, this message translates to:
  /// **'Belge özellikleri…'**
  String get documentProperties;

  /// No description provided for @propertiesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Belge özellikleri'**
  String get propertiesTitle;

  /// No description provided for @propFile.
  ///
  /// In tr, this message translates to:
  /// **'Dosya'**
  String get propFile;

  /// No description provided for @propLocation.
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get propLocation;

  /// No description provided for @propNotSaved.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kaydedilmedi'**
  String get propNotSaved;

  /// No description provided for @propFileSize.
  ///
  /// In tr, this message translates to:
  /// **'Dosya boyutu'**
  String get propFileSize;

  /// No description provided for @propTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get propTitle;

  /// No description provided for @propAuthor.
  ///
  /// In tr, this message translates to:
  /// **'Yazar'**
  String get propAuthor;

  /// No description provided for @propSubject.
  ///
  /// In tr, this message translates to:
  /// **'Konu'**
  String get propSubject;

  /// No description provided for @propKeywords.
  ///
  /// In tr, this message translates to:
  /// **'Anahtar sözcükler'**
  String get propKeywords;

  /// No description provided for @propCreator.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturan uygulama'**
  String get propCreator;

  /// No description provided for @propProducer.
  ///
  /// In tr, this message translates to:
  /// **'PDF üreticisi'**
  String get propProducer;

  /// No description provided for @propCreated.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturulma'**
  String get propCreated;

  /// No description provided for @propModified.
  ///
  /// In tr, this message translates to:
  /// **'Değiştirilme'**
  String get propModified;

  /// No description provided for @propVersion.
  ///
  /// In tr, this message translates to:
  /// **'PDF sürümü'**
  String get propVersion;

  /// No description provided for @propPages.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa sayısı'**
  String get propPages;

  /// No description provided for @propPageSize.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa boyutu (bu sayfa)'**
  String get propPageSize;

  /// No description provided for @propSecurity.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik'**
  String get propSecurity;

  /// No description provided for @propPasswordProtected.
  ///
  /// In tr, this message translates to:
  /// **'Parolalı'**
  String get propPasswordProtected;

  /// No description provided for @propSigned.
  ///
  /// In tr, this message translates to:
  /// **'Dijital imzalı'**
  String get propSigned;

  /// No description provided for @propNoSecurity.
  ///
  /// In tr, this message translates to:
  /// **'Yok'**
  String get propNoSecurity;

  /// No description provided for @propUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Bilgiler okunamadı.'**
  String get propUnreadable;

  /// No description provided for @propSectionDocument.
  ///
  /// In tr, this message translates to:
  /// **'Belge'**
  String get propSectionDocument;

  /// No description provided for @propSectionFile.
  ///
  /// In tr, this message translates to:
  /// **'Dosya ve sayfalar'**
  String get propSectionFile;

  /// No description provided for @nightMode.
  ///
  /// In tr, this message translates to:
  /// **'Gece modu'**
  String get nightMode;

  /// No description provided for @pageColorWhite.
  ///
  /// In tr, this message translates to:
  /// **'Beyaz'**
  String get pageColorWhite;

  /// No description provided for @pageColorBlack.
  ///
  /// In tr, this message translates to:
  /// **'Siyah'**
  String get pageColorBlack;

  /// No description provided for @pageColorStraw.
  ///
  /// In tr, this message translates to:
  /// **'Saman kâğıdı'**
  String get pageColorStraw;

  /// No description provided for @toolTextSelect.
  ///
  /// In tr, this message translates to:
  /// **'Metin seç'**
  String get toolTextSelect;

  /// No description provided for @textCopied.
  ///
  /// In tr, this message translates to:
  /// **'Metin kopyalandı'**
  String get textCopied;

  /// No description provided for @textCopyNotAllowed.
  ///
  /// In tr, this message translates to:
  /// **'Bu belge metin kopyalamaya izin vermiyor.'**
  String get textCopyNotAllowed;

  /// No description provided for @copyText.
  ///
  /// In tr, this message translates to:
  /// **'Metni kopyala'**
  String get copyText;

  /// No description provided for @bugReport.
  ///
  /// In tr, this message translates to:
  /// **'Hata bildir'**
  String get bugReport;

  /// No description provided for @bugReportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hatayı nasıl bildirmek istersin?'**
  String get bugReportTitle;

  /// No description provided for @bugReportEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta ile'**
  String get bugReportEmail;

  /// No description provided for @bugReportEmailHint.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine. Hesap gerekmez; ekran görüntüsü de ekleyebilirsin.'**
  String bugReportEmailHint(String email);

  /// No description provided for @bugReportGitHub.
  ///
  /// In tr, this message translates to:
  /// **'GitHub\'da'**
  String get bugReportGitHub;

  /// No description provided for @bugReportGitHubHint.
  ///
  /// In tr, this message translates to:
  /// **'GitHub hesabı gerekir. Bildirim herkese açık görünür, gelişmesini oradan izleyebilirsin.'**
  String get bugReportGitHubHint;

  /// No description provided for @bugReportSubject.
  ///
  /// In tr, this message translates to:
  /// **'Inken PDF hata bildirimi'**
  String get bugReportSubject;

  /// No description provided for @bugReportWhat.
  ///
  /// In tr, this message translates to:
  /// **'Ne oldu?'**
  String get bugReportWhat;

  /// No description provided for @bugReportExpected.
  ///
  /// In tr, this message translates to:
  /// **'Ne olmasını bekliyordun?'**
  String get bugReportExpected;

  /// No description provided for @bugReportSteps.
  ///
  /// In tr, this message translates to:
  /// **'Nasıl tekrarlanır?'**
  String get bugReportSteps;

  /// No description provided for @bugReportCopiedEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta uygulaması açılamadı. Bildirim metni panoya kopyalandı; {email} adresine gönderebilirsin.'**
  String bugReportCopiedEmail(String email);

  /// No description provided for @bugReportCopiedGitHub.
  ///
  /// In tr, this message translates to:
  /// **'Tarayıcı açılamadı. Bildirim metni panoya kopyalandı; {url}/issues adresine yapıştırabilirsin.'**
  String bugReportCopiedGitHub(String url);

  /// No description provided for @aboutPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik: Inken PDF hiçbir veri toplamaz ve internete bağlanmaz. Ayarların, son belgelerin ve yedeklerin yalnızca bu cihazda kalır.'**
  String get aboutPrivacy;

  /// No description provided for @sectionSelect.
  ///
  /// In tr, this message translates to:
  /// **'Neyi seçeceksin'**
  String get sectionSelect;

  /// No description provided for @selectDrawings.
  ///
  /// In tr, this message translates to:
  /// **'Çizimler'**
  String get selectDrawings;

  /// No description provided for @selectText.
  ///
  /// In tr, this message translates to:
  /// **'Metin'**
  String get selectText;

  /// No description provided for @opacity.
  ///
  /// In tr, this message translates to:
  /// **'Opaklık'**
  String get opacity;

  /// No description provided for @percent.
  ///
  /// In tr, this message translates to:
  /// **'%{value}'**
  String percent(int value);

  /// No description provided for @editImage.
  ///
  /// In tr, this message translates to:
  /// **'Görseli düzenle'**
  String get editImage;

  /// No description provided for @imageEditHint.
  ///
  /// In tr, this message translates to:
  /// **'Köşe ve kenarlardan sürükleyerek kırp; çerçevenin içinden tutup kaydır.'**
  String get imageEditHint;

  /// No description provided for @cropRatio.
  ///
  /// In tr, this message translates to:
  /// **'Kırpma oranı'**
  String get cropRatio;

  /// No description provided for @cropFree.
  ///
  /// In tr, this message translates to:
  /// **'Serbest'**
  String get cropFree;

  /// No description provided for @cropOriginal.
  ///
  /// In tr, this message translates to:
  /// **'Orijinal'**
  String get cropOriginal;

  /// No description provided for @imageSizeOnPage.
  ///
  /// In tr, this message translates to:
  /// **'Sayfadaki boyut'**
  String get imageSizeOnPage;

  /// No description provided for @imageWidth.
  ///
  /// In tr, this message translates to:
  /// **'Genişlik'**
  String get imageWidth;

  /// No description provided for @imageHeight.
  ///
  /// In tr, this message translates to:
  /// **'Yükseklik'**
  String get imageHeight;

  /// No description provided for @unitCm.
  ///
  /// In tr, this message translates to:
  /// **'cm'**
  String get unitCm;

  /// No description provided for @aspectLocked.
  ///
  /// In tr, this message translates to:
  /// **'En-boy oranı kilitli'**
  String get aspectLocked;

  /// No description provided for @aspectUnlocked.
  ///
  /// In tr, this message translates to:
  /// **'En-boy oranı serbest'**
  String get aspectUnlocked;

  /// No description provided for @aspectHint.
  ///
  /// In tr, this message translates to:
  /// **'Kilitliyken en-boy oranı korunur.'**
  String get aspectHint;

  /// No description provided for @rotate.
  ///
  /// In tr, this message translates to:
  /// **'Döndür'**
  String get rotate;

  /// No description provided for @rotateLeftShort.
  ///
  /// In tr, this message translates to:
  /// **'Sola'**
  String get rotateLeftShort;

  /// No description provided for @rotateRightShort.
  ///
  /// In tr, this message translates to:
  /// **'Sağa'**
  String get rotateRightShort;

  /// No description provided for @resetEdits.
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get resetEdits;

  /// No description provided for @applyEdits.
  ///
  /// In tr, this message translates to:
  /// **'Uygula'**
  String get applyEdits;

  /// No description provided for @printTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yazdır'**
  String get printTitle;

  /// No description provided for @printPrinter.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı'**
  String get printPrinter;

  /// No description provided for @printNoPrinter.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı bulunamadı'**
  String get printNoPrinter;

  /// No description provided for @printDefaultPrinter.
  ///
  /// In tr, this message translates to:
  /// **'varsayılan yazıcı'**
  String get printDefaultPrinter;

  /// No description provided for @printCopies.
  ///
  /// In tr, this message translates to:
  /// **'Kopya'**
  String get printCopies;

  /// No description provided for @printPages.
  ///
  /// In tr, this message translates to:
  /// **'Sayfalar'**
  String get printPages;

  /// No description provided for @printPagesAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get printPagesAll;

  /// No description provided for @printPagesCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli sayfa'**
  String get printPagesCurrent;

  /// No description provided for @printPagesCurrentShort.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli'**
  String get printPagesCurrentShort;

  /// No description provided for @printPagesRange.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get printPagesRange;

  /// No description provided for @printRangeHint.
  ///
  /// In tr, this message translates to:
  /// **'ör. 1-3, 5'**
  String get printRangeHint;

  /// No description provided for @printRangeInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz aralık (1–{count})'**
  String printRangeInvalid(int count);

  /// No description provided for @printSize.
  ///
  /// In tr, this message translates to:
  /// **'Boyut'**
  String get printSize;

  /// No description provided for @printFit.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaya sığdır'**
  String get printFit;

  /// No description provided for @printActual.
  ///
  /// In tr, this message translates to:
  /// **'Gerçek boyut'**
  String get printActual;

  /// No description provided for @printDrawings.
  ///
  /// In tr, this message translates to:
  /// **'Çizimleri yazdır'**
  String get printDrawings;

  /// No description provided for @printMore.
  ///
  /// In tr, this message translates to:
  /// **'Diğer seçenekler'**
  String get printMore;

  /// No description provided for @printColor.
  ///
  /// In tr, this message translates to:
  /// **'Renk'**
  String get printColor;

  /// No description provided for @printColorOn.
  ///
  /// In tr, this message translates to:
  /// **'Renkli'**
  String get printColorOn;

  /// No description provided for @printGray.
  ///
  /// In tr, this message translates to:
  /// **'Gri tonlamalı'**
  String get printGray;

  /// No description provided for @printDuplex.
  ///
  /// In tr, this message translates to:
  /// **'Çift taraflı'**
  String get printDuplex;

  /// No description provided for @printDuplexOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get printDuplexOff;

  /// No description provided for @printDuplexLong.
  ///
  /// In tr, this message translates to:
  /// **'Uzun kenardan çevir'**
  String get printDuplexLong;

  /// No description provided for @printDuplexShort.
  ///
  /// In tr, this message translates to:
  /// **'Kısa kenardan çevir'**
  String get printDuplexShort;

  /// No description provided for @printPaper.
  ///
  /// In tr, this message translates to:
  /// **'Kâğıt'**
  String get printPaper;

  /// No description provided for @printOrientation.
  ///
  /// In tr, this message translates to:
  /// **'Yönlendirme'**
  String get printOrientation;

  /// No description provided for @printOrientationAuto.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get printOrientationAuto;

  /// No description provided for @printPortrait.
  ///
  /// In tr, this message translates to:
  /// **'Dikey'**
  String get printPortrait;

  /// No description provided for @printLandscape.
  ///
  /// In tr, this message translates to:
  /// **'Yatay'**
  String get printLandscape;

  /// No description provided for @printOrientationHint.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik: yatay sayfalar kâğıda sığacak şekilde döndürülür.'**
  String get printOrientationHint;

  /// No description provided for @printCollate.
  ///
  /// In tr, this message translates to:
  /// **'Kopyaları harmanla'**
  String get printCollate;

  /// No description provided for @printReverse.
  ///
  /// In tr, this message translates to:
  /// **'Sayfaları ters sırala'**
  String get printReverse;

  /// No description provided for @printProperties.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı özellikleri…'**
  String get printProperties;

  /// No description provided for @printPropertiesHint.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcının kendi ayar penceresi: baskı kalitesi, kâğıt türü.'**
  String get printPropertiesHint;

  /// No description provided for @printSummary.
  ///
  /// In tr, this message translates to:
  /// **'{pages} sayfa · {copies} kopya'**
  String printSummary(int pages, int copies);

  /// No description provided for @printContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get printContinue;

  /// No description provided for @printAndroidHint.
  ///
  /// In tr, this message translates to:
  /// **'Yazıcı, kopya sayısı ve renk bir sonraki ekranda seçilir.'**
  String get printAndroidHint;

  /// No description provided for @printPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlanıyor…'**
  String get printPreparing;

  /// No description provided for @printPreviewLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa {page} önizlemesi'**
  String printPreviewLabel(int page);

  /// No description provided for @printDecrease.
  ///
  /// In tr, this message translates to:
  /// **'Azalt'**
  String get printDecrease;

  /// No description provided for @printIncrease.
  ///
  /// In tr, this message translates to:
  /// **'Artır'**
  String get printIncrease;

  /// No description provided for @printPrevPage.
  ///
  /// In tr, this message translates to:
  /// **'Önceki sayfa'**
  String get printPrevPage;

  /// No description provided for @printNextPage.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki sayfa'**
  String get printNextPage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
