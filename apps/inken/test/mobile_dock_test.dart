import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inken/features/ink/mobile_dock.dart';
import 'package:inken/features/ink/tool_options.dart';
import 'package:inken/features/ink/tool_state.dart';
import 'package:inken/features/settings/settings_store.dart';
import 'package:inken/l10n/app_localizations.dart';

void main() {
  testWidgets('telefon rafı: Seç düğmesi metin seçmeyi de kapsar', (t) async {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.memory()),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox.shrink(),
            bottomNavigationBar: MobileDock(),
          ),
        ),
      ),
    );
    final select = find.byKey(const ValueKey('tool-select'));
    expect(find.byKey(const ValueKey('tool-textSelect')), findsNothing);

    await t.tap(select);
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.select);

    // Seçiliyken dokunmak alt sayfayı açar; Metin seçilince kapanır.
    await t.tap(select);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('seg-Tool.textSelect')));
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.textSelect);
    expect(find.byKey(const ValueKey('seg-Tool.textSelect')), findsNothing);
    expect(
      find.descendant(
        of: select,
        // Seçili düğmede ikon bir kademe kalın.
        matching: find.byIcon(selectedIcon(toolIcon(Tool.textSelect))),
      ),
      findsOneWidget,
    );

    // Kalemden dönünce son tür.
    await t.tap(find.byKey(const ValueKey('tool-pen')));
    await t.pumpAndSettle();
    await t.tap(select);
    await t.pumpAndSettle();
    expect(container.read(toolProvider).tool, Tool.textSelect);
  });
}
