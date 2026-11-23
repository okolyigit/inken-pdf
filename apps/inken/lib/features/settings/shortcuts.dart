import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Belge ekranının klavye kısayolları. Tuşlar yalnızca burada tanımlanır:
/// belge ekranı bunlara bağlanır ([shortcutKeys]), Ayarlar → Kısayollar
/// aynı tablodan listeler. Böylece liste gerçek bağlardan kopamaz.
enum AppShortcut {
  newDocument,
  open,
  save,
  saveAs,
  export,
  print,
  close,
  documentProperties,
  undo,
  redo,
  cut,
  copy,
  paste,
  selectAll,
  find,
  capture,
  deleteSelection,
  settings,
  toolPen,
  toolHighlighter,
  toolShape,
  toolText,
  toolEraser,
  toolLaser,
  toolSelect,
  spotlight,
  curtain,
  previousPage,
  nextPage,
  firstPage,
  lastPage,
  goToPage,
  rotateRight,
  rotateLeft,
  zoomIn,
  zoomOut,
  fitPage,
  actualSize,
  fitWidth,
  fullscreen,
  escape,
}

/// Her kısayolun tuşları; ilki listede gösterilir, hepsi çalışır.
const Map<AppShortcut, List<SingleActivator>> shortcutKeys = {
  AppShortcut.newDocument: [
    SingleActivator(LogicalKeyboardKey.keyN, control: true),
  ],
  AppShortcut.open: [SingleActivator(LogicalKeyboardKey.keyO, control: true)],
  AppShortcut.save: [SingleActivator(LogicalKeyboardKey.keyS, control: true)],
  AppShortcut.saveAs: [
    SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
  ],
  AppShortcut.export: [SingleActivator(LogicalKeyboardKey.keyE, control: true)],
  AppShortcut.print: [SingleActivator(LogicalKeyboardKey.keyP, control: true)],
  AppShortcut.close: [SingleActivator(LogicalKeyboardKey.keyW, control: true)],
  AppShortcut.documentProperties: [
    SingleActivator(LogicalKeyboardKey.keyD, control: true),
  ],
  AppShortcut.undo: [SingleActivator(LogicalKeyboardKey.keyZ, control: true)],
  AppShortcut.redo: [
    SingleActivator(LogicalKeyboardKey.keyY, control: true),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
  ],
  AppShortcut.cut: [SingleActivator(LogicalKeyboardKey.keyX, control: true)],
  AppShortcut.copy: [SingleActivator(LogicalKeyboardKey.keyC, control: true)],
  AppShortcut.paste: [SingleActivator(LogicalKeyboardKey.keyV, control: true)],
  AppShortcut.selectAll: [
    SingleActivator(LogicalKeyboardKey.keyA, control: true),
  ],
  AppShortcut.find: [SingleActivator(LogicalKeyboardKey.keyF, control: true)],
  AppShortcut.capture: [
    SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true),
  ],
  AppShortcut.deleteSelection: [
    SingleActivator(LogicalKeyboardKey.delete),
    SingleActivator(LogicalKeyboardKey.backspace),
  ],
  AppShortcut.settings: [
    SingleActivator(LogicalKeyboardKey.comma, control: true),
  ],
  AppShortcut.toolPen: [SingleActivator(LogicalKeyboardKey.keyP)],
  AppShortcut.toolHighlighter: [SingleActivator(LogicalKeyboardKey.keyH)],
  AppShortcut.toolShape: [SingleActivator(LogicalKeyboardKey.keyG)],
  AppShortcut.toolText: [SingleActivator(LogicalKeyboardKey.keyT)],
  AppShortcut.toolEraser: [SingleActivator(LogicalKeyboardKey.keyE)],
  AppShortcut.toolLaser: [SingleActivator(LogicalKeyboardKey.keyL)],
  AppShortcut.toolSelect: [SingleActivator(LogicalKeyboardKey.keyV)],
  AppShortcut.spotlight: [SingleActivator(LogicalKeyboardKey.keyS)],
  AppShortcut.curtain: [SingleActivator(LogicalKeyboardKey.keyC)],
  AppShortcut.previousPage: [SingleActivator(LogicalKeyboardKey.pageUp)],
  AppShortcut.nextPage: [SingleActivator(LogicalKeyboardKey.pageDown)],
  AppShortcut.firstPage: [SingleActivator(LogicalKeyboardKey.home)],
  AppShortcut.lastPage: [SingleActivator(LogicalKeyboardKey.end)],
  AppShortcut.goToPage: [
    SingleActivator(LogicalKeyboardKey.keyG, control: true),
  ],
  AppShortcut.rotateRight: [
    SingleActivator(LogicalKeyboardKey.keyR, control: true),
  ],
  AppShortcut.rotateLeft: [
    SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true),
  ],
  AppShortcut.zoomIn: [
    SingleActivator(LogicalKeyboardKey.equal, control: true),
  ],
  AppShortcut.zoomOut: [
    SingleActivator(LogicalKeyboardKey.minus, control: true),
  ],
  AppShortcut.fitPage: [
    SingleActivator(LogicalKeyboardKey.digit0, control: true),
  ],
  AppShortcut.actualSize: [
    SingleActivator(LogicalKeyboardKey.digit1, control: true),
  ],
  AppShortcut.fitWidth: [
    SingleActivator(LogicalKeyboardKey.digit2, control: true),
  ],
  AppShortcut.fullscreen: [SingleActivator(LogicalKeyboardKey.f11)],
  AppShortcut.escape: [SingleActivator(LogicalKeyboardKey.escape)],
};

