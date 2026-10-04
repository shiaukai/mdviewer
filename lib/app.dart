import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/app_state.dart';
import 'ui/home_page.dart';

const _seed = Color(0xFF3B6FE0);
const _zhTW = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW');

class MdViewerApp extends StatelessWidget {
  const MdViewerApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: 'MD Viewer',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: state.messengerKey,
        themeMode: state.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        // Also makes CJK fall back to Traditional Chinese glyphs.
        locale: _zhTW,
        supportedLocales: const [_zhTW, Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomePage(state: state),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        space: 1,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: scheme.surfaceContainerLow),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: TextStyle(fontSize: 12, color: scheme.onInverseSurface),
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(220, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          iconSize: 16,
          // Derive from the theme so the font family is kept.
          textStyle: base.textTheme.bodyMedium?.copyWith(fontSize: 13.5),
        ),
      ),
    );
  }
}
