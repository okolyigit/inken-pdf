// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Inken PDF';

  @override
  String get homeTagline => 'Open a PDF, pick your pen, teach your lesson.';

  @override
  String get openPdf => 'Open PDF';

  @override
  String openPdfFailed(String error) {
    return 'Couldn\'t open the file: $error';
  }

  @override
  String get passwordTitle => 'Password required';

  @override
  String passwordPrompt(String name) {
    return '“$name” is password protected. Enter the password to open it.';
  }

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordWrong => 'Wrong password. Try again.';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get passwordOpen => 'Open';

  @override
  String get passwordNeeded =>
      'The file is password protected and can\'t be opened without the password.';

  @override
  String get pdfFileType => 'PDF files';

  @override
  String get closeDocument => 'Close document';

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get toolHand => 'Pan';

  @override
  String get toolPen => 'Pen';

  @override
  String get toolHighlighter => 'Highlighter';

  @override
  String get toolEraser => 'Eraser';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get thicknessThin => 'Thin';

  @override
  String get thicknessMedium => 'Medium';

  @override
  String get thicknessThick => 'Thick';

  @override
  String get inputMode => 'Touch behavior';

  @override
  String get inputModeAuto =>
      'Automatic (finger scrolls once a pen is detected)';

  @override
  String get inputModePen => 'Pen draws, finger scrolls';

  @override
  String get inputModeTouch => 'Finger draws, two fingers scroll';

  @override
  String get save => 'Save';

  @override
  String savedTo(String name) {
    return 'Saved: $name';
  }

  @override
  String savedWithSkipped(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Saved: $name. $_temp0 could not be written to the PDF; kept in Inken but not visible in other readers.';
  }

  @override
  String saveFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesBody =>
      'Your drawings are not saved. Save before closing?';

  @override
  String get discardChanges => 'Don\'t save';

  @override
  String get cancel => 'Cancel';

  @override
  String get protectedFileWarning =>
      'This file is encrypted or signed. Drawings will be saved to a separate copy.';

  @override
  String get openNewerFormat =>
      'This file was saved by a newer version of Inken. Update the app to open it.';

  @override
  String get openCorruptData =>
      'The Inken drawing data in this file is damaged. The file was not opened, so no drawings are lost.';

  @override
  String get openPageMismatch =>
      'Another program changed this file\'s pages, so Inken\'s drawings no longer match them. The file was not opened, so no drawings are lost.';

  @override
  String get recoveryTitle => 'Unsaved drawings found';

  @override
  String recoveryBody(String name, String time) {
    return 'Drawings in $name were backed up on $time but never saved. Restore them?';
  }

  @override
  String get recoveryFileChanged =>
      'The file has changed since this backup. Restoring replaces the drawings in the file with the backed-up ones (undo brings them back).';

  @override
  String recoveryFileMissing(String path) {
    return '$path was not found; it may have been moved or deleted. The backup cannot be restored.';
  }

  @override
  String get recoveryRestore => 'Restore';

  @override
  String get recoveryDelete => 'Delete backup';

  @override
  String get recoveryLater => 'Later';

  @override
  String get exportFlattened => 'Export with drawings embedded…';

  @override
  String exportFileName(String base) {
    return '$base (annotated).pdf';
  }

  @override
  String exportedTo(String name) {
    return 'Exported: $name';
  }

  @override
  String exportedWithSkipped(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'are',
      one: 'is',
    );
    return 'Exported: $name. $_temp0 could not be written and $_temp1 missing from the copy.';
  }

  @override
  String exportFailed(String error) {
    return 'Couldn\'t export: $error';
  }

  @override
  String get exportOntoOpenFile =>
      'Cannot export over the open file; choose another name.';

  @override
  String get overwriteTitle => 'File already exists';

  @override
  String overwriteBody(String name) {
    return '$name already exists. Replace it?';
  }

  @override
  String get overwrite => 'Replace';

  @override
  String get saveAs => 'Save as…';

  @override
  String get saveAsOntoOriginal =>
      'Cannot save over the original PDF; choose another name.';

  @override
  String get pickerUnavailable =>
      'Choosing a save location is not supported on this device yet.';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuTools => 'Tools';

  @override
  String get openPdfMenu => 'Open…';

  @override
  String get newDocument => 'New';

  @override
  String get untitledDocument => 'Untitled.pdf';

  @override
  String get menuView => 'View';

  @override
  String get menuPage => 'Page';

  @override
  String get menu => 'Menu';

  @override
  String get more => 'More';

  @override
  String get close => 'Close';

  @override
  String get zoom => 'Zoom';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get fitPage => 'Fit page';

  @override
  String get fitWidth => 'Fit width';

  @override
  String get actualSize => 'Actual size (100%)';

  @override
  String get zoomOptions => 'Zoom options';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get statusSaved => 'Saved';

  @override
  String get statusSaving => 'Saving…';

  @override
  String get statusUnsaved => 'Not saved';

  @override
  String get sectionColor => 'Color';

  @override
  String get sectionThickness => 'Thickness';

  @override
  String get thicknessVeryThick => 'Extra thick';

  @override
  String toolOptions(String tool) {
    return '$tool options';
  }

  @override
  String get colorBlack => 'Black';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorPink => 'Pink';

  @override
  String get toolLaser => 'Vanishing pen';

  @override
  String get sectionEraserMode => 'Eraser type';

  @override
  String get eraserStroke => 'Stroke';

  @override
  String get eraserPixel => 'Pixel';

  @override
  String get sectionSize => 'Size';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get goToPage => 'Go to page…';

  @override
  String get find => 'Find…';

  @override
  String get searchHint => 'Search document';

  @override
  String get searchNoResults => 'No results';

  @override
  String searchCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get searchNext => 'Next match';

  @override
  String get searchPrevious => 'Previous match';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchSearching => 'Searching…';

  @override
  String goToPageLabel(int count) {
    return 'Page number (1–$count)';
  }

  @override
  String get go => 'Go';

  @override
  String windowTitle(String name) {
    return '$name – Inken PDF';
  }

  @override
  String get goToPageTitle => 'Go to page';

  @override
  String get colorBrick => 'Brick';

  @override
  String get menuBars => 'Toolbars and panels';

  @override
  String get toolDock => 'Toolbox';

  @override
  String get dockTop => 'Top';

  @override
  String get dockLeft => 'Left';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get exitFullscreen => 'Exit full screen (Esc)';

  @override
  String get toolSelect => 'Select';

  @override
  String get deleteSelection => 'Delete selection';

  @override
  String get fadeFloating => 'Fade idle floating controls';

  @override
  String get pageScrollbar => 'Page scrollbar';

  @override
  String get toolShape => 'Shape';

  @override
  String get sectionShape => 'Shape';

  @override
  String get shapeLine => 'Line';

  @override
  String get shapeArrow => 'Arrow';

  @override
  String get shapeRectangle => 'Rectangle';

  @override
  String get shapeEllipse => 'Ellipse';

  @override
  String get shapeCoordinate => 'Coordinate plane';

  @override
  String get sectionInstruments => 'Measuring tools';

  @override
  String get instrumentRuler => 'Ruler';

  @override
  String get instrumentSetSquare => 'Set square';

  @override
  String get instrumentProtractor => 'Protractor';

  @override
  String get instrumentCompass => 'Compass';

  @override
  String instrumentClose(String name) {
    return 'Close $name';
  }

  @override
  String instrumentCentimeters(String value) {
    return '$value cm';
  }

  @override
  String get recentTitle => 'Recent';

  @override
  String get recentRemove => 'Remove from list';

  @override
  String get recentMissing => 'File not found';

  @override
  String get recentUnsaved => 'Unsaved changes';

  @override
  String recentOpenFailed(String name) {
    return 'Couldn\'t open \"$name\". It may have been moved or deleted.';
  }

  @override
  String recentToday(String time) {
    return 'Today $time';
  }

  @override
  String recentYesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String recentPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get introTitle => 'What you can do';

  @override
  String get introSubtitle => 'The toolbox becomes active once you open a PDF.';

  @override
  String get introHide => 'Hide';

  @override
  String get introShowSetting => 'Show introduction on start';

  @override
  String get introToolsHeading => 'Tools';

  @override
  String get introLessonHeading => 'During the lesson';

  @override
  String get keySpace => 'Space';

  @override
  String get introPen =>
      'Write with the pen; with a pressure-sensitive pen, lines get thicker as you press. Tap the tool again for color and thickness.';

  @override
  String get introHighlighter =>
      'Mark over text; the text underneath stays readable.';

  @override
  String get introShape =>
      'Line, arrow, rectangle, ellipse, coordinate plane. Hold Shift for squares and circles. The panel has a ruler, set square, protractor and compass: the pen follows their edges.';

  @override
  String get introEraser =>
      'Erases the stroke you touch, or only the part you pass over. The pen\'s eraser end works too.';

  @override
  String get introLaser =>
      'Point and explain: what you draw fades in a few seconds and is not saved.';

  @override
  String get introSelect =>
      'Tap or drag a rectangle to select; drag to move, pull a corner to resize, Delete to remove.';

  @override
  String get introHand =>
      'Drag to scroll. With any other tool, hold Space to scroll for a moment.';

  @override
  String get introUndo => 'Every step can be undone, even after saving.';

  @override
  String get introSave =>
      'Drawings are saved inside the PDF and show in every PDF reader. The original file is never overwritten.';

  @override
  String get introExport =>
      'Makes a copy with drawings merged into the page, for sharing with students and printing.';

  @override
  String get introBackupTitle => 'Automatic backup';

  @override
  String get introBackup =>
      'Unsaved drawings are backed up every minute; if the app closes unexpectedly, they are offered back on the next start.';

  @override
  String get introFullscreen =>
      'Menus hide; only the page and the toolbox remain. Esc exits.';

  @override
  String get introPagesTitle => 'Moving between pages';

  @override
  String get introPages =>
      'Go page by page, jump with the bar on the right, or tap the page number and type one.';

  @override
  String get toolText => 'Text';

  @override
  String get introText =>
      'Tap the page and type; Enter starts a new line. Tap existing text to edit it. Turkish letters and math symbols (√ π ≤ ∞) are fully supported.';

  @override
  String get customColor => 'Custom color';

  @override
  String get customColorNew => 'New color';

  @override
  String get colorHue => 'Hue';

  @override
  String get colorSaturationValue => 'Saturation and brightness';

  @override
  String get colorHex => 'Color code';

  @override
  String get colorHexInvalid => 'Invalid code';

  @override
  String get colorChoose => 'Choose';

  @override
  String get quickBar => 'Quick access bar';

  @override
  String get settings => 'Settings';

  @override
  String get settingsMenu => 'Settings…';

  @override
  String get printDocument => 'Print…';

  @override
  String appendPage(String template) {
    return 'Add page at the end: $template';
  }

  @override
  String get insertPage => 'Insert page';

  @override
  String get deletePage => 'Delete page';

  @override
  String get rotatePage => 'Rotate page';

  @override
  String get rotateRight => 'Rotate right';

  @override
  String get rotateLeft => 'Rotate left';

  @override
  String get pageOrientation => 'Page orientation';

  @override
  String get orientationPortrait => 'Portrait';

  @override
  String get orientationLandscape => 'Landscape';

  @override
  String get insertPageBefore => 'Insert page before';

  @override
  String get movePageUp => 'Move up';

  @override
  String get movePageDown => 'Move down';

  @override
  String get insertPageAfter => 'Insert page after';

  @override
  String get insertPageHere => 'Insert page here';

  @override
  String get pageActions => 'Page actions';

  @override
  String pagesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages selected',
      one: '1 page selected',
    );
    return '$_temp0';
  }

  @override
  String get clearPageSelection => 'Clear selection';

  @override
  String deletePages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count pages',
      one: 'Delete page',
    );
    return '$_temp0';
  }

  @override
  String pagesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages deleted',
      one: '1 page deleted',
    );
    return '$_temp0';
  }

  @override
  String get exportShort => 'Export';

  @override
  String get settingsInput => 'Pen and touch';

  @override
  String get settingsShortcuts => 'Shortcuts';

  @override
  String get settingsAbout => 'About';

  @override
  String get shortcutSpaceHold => 'Hold: pan temporarily';

  @override
  String get shortcutShiftShape =>
      'Hold while drawing a shape: square, circle, 15° steps';

  @override
  String get shortcutTextEnter => 'While typing: new line';

  @override
  String get shortcutPagesView => 'Pages and view';

  @override
  String get shortcutFirstPage => 'First page';

  @override
  String get shortcutLastPage => 'Last page';

  @override
  String get keyWheel => 'Wheel';

  @override
  String get shortcutZoomWheel => 'Zoom in / out';

  @override
  String get shortcutEscape =>
      'Close panel, clear selection, close spotlight / curtain, exit full screen';

  @override
  String get shortcutsNote =>
      'Most shortcuts work while a document is open (Ctrl+O and Ctrl+, work everywhere). Single-letter shortcuts are off while typing.';

  @override
  String get aboutDescription =>
      'A light, fast PDF reader you can write and draw on. Drawings are saved inside the PDF and appear in any PDF reader. Free, no account needed.';

  @override
  String get aboutFonts =>
      'Fonts: Figtree, Fraunces, JetBrains Mono (SIL Open Font License) and DejaVu Sans (Bitstream Vera license).';

  @override
  String get aboutAppLicense =>
      'Inken PDF is free software: you can use, modify and redistribute it under the GNU General Public License version 3 or any later version (GPL-3.0-or-later). It comes with no warranty. This is a beta; keep a separate copy of important files.';

  @override
  String get aboutLicenses => 'Licenses';

  @override
  String get templateBlank => 'Blank';

  @override
  String get templateGrid => 'Grid';

  @override
  String get templateDotted => 'Dotted';

  @override
  String get templateLined => 'Lined';

  @override
  String get templateCoordinate => 'Coordinate plane';

  @override
  String pageDeleted(int page) {
    return 'Page $page deleted';
  }

  @override
  String pageLayoutFailed(String error) {
    return 'Couldn\'t prepare pages: $error';
  }

  @override
  String get printSent => 'Sent to the printer';

  @override
  String printFailed(String error) {
    return 'Couldn\'t print: $error';
  }

  @override
  String get printUnsupported =>
      'This printer doesn\'t accept PDF. Choose another printer, or export and print from a PDF reader.';

  @override
  String get shareDocument => 'Share…';

  @override
  String get shareMailed => 'The file was attached to a new email';

  @override
  String get shareShown => 'No email app found; showing the file in its folder';

  @override
  String shareFailed(String error) {
    return 'Couldn\'t share: $error';
  }

  @override
  String get shareUnsupported =>
      'Sharing files isn\'t available on this system. Save the document and send the file yourself.';

  @override
  String get phoneToolsShow => 'Show drawing tools';

  @override
  String get phoneToolsHide => 'Hide drawing tools';

  @override
  String get dropPdfHere => 'Drop to open the PDF';

  @override
  String get dropOnlyPdf => 'Only PDF files can be opened';

  @override
  String get dockBottom => 'Bottom';

  @override
  String get dockRight => 'Right';

  @override
  String get dockMove => 'Move the toolbox (drag or tap)';

  @override
  String get spotlight => 'Spotlight';

  @override
  String get curtain => 'Curtain';

  @override
  String get spotlightResize =>
      'Resize (drag; the wheel or two fingers work too)';

  @override
  String get spotlightClose => 'Close spotlight (Esc)';

  @override
  String get curtainClose => 'Close curtain (Esc)';

  @override
  String get curtainHint => 'Pull down to reveal';

  @override
  String get introSpotlight =>
      'Light up one part of the page and dim the rest. Drag the dim area to move the light; keep writing inside it.';

  @override
  String get introCurtain =>
      'Cover the page and pull down to reveal it line by line; keep the answer for last.';

  @override
  String get paste => 'Paste';

  @override
  String get insertImage => 'Insert image…';

  @override
  String get imageFileType => 'Images';

  @override
  String get clipboardNoImage =>
      'No image on the clipboard. Copy an image or a screenshot and try again.';

  @override
  String get imageUnreadable => 'Couldn\'t open the image';

  @override
  String get dropOnlyPdfOrImage => 'Only PDF and image files can be dropped';

  @override
  String get dropPdfOrImageHere => 'Drop a PDF or an image';

  @override
  String get introImageTitle => 'Image';

  @override
  String get introImage =>
      'Paste a copied image or screenshot with Ctrl+V; it comes in selected, resize it from a corner. You can also add one from a file or drag it onto the window.';

  @override
  String get stageCover => 'Spotlight / curtain';

  @override
  String get menuHelp => 'Help';

  @override
  String get aboutApp => 'About Inken PDF';

  @override
  String get settingsInfo => 'App information';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get guideMenu => 'Getting started';

  @override
  String get guideFileName => 'Getting Started.pdf';

  @override
  String versionWithBuild(String version, String build) {
    return '$version (build $build)';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutRepository => 'Inken PDF on GitHub';

  @override
  String get aboutRepositoryHint => 'Source, releases and feedback';

  @override
  String get shareApp => 'Share Inken PDF';

  @override
  String shareAppText(String url) {
    return 'Inken PDF: a light, fast, free PDF reader you can write and draw on. No account needed, open source: $url';
  }

  @override
  String get shareAppCopied => 'Description and link copied to the clipboard';

  @override
  String linkOpenFailed(String url) {
    return 'Couldn\'t open the link: $url';
  }

  @override
  String get linkOpenTitle => 'Open link?';

  @override
  String linkOpenBody(String url) {
    return '$url will open in your browser.';
  }

  @override
  String get linkOpen => 'Open';

  @override
  String get infoIntro =>
      'Include this information when you report a problem; it helps track it down.';

  @override
  String get infoCopy => 'Copy';

  @override
  String get infoCopied => 'App information copied to the clipboard';

  @override
  String get infoVersion => 'Version';

  @override
  String get infoPlatform => 'Operating system';

  @override
  String get infoDart => 'Dart';

  @override
  String get infoPdfEngine => 'PDF engine';

  @override
  String get infoFormat => 'File format (inken.json)';

  @override
  String get infoLanguage => 'Language';

  @override
  String get infoScreen => 'Screen';

  @override
  String get infoStylusSeen => 'Pen detected';

  @override
  String get infoDataFolder => 'Data folder (settings, backups)';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get toolHighlighterShort => 'Marker';

  @override
  String get toolLaserShort => 'Laser';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get selectAll => 'Select all';

  @override
  String recolorSelection(String color) {
    return 'Selection color: $color';
  }

  @override
  String get clipboardMarker => 'Inken PDF items';

  @override
  String get selectionBar => 'Selection';

  @override
  String get pagePanel => 'Page thumbnails';

  @override
  String get pagePanelTitle => 'Pages';

  @override
  String get pagePanelPages => 'Pages';

  @override
  String get outline => 'Contents';

  @override
  String get outlineEmpty => 'This document has no table of contents.';

  @override
  String get outlineExpand => 'Show subheadings';

  @override
  String get outlineCollapse => 'Hide subheadings';

  @override
  String pageThumbnail(int page) {
    return 'Page $page';
  }

  @override
  String get uiScale => 'Interface size';

  @override
  String get uiScaleNormal => 'Normal';

  @override
  String get uiScaleLarge => 'Large';

  @override
  String get uiScaleLarger => 'Smart board';

  @override
  String get pagePanelClose => 'Close page panel';

  @override
  String get pagePanelOpen => 'Open page panel';

  @override
  String get documentProperties => 'Document properties…';

  @override
  String get propertiesTitle => 'Document properties';

  @override
  String get propFile => 'File';

  @override
  String get propLocation => 'Location';

  @override
  String get propNotSaved => 'Not saved yet';

  @override
  String get propFileSize => 'File size';

  @override
  String get propTitle => 'Title';

  @override
  String get propAuthor => 'Author';

  @override
  String get propSubject => 'Subject';

  @override
  String get propKeywords => 'Keywords';

  @override
  String get propCreator => 'Created with';

  @override
  String get propProducer => 'PDF producer';

  @override
  String get propCreated => 'Created';

  @override
  String get propModified => 'Modified';

  @override
  String get propVersion => 'PDF version';

  @override
  String get propPages => 'Pages';

  @override
  String get propPageSize => 'Page size (this page)';

  @override
  String get propSecurity => 'Security';

  @override
  String get propPasswordProtected => 'Password protected';

  @override
  String get propSigned => 'Digitally signed';

  @override
  String get propNoSecurity => 'None';

  @override
  String get propUnreadable => 'Could not read the properties.';

  @override
  String get propSectionDocument => 'Document';

  @override
  String get propSectionFile => 'File and pages';

  @override
  String get nightMode => 'Night mode';

  @override
  String get pageColorWhite => 'White';

  @override
  String get pageColorBlack => 'Black';

  @override
  String get pageColorStraw => 'Manila';

  @override
  String get toolTextSelect => 'Select text';

  @override
  String get textCopied => 'Text copied';

  @override
  String get textCopyNotAllowed => 'This document does not allow copying text.';

  @override
  String get copyText => 'Copy text';

  @override
  String get bugReport => 'Report a bug';

  @override
  String get bugReportTitle => 'How would you like to report it?';

  @override
  String get bugReportEmail => 'By email';

  @override
  String bugReportEmailHint(String email) {
    return 'To $email. No account needed; you can attach a screenshot.';
  }

  @override
  String get bugReportGitHub => 'On GitHub';

  @override
  String get bugReportGitHubHint =>
      'Needs a GitHub account. The report is public and you can follow its progress there.';

  @override
  String get bugReportSubject => 'Inken PDF bug report';

  @override
  String get bugReportWhat => 'What happened?';

  @override
  String get bugReportExpected => 'What did you expect?';

  @override
  String get bugReportSteps => 'How can it be reproduced?';

  @override
  String bugReportCopiedEmail(String email) {
    return 'Couldn\'t open an email app. The report was copied to the clipboard; you can send it to $email.';
  }

  @override
  String bugReportCopiedGitHub(String url) {
    return 'Couldn\'t open the browser. The report was copied to the clipboard; you can paste it at $url/issues.';
  }

  @override
  String get aboutPrivacy =>
      'Privacy: Inken PDF collects no data and doesn\'t connect to the internet. Your settings, recent documents and backups stay on this device.';

  @override
  String get sectionSelect => 'What to select';

  @override
  String get selectDrawings => 'Drawings';

  @override
  String get selectText => 'Text';

  @override
  String get opacity => 'Opacity';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String get editImage => 'Edit image';

  @override
  String get imageEditHint =>
      'Drag the corners and edges to crop; drag inside the frame to move it.';

  @override
  String get cropRatio => 'Crop ratio';

  @override
  String get cropFree => 'Free';

  @override
  String get cropOriginal => 'Original';

  @override
  String get imageSizeOnPage => 'Size on page';

  @override
  String get imageWidth => 'Width';

  @override
  String get imageHeight => 'Height';

  @override
  String get unitCm => 'cm';

  @override
  String get aspectLocked => 'Aspect ratio locked';

  @override
  String get aspectUnlocked => 'Aspect ratio unlocked';

  @override
  String get aspectHint => 'While locked, the aspect ratio is kept.';

  @override
  String get rotate => 'Rotate';

  @override
  String get rotateLeftShort => 'Left';

  @override
  String get rotateRightShort => 'Right';

  @override
  String get resetEdits => 'Reset';

  @override
  String get applyEdits => 'Apply';

  @override
  String get printTitle => 'Print';

  @override
  String get printPrinter => 'Printer';

  @override
  String get printNoPrinter => 'No printer found';

  @override
  String get printDefaultPrinter => 'default printer';

  @override
  String get printCopies => 'Copies';

  @override
  String get printPages => 'Pages';

  @override
  String get printPagesAll => 'All';

  @override
  String get printPagesCurrent => 'Current page';

  @override
  String get printPagesCurrentShort => 'Current';

  @override
  String get printPagesRange => 'Range';

  @override
  String get printRangeHint => 'e.g. 1-3, 5';

  @override
  String printRangeInvalid(int count) {
    return 'Invalid range (1–$count)';
  }

  @override
  String get printSize => 'Size';

  @override
  String get printFit => 'Fit to page';

  @override
  String get printActual => 'Actual size';

  @override
  String get printDrawings => 'Print drawings';

  @override
  String get printMore => 'More options';

  @override
  String get printColor => 'Color';

  @override
  String get printColorOn => 'Color';

  @override
  String get printGray => 'Grayscale';

  @override
  String get printDuplex => 'Two-sided';

  @override
  String get printDuplexOff => 'Off';

  @override
  String get printDuplexLong => 'Flip on long edge';

  @override
  String get printDuplexShort => 'Flip on short edge';

  @override
  String get printPaper => 'Paper';

  @override
  String get printOrientation => 'Orientation';

  @override
  String get printOrientationAuto => 'Automatic';

  @override
  String get printPortrait => 'Portrait';

  @override
  String get printLandscape => 'Landscape';

  @override
  String get printOrientationHint =>
      'Automatic: landscape pages are rotated to fit the paper.';

  @override
  String get printCollate => 'Collate copies';

  @override
  String get printReverse => 'Reverse page order';

  @override
  String get printProperties => 'Printer properties…';

  @override
  String get printPropertiesHint =>
      'The printer\'s own settings: print quality, paper type.';

  @override
  String printSummary(int pages, int copies) {
    return '$pages pages · $copies copies';
  }

  @override
  String get printContinue => 'Continue';

  @override
  String get printAndroidHint =>
      'Printer, copies and color are chosen on the next screen.';

  @override
  String get printPreparing => 'Preparing…';

  @override
  String printPreviewLabel(int page) {
    return 'Page $page preview';
  }

  @override
  String get printDecrease => 'Decrease';

  @override
  String get printIncrease => 'Increase';

  @override
  String get printPrevPage => 'Previous page';

  @override
  String get printNextPage => 'Next page';

  @override
  String get captureRegion => 'Capture area';

  @override
  String get captureHint =>
      'Drag a frame around the area to capture, or tap a page to capture all of it.';

  @override
  String get captureBar => 'Capture';

  @override
  String get captureSave => 'Save…';

  @override
  String get captureShare => 'Share…';

  @override
  String get captureToNewPage => 'Put on a new page';

  @override
  String get captureToNewPageHint =>
      'Places the captured area at the top of a new blank page added after it, with room to work below.';

  @override
  String get captureCopied => 'Image copied to the clipboard';

  @override
  String get captureCopyUnsupported =>
      'Images can\'t be copied to the clipboard on this system; save or share it instead.';

  @override
  String captureFailed(String error) {
    return 'Couldn\'t capture the image: $error';
  }

  @override
  String captureFileName(String base, int page) {
    return '$base - page $page.png';
  }

  @override
  String get pngFileType => 'PNG image';

  @override
  String get sharePageImage => 'Share page as image…';
}