/// [event]'e uyan kısayol; yoksa `null`.
AppShortcut? matchShortcut(KeyEvent event, Set<AppShortcut> among) {
  for (final s in among) {
    for (final a in shortcutKeys[s]!) {
      if (a.accepts(event, HardwareKeyboard.instance)) return s;
    }
  }
  return null;
}

/// Listede bir satır: tuşlar (her biri ayrı rozet, `+` ile) ve açıklama.
typedef ShortcutRow = ({List<String> keys, String label});

/// Kısayollar sayfasının grupları. Bağlı kısayolların tuşları
/// [shortcutKeys]'ten gelir; tabloya girmeyen hareketler (boşluk, Shift ile
/// çizim, Ctrl + tekerlek) elle eklenir.
List<(String, List<ShortcutRow>)> shortcutGroups(AppLocalizations l10n) {
  ShortcutRow row(AppShortcut s, String label) =>
      (keys: activatorKeys(shortcutKeys[s]!.first), label: label);
  return [
    (
      l10n.menuFile,
      [
        row(AppShortcut.newDocument, l10n.newDocument),
        row(AppShortcut.open, l10n.openPdf),
        row(AppShortcut.save, l10n.save),
        row(AppShortcut.saveAs, l10n.saveAs),
        row(AppShortcut.export, l10n.exportTitle),
        row(AppShortcut.print, l10n.printDocument),
        row(AppShortcut.documentProperties, l10n.propertiesTitle),
        row(AppShortcut.close, l10n.closeDocument),
      ],
    ),
    (
      l10n.menuEdit,
      [
        row(AppShortcut.undo, l10n.undo),
        row(AppShortcut.redo, l10n.redo),
        (
          keys: activatorKeys(shortcutKeys[AppShortcut.redo]![1]),
          label: l10n.redo,
        ),
        row(AppShortcut.cut, l10n.cut),
        row(AppShortcut.copy, l10n.copy),
        row(AppShortcut.paste, l10n.paste),
        row(AppShortcut.selectAll, l10n.selectAll),
        row(AppShortcut.find, l10n.find),
        row(AppShortcut.capture, l10n.captureRegion),
        row(AppShortcut.deleteSelection, l10n.deleteSelection),
        row(AppShortcut.settings, l10n.settings),
      ],
    ),
    (
      l10n.menuTools,
      [
        row(AppShortcut.toolPen, l10n.toolPen),
        row(AppShortcut.toolHighlighter, l10n.toolHighlighter),
        row(AppShortcut.toolLaser, l10n.toolLaser),
        row(AppShortcut.toolEraser, l10n.toolEraser),
        row(AppShortcut.toolShape, l10n.toolShape),
        row(AppShortcut.toolText, l10n.toolText),
        row(AppShortcut.toolSelect, l10n.toolSelect),
        row(AppShortcut.spotlight, l10n.spotlight),
        row(AppShortcut.curtain, l10n.curtain),
        (keys: [l10n.keySpace], label: l10n.shortcutSpaceHold),
        (keys: ['Shift'], label: l10n.shortcutShiftShape),
        (keys: ['Enter'], label: l10n.shortcutTextEnter),
      ],
    ),
    (
      l10n.shortcutPagesView,
      [
        row(AppShortcut.nextPage, l10n.nextPage),
        row(AppShortcut.previousPage, l10n.previousPage),
        (keys: [l10n.keySpace], label: l10n.nextPage),
        (keys: ['Shift', l10n.keySpace], label: l10n.previousPage),
        row(AppShortcut.firstPage, l10n.shortcutFirstPage),
        row(AppShortcut.lastPage, l10n.shortcutLastPage),
        row(AppShortcut.goToPage, l10n.goToPageTitle),
        row(AppShortcut.rotateRight, l10n.rotateRight),
        row(AppShortcut.rotateLeft, l10n.rotateLeft),
        row(AppShortcut.zoomIn, l10n.zoomIn),
        row(AppShortcut.zoomOut, l10n.zoomOut),
        row(AppShortcut.fitPage, l10n.fitPage),
        row(AppShortcut.fitWidth, l10n.fitWidth),
        row(AppShortcut.actualSize, l10n.actualSize),
        (keys: ['Ctrl', l10n.keyWheel], label: l10n.shortcutZoomWheel),
        row(AppShortcut.fullscreen, l10n.fullscreen),
        row(AppShortcut.escape, l10n.shortcutEscape),
      ],
    ),
  ];
}

/// Tuş adları: "Ctrl", "Shift", "S", "Page Down"…
List<String> activatorKeys(SingleActivator a) => [
  if (a.control) 'Ctrl',
  if (a.alt) 'Alt',
  if (a.shift) 'Shift',
  switch (a.trigger) {
    LogicalKeyboardKey.equal => '+',
    LogicalKeyboardKey.minus => '−',
    LogicalKeyboardKey.comma => ',',
    LogicalKeyboardKey.delete => 'Delete',
    LogicalKeyboardKey.escape => 'Esc',
    final k => k.keyLabel,
  },
];
