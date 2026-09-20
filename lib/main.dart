import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'screens/display_page.dart';
import 'screens/splash_screen.dart';
import 'services/app_language.dart';
import 'services/customer_preferences.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeAppTheme();
  await initializeAppLanguage();
  await initializeCustomerPreferences();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  List<Route<dynamic>> _initialRoutes(String initialRouteName) {
    if (isDisplayPageLaunch(Uri.base, initialRouteName: initialRouteName)) {
      return [
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: displayPageRoute),
          builder: (_) => const DisplayPage(showBackButton: false),
        ),
      ];
    }

    return [
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SplashScreen(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguageNotifier,
      builder: (context, language, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeModeNotifier,
        builder: (context, themeMode, _) {
          return MaterialApp(
            title: 'Queue System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            locale: language == filipinoLanguage
                ? const Locale('fil', 'PH')
                : const Locale('en', 'US'),
            supportedLocales: const [Locale('en', 'US'), Locale('fil', 'PH')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            onGenerateInitialRoutes: _initialRoutes,
            routes: {
              '/': (_) => const SplashScreen(),
              displayPageRoute: (_) => const DisplayPage(showBackButton: false),
            },
          );
        },
      ),
    );
  }
}
