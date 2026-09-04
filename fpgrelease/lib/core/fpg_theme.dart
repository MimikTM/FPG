import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';

/// Global light/dark switch for the whole app.
///
/// FPGTheme.accent / FPGTheme.muted / etc. used to be compile-time `const`
/// values, which is why dozens of screens could write
/// `TextStyle(color: FPGTheme.muted)`. A real runtime theme switch
/// needs those to be readable at any time, so they are now getters that
/// look at [isLight]. Any call site that still wraps them in `const` will
/// no longer compile — that is intentional: it is exactly the set of
/// places that need to drop the `const` keyword to actually repaint when
/// the user flips the setting.
class FPGTheme {
  FPGTheme._();

  /// Notifies MaterialApp (and anything else listening) that the palette
  /// changed. Read `FPGTheme.isLight` for the current value.
  static final ValueNotifier<bool> modeNotifier = ValueNotifier<bool>(false);

  static bool get isLight => modeNotifier.value;

  static const String _prefsKey = 'fpg_light_mode';

  /// Called once at app startup, before runApp, so the very first frame
  /// already uses the saved preference instead of flashing dark mode first.
  static Future<void> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modeNotifier.value = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      // Preferences unavailable (e.g. in tests) — default to dark.
    }
  }

  static Future<void> setLight(bool light) async {
    modeNotifier.value = light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, light);
    } catch (_) {
      // Best-effort persistence; the in-memory toggle still works this session.
    }
  }

  // ==========================================================
  // PALETTE
  // ==========================================================
  // Dark values match the existing look. Light values are a proper light
  // counterpart with the same blue/purple accent identity from the
  // reference screens, not just an inverted dark theme.

  static Color get bg => isLight ? Color(0xFFF3F5FA) : Color(0xFF070B14);
  static Color get surface => isLight ? Color(0xFFFFFFFF) : Color(0xFF101827);
  static Color get surface2 => isLight ? Color(0xFFEDF0F7) : Color(0xFF182238);
  static Color get accent => isLight ? Color(0xFF2A6FE0) : Color(0xFF67D9FF);
  static Color get secondary => isLight ? Color(0xFF7B4FE0) : Color(0xFFA96BFF);
  static Color get muted => isLight ? Color(0xFF5B6472) : Color(0xFF8794A8);
  static Color get textPrimary => isLight ? Color(0xFF10141C) : Colors.white;
  static Color get cardBorder => isLight ? Color(0x14101827) : Colors.white.withValues(alpha: .06);

  /// The purple-to-blue hero gradient used on hero cards / headers in the
  /// reference screens (Home, Matches Details, club/player cards).
  static List<Color> get heroGradient => isLight
      ? [Color(0xFFDCE6FF), Color(0xFFEFE6FF)]
      : [Color(0xFF1B2A4A), Color(0xFF241A38)];

  static ThemeData themeData() => isLight ? light() : dark();

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final bgColor = light ? Color(0xFFF3F5FA) : Color(0xFF070B14);
    final surfaceColor = light ? Color(0xFFFFFFFF) : Color(0xFF101827);
    final surface2Color = light ? Color(0xFFEDF0F7) : Color(0xFF182238);
    final accentColor = light ? Color(0xFF2A6FE0) : Color(0xFF67D9FF);
    final secondaryColor = light ? Color(0xFF7B4FE0) : Color(0xFFA96BFF);
    final onSurfaceColor = light ? Color(0xFF10141C) : Colors.white;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'sans-serif',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: light ? Colors.white : Colors.black,
        secondary: secondaryColor,
        onSecondary: light ? Colors.white : Colors.black,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
        error: Color(0xFFFF6B6B),
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor.withValues(alpha: .94),
        foregroundColor: onSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onSurfaceColor),
        iconTheme: IconThemeData(color: onSurfaceColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: light ? Colors.white : Colors.black,
          elevation: 0,
          minimumSize: Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          minimumSize: Size.fromHeight(52),
          side: BorderSide(color: accentColor.withValues(alpha: .32)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .4),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: light ? Color(0x14101827) : Colors.transparent),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Colors.white : Color(0xFF0D1117),
        indicatorColor: accentColor.withValues(alpha: .2),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      dividerTheme: DividerThemeData(color: light ? Color(0x14101827) : Color(0x12FFFFFF), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2Color,
        contentTextStyle: TextStyle(color: onSurfaceColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      textTheme: (light ? Typography.blackMountainView : Typography.whiteMountainView).apply(
        bodyColor: onSurfaceColor,
        displayColor: onSurfaceColor,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      scrollbarTheme: ScrollbarThemeData(
        radius: Radius.circular(20),
        thickness: WidgetStatePropertyAll(3),
        thumbVisibility: WidgetStatePropertyAll(false),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: accentColor.withValues(alpha: .12),
        circularTrackColor: accentColor.withValues(alpha: .12),
      ),
    );
  }
}

class FPGDecor {
  static BoxDecoration glowCard({bool accent = false}) => BoxDecoration(
    color: FPGTheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: accent ? FPGTheme.accent.withValues(alpha: .28) : FPGTheme.cardBorder),
    boxShadow: accent
        ? [BoxShadow(color: FPGTheme.accent.withValues(alpha: .08), blurRadius: 24, spreadRadius: 1)]
        : (FPGTheme.isLight
            ? [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 16, offset: Offset(0, 4))]
            : []),
  );

  /// The purple/blue diagonal hero gradient used on the reference screens'
  /// header cards (Home banner, Match Details, Club/Player hero).
  static BoxDecoration heroCard({double radius = 24}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: FPGTheme.heroGradient,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: FPGTheme.cardBorder),
  );
}
