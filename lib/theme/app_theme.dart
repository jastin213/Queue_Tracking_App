import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePreferenceKey = 'app_dark_mode_enabled';

/// The selected appearance is shared by the admin and customer interfaces.
/// It is stored only on the current device and does not change Firestore data.
final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

Future<void> initializeAppTheme() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final isDark = preferences.getBool(_themePreferenceKey) ?? false;
    appThemeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {
    appThemeModeNotifier.value = ThemeMode.light;
  }
}

Future<void> setAppDarkMode(bool enabled) async {
  appThemeModeNotifier.value = enabled ? ThemeMode.dark : ThemeMode.light;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_themePreferenceKey, enabled);
  } catch (_) {
    // The mode still changes for this session if device storage is unavailable.
  }
}

bool get isAppDarkMode => appThemeModeNotifier.value == ThemeMode.dark;

/// Shared visual tokens for the application.
///
/// Keeping these values in one place lets future design refinements remain
/// consistent without touching authentication, queue, appointment, or report
/// logic.
abstract final class AppColors {
  // Shared visual language: crisp slate canvas, deep service-industry navy,
  // clean white surfaces, and restrained status accents.
  static const Color background = Color(0xFFF1F5F8);
  static const Color primary = Color(0xFF0F2B48);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFD3DEE7);
  static const Color mutedText = Color(0xFF607487);
  static const Color softPrimary = Color(0xFFEDF3F7);
  static const Color accent = Color(0xFF2563EB);
  static const Color success = Color(0xFF0D9568);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE5484D);

  // Dark mode keeps the same brand character while increasing the depth
  // between the page canvas, cards, and inset controls.
  static const Color darkBackground = Color(0xFF07111D);
  static const Color darkPrimary = Color(0xFF7CC5E8);
  static const Color darkSurface = Color(0xFF0F2233);
  static const Color darkBorder = Color(0xFF294158);
  static const Color darkMutedText = Color(0xFFB8C7D5);
  static const Color darkSoftPrimary = Color(0xFF172F43);

  static Color get activeBackground =>
      isAppDarkMode ? darkBackground : background;
  static Color get activePrimary => isAppDarkMode ? darkPrimary : primary;
  static Color get activeSurface => isAppDarkMode ? darkSurface : surface;
  static Color get activeBorder => isAppDarkMode ? darkBorder : border;
  static Color get activeMutedText => isAppDarkMode ? darkMutedText : mutedText;
  static Color get activeSoftPrimary =>
      isAppDarkMode ? darkSoftPrimary : softPrimary;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
}

abstract final class AppRadii {
  static const double control = 12;
  static const double card = 18;
  static const double dialog = 22;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration chartEntrance = Duration(milliseconds: 650);
  static const Duration notificationAttention = Duration(milliseconds: 720);
  static const Duration statusPulse = Duration(milliseconds: 1500);
  static const Curve emphasizedCurve = Curves.easeOutCubic;
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedCurve,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Shared depth effects used by reusable visual surfaces.
abstract final class AppEffects {
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: isAppDarkMode
          ? Colors.black.withValues(alpha: 0.26)
          : const Color(0xFF16324F).withValues(alpha: 0.075),
      blurRadius: 18,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> get raisedShadow => [
    BoxShadow(
      color: isAppDarkMode
          ? Colors.black.withValues(alpha: 0.34)
          : const Color(0xFF16324F).withValues(alpha: 0.12),
      blurRadius: 26,
      offset: const Offset(0, 9),
    ),
  ];
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 850;
  static const double expanded = 1100;
  static const double maxContentWidth = 1240;
  static const double maxFormWidth = 880;
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.success,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.primary,
          error: AppColors.danger,
          onError: Colors.white,
          outline: AppColors.border,
          surfaceContainerLow: const Color(0xFFF8FAFC),
          surfaceContainer: AppColors.softPrimary,
          surfaceContainerHigh: const Color(0xFFE1E9EF),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.primary,
        displayColor: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      hoverColor: AppColors.primary.withValues(alpha: 0.055),
      focusColor: AppColors.primary.withValues(alpha: 0.10),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        shape: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: AppColors.primary.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: AppColors.primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppEffects.cardShadow,
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.quick,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primary.withValues(alpha: 0.09);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primary.withValues(alpha: 0.14);
            }
            return null;
          }),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.primary,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.softPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F9FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: const TextStyle(color: AppColors.mutedText),
        hintStyle: const TextStyle(color: AppColors.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border, width: 1.15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.42),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border, width: 1.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mutedText;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.softPrimary,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.softPrimary.withValues(alpha: 0.55),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.softPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppRadii.dialog),
            bottomRight: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.softPrimary),
        headingTextStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: const TextStyle(color: AppColors.primary),
        dividerThickness: 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.darkPrimary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.darkPrimary,
          onPrimary: Colors.white,
          secondary: AppColors.success,
          onSecondary: Colors.white,
          surface: AppColors.darkSurface,
          onSurface: const Color(0xFFF4F8FB),
          error: const Color(0xFFFF6B67),
          onError: Colors.white,
          outline: AppColors.darkBorder,
          surfaceContainerLow: const Color(0xFF0E202D),
          surfaceContainer: AppColors.darkSoftPrimary,
          surfaceContainerHigh: const Color(0xFF29495C),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: const Color(0xFFF4F8FB),
        displayColor: const Color(0xFFF4F8FB),
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      hoverColor: AppColors.darkPrimary.withValues(alpha: 0.10),
      focusColor: AppColors.darkPrimary.withValues(alpha: 0.15),
      highlightColor: AppColors.darkPrimary.withValues(alpha: 0.08),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Color(0xFFE8F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFE8F2F7),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.30),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF29495C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: AppEffects.cardShadow,
        ),
        textStyle: const TextStyle(
          color: Color(0xFFF4F8FB),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.quick,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.darkPrimary.withValues(alpha: 0.13);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.darkPrimary.withValues(alpha: 0.20);
            }
            return null;
          }),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: const Color(0xFFE8F2F7),
        textColor: const Color(0xFFE8F2F7),
        selectedColor: AppColors.darkPrimary,
        selectedTileColor: AppColors.darkSoftPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSoftPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: const TextStyle(color: AppColors.darkMutedText),
        hintStyle: const TextStyle(color: AppColors.darkMutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(
            color: AppColors.darkBorder,
            width: 1.15,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(
            color: AppColors.darkPrimary,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBackground,
          disabledBackgroundColor: AppColors.darkPrimary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white60,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: const Color(0xFFE8F2F7),
          backgroundColor: AppColors.darkSurface,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.darkPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.darkBackground
              : AppColors.darkMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.darkPrimary
              : AppColors.darkBorder;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.darkPrimary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.darkBackground),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.darkPrimary
              : AppColors.darkMutedText;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSoftPrimary,
        selectedColor: AppColors.darkPrimary,
        disabledColor: AppColors.darkSoftPrimary.withValues(alpha: 0.55),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFF4F8FB),
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.darkBackground,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.darkSoftPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: Color(0xFFF4F8FB), fontWeight: FontWeight.w700),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppRadii.dialog),
            bottomRight: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(
          AppColors.darkSoftPrimary,
        ),
        headingTextStyle: const TextStyle(
          color: Color(0xFFF4F8FB),
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: const TextStyle(color: Color(0xFFF4F8FB)),
        dividerThickness: 0.8,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.darkBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF20394B),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    );
  }
}
