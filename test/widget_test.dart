import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:queue_tracking_app/main.dart';
import 'package:queue_tracking_app/screens/admin_settings.dart';
import 'package:queue_tracking_app/screens/book_appointment.dart';
import 'package:queue_tracking_app/screens/customer_home.dart';
import 'package:queue_tracking_app/screens/customer_settings.dart';
import 'package:queue_tracking_app/widgets/analytics_line_chart.dart';
import 'package:queue_tracking_app/widgets/app_refresh_indicator.dart';

void main() {
  test('validates Philippine vehicle plate numbers', () {
    expect(validatePhilippinePlateNumber('ABC123'), isNull);
    expect(validatePhilippinePlateNumber('abc1234'), isNull);
    expect(validatePhilippinePlateNumber('AB12345'), isNull);

    expect(validatePhilippinePlateNumber('ABC12'), isNotNull);
    expect(validatePhilippinePlateNumber('ABC12345'), isNotNull);
    expect(validatePhilippinePlateNumber('ABCDEF'), isNotNull);
    expect(validatePhilippinePlateNumber('123456'), isNotNull);
    expect(validatePhilippinePlateNumber('ABC-123'), isNotNull);
  });

  test('customer voice queue alerts are enabled by default', () {
    expect(customerVoiceAlertsEnabledNotifier.value, isTrue);
  });

  testWidgets('shows one shared account login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Account Login'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(find.text('CONTINUE AS WALK-IN'), findsOneWidget);
    expect(find.text('Login or Create Account'), findsOneWidget);
    expect(find.byType(AppRefreshIndicator), findsNothing);
    expect(find.text('Customer Portal'), findsNothing);
    expect(find.text('Admin Login'), findsNothing);
    expect(
      find.text('Admins and customers use the same login form.'),
      findsNothing,
    );
  });

  testWidgets('opens the password recovery dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final forgotPasswordLink = find.text('Forgot Password?');
    await tester.ensureVisible(forgotPasswordLink);
    await tester.pumpAndSettle();
    await tester.tap(forgotPasswordLink);
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('SEND RESET LINK'), findsOneWidget);
    expect(find.textContaining('create a new password'), findsOneWidget);
  });

  testWidgets('registration can show and hide the password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final createAccountLink = find.text('Create Account');
    await tester.ensureVisible(createAccountLink);
    await tester.pumpAndSettle();
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.text('Customer Registration'), findsOneWidget);

    final passwordField = find.byType(TextField).last;
    await tester.ensureVisible(passwordField);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('pulling down refreshes and shows confirmation', (
    WidgetTester tester,
  ) async {
    bool refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: () async {
              refreshed = true;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 900)],
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(refreshed, isTrue);
    expect(find.text('Refreshed just now'), findsOneWidget);
  });

  testWidgets('analytics line graph renders both data series', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsLineChart(
            labels: ['Jan\n26', 'Feb\n26', 'Mar\n26'],
            servedValues: [12, 20, 16],
            appointmentValues: [8, 14, 18],
          ),
        ),
      ),
    );

    expect(find.text('Served'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings scrolls normally without pull to refresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminSettings()));

    expect(find.text('Admin Settings'), findsOneWidget);
    expect(find.byType(AppRefreshIndicator), findsNothing);

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.physics, isA<ClampingScrollPhysics>());
  });

  testWidgets('customer home provides settings and logout actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CustomerHome()));

    expect(find.byTooltip('Customer settings'), findsOneWidget);
    expect(find.byTooltip('Log out'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
  });
}
