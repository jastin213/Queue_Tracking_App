import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/screens/customer_onboarding.dart';
import 'package:queue_tracking_app/screens/home_page.dart';
import 'package:queue_tracking_app/screens/splash_screen.dart';
import 'package:queue_tracking_app/services/app_language.dart';
import 'package:queue_tracking_app/services/customer_onboarding.dart';
import 'package:queue_tracking_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLanguageNotifier.value = englishLanguage;
    appThemeModeNotifier.value = ThemeMode.light;
  });

  test('onboarding completion is stored for the device', () async {
    expect(await hasCompletedCustomerOnboarding(), isFalse);

    await completeCustomerOnboarding();

    expect(await hasCompletedCustomerOnboarding(), isTrue);
  });

  testWidgets('customer onboarding shows all three pages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CustomerOnboarding()),
    );

    expect(find.text('Track Your Queue in Real Time'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Book Ahead, Wait Less'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Get Ready at the Right Time'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('onboarding appears before the login screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const HomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Track Your Queue in Real Time'), findsOneWidget);
    expect(find.text('Account Login'), findsNothing);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Account Login'), findsOneWidget);
    expect(await hasCompletedCustomerOnboarding(), isTrue);
  });

  testWidgets('splash screen transitions into onboarding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
    );
    await tester.pump();

    expect(find.text('Smart Queue Management'), findsOneWidget);
    expect(find.text('Track Your Queue in Real Time'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Track Your Queue in Real Time'), findsOneWidget);
  });
}
