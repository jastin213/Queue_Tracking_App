import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:queue_tracking_app/main.dart';
import 'package:queue_tracking_app/services/document_upload_consent.dart';
import 'package:queue_tracking_app/services/firestore_query_fields.dart';
import 'package:queue_tracking_app/services/customer_onboarding.dart';
import 'package:queue_tracking_app/screens/admin_settings.dart';
import 'package:queue_tracking_app/screens/book_appointment.dart';
import 'package:queue_tracking_app/screens/customer_home.dart';
import 'package:queue_tracking_app/screens/customer_settings.dart';
import 'package:queue_tracking_app/screens/display_page.dart';
import 'package:queue_tracking_app/screens/track_page.dart';
import 'package:queue_tracking_app/theme/app_theme.dart';
import 'package:queue_tracking_app/widgets/analytics_line_chart.dart';
import 'package:queue_tracking_app/widgets/app_refresh_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpLoginApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await completeCustomerOnboarding();
  await tester.pumpWidget(const MyApp());
  await tester.pump(const Duration(milliseconds: 2300));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('document authorization can be declined without continuing', (
    tester,
  ) async {
    bool? consentResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  consentResult = await requestDocumentUploadConsent(context);
                },
                child: const Text('CREATE ACCOUNT'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    final acceptButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('ACCEPT & CONTINUE'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(acceptButton.onPressed, isNull);

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(consentResult, isFalse);
  });

  testWidgets('document authorization requires the consent checkbox', (
    tester,
  ) async {
    bool? consentResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  consentResult = await requestDocumentUploadConsent(context);
                },
                child: const Text('CREATE ACCOUNT'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('ACCEPT & CONTINUE'));
    await tester.pumpAndSettle();

    expect(consentResult, isTrue);
  });

  test('builds a dedicated web display route', () {
    final uri = displayPageUri(
      Uri.parse('https://npjn-queue-system-jkr.web.app/#/admin'),
    );

    expect(uri.toString(), 'https://npjn-queue-system-jkr.web.app/#/display');
  });

  test('direct display launches bypass the normal startup flow', () {
    expect(
      isDisplayPageLaunch(
        Uri.parse('https://npjn-queue-system-jkr.web.app/#/display'),
      ),
      isTrue,
    );
    expect(
      isDisplayPageLaunch(
        Uri.parse('https://npjn-queue-system-jkr.web.app/display'),
      ),
      isTrue,
    );
    expect(
      isDisplayPageLaunch(
        Uri.parse('https://npjn-queue-system-jkr.web.app/'),
        initialRouteName: '/display',
      ),
      isTrue,
    );
    expect(
      isDisplayPageLaunch(Uri.parse('https://npjn-queue-system-jkr.web.app/')),
      isFalse,
    );
  });

  test('public display limits the visible upcoming queue numbers', () {
    final waitingQueue = List.generate(
      12,
      (index) => <String, dynamic>{'queue': 'G${index + 1}'},
    );

    expect(visibleWaitingQueues(waitingQueue), hasLength(4));
    expect(visibleWaitingQueues(waitingQueue).last['queue'], 'G4');
  });

  test('normalizes customer names for report search', () {
    expect(normalizeNameForQuery('  jOhN   baptist  '), 'JOHN BAPTIST');
    expect(
      firestoreQueryFields(
        date: '8/25/2026',
        plate: 'zap123',
        name: 'John Baptist',
      )['nameNormalized'],
      'JOHN BAPTIST',
    );
  });

  test('formats long queue durations as hours and minutes', () {
    expect(formatQueueDuration(0), '0 mins');
    expect(formatQueueDuration(59), '59 mins');
    expect(formatQueueDuration(60), '1 hour');
    expect(formatQueueDuration(61), '1 hour 1 min');
    expect(formatQueueDuration(174), '2 hours 54 mins');
    expect(formatQueueDuration(180), '3 hours');
  });

  test('walk-in queue position and time update from the live queue order', () {
    final initialItems = <Map<String, dynamic>>[
      {'queue': 'G002', 'status': 'Now Serving'},
      {'queue': 'G003', 'status': 'Waiting'},
      {'queue': 'G004', 'status': 'Waiting'},
    ];
    final updatedItems = <Map<String, dynamic>>[
      {'queue': 'G002', 'status': 'Passed'},
      {'queue': 'G003', 'status': 'Now Serving'},
      {'queue': 'G004', 'status': 'Waiting'},
    ];

    expect(
      calculateLiveQueuePosition(queueNumber: 'g004', items: initialItems),
      2,
    );
    expect(
      calculateLiveEstimatedQueueTime(queueNumber: 'G004', items: initialItems),
      18,
    );
    expect(
      calculateLiveQueuePosition(queueNumber: 'G004', items: updatedItems),
      1,
    );
    expect(
      calculateLiveEstimatedQueueTime(queueNumber: 'G004', items: updatedItems),
      9,
    );
  });

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

  test('walk-in tracking explicitly bypasses appointment ownership checks', () {
    const walkInTracker = TrackPage(isWalkInTracking: true);
    const appointmentTracker = TrackPage();

    expect(walkInTracker.isWalkInTracking, isTrue);
    expect(appointmentTracker.isWalkInTracking, isFalse);
  });

  test('shared appearance mode switches the active app palette', () {
    addTearDown(() => appThemeModeNotifier.value = ThemeMode.light);

    appThemeModeNotifier.value = ThemeMode.dark;
    expect(AppColors.activeBackground, AppColors.darkBackground);
    expect(AppColors.activeSurface, AppColors.darkSurface);

    appThemeModeNotifier.value = ThemeMode.light;
    expect(AppColors.activeBackground, AppColors.background);
    expect(AppColors.activeSurface, AppColors.surface);
  });

  testWidgets('shows one shared account login', (WidgetTester tester) async {
    await pumpLoginApp(tester);

    expect(find.text('Account Login'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    expect(find.text('OR SIGN IN WITH EMAIL'), findsOneWidget);
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
    await pumpLoginApp(tester);

    final forgotPasswordLink = find.text('Forgot Password?');
    await tester.ensureVisible(forgotPasswordLink);
    await tester.pumpAndSettle();
    await tester.tap(forgotPasswordLink);
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('SEND RESET LINK'), findsOneWidget);
    expect(find.textContaining('create a separate password'), findsOneWidget);
  });

  testWidgets('registration can show and hide the password', (
    WidgetTester tester,
  ) async {
    await pumpLoginApp(tester);

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

  testWidgets('analytics line graph renders all data series', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsLineChart(
            labels: ['Jan\n26', 'Feb\n26', 'Mar\n26'],
            servedValues: [12, 20, 16],
            appointmentValues: [8, 14, 18],
            walkInValues: [4, 6, 5],
            passedValues: [10, 17, 15],
            failedValues: [2, 3, 1],
          ),
        ),
      ),
    );

    expect(find.text('Served'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Walk-ins'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('analytics chart supports the grouped bar view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnalyticsLineChart(
            labels: ['Jan\n26', 'Feb\n26'],
            servedValues: [12, 20],
            appointmentValues: [8, 14],
            walkInValues: [4, 6],
            passedValues: [10, 17],
            failedValues: [2, 3],
            chartType: AnalyticsChartType.bar,
          ),
        ),
      ),
    );

    expect(find.text('Walk-ins'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings scrolls normally without pull to refresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminSettings()));

    expect(find.text('Admin Settings'), findsOneWidget);
    expect(find.text('Voice Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Final Defense Demo Data'), findsNothing);
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

    expect(find.byTooltip('Appointment notifications'), findsOneWidget);
    expect(find.byKey(const Key('customer-theme-mode-toggle')), findsOneWidget);
    expect(find.byTooltip('Customer settings'), findsOneWidget);
    expect(find.byTooltip('Log out'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
  });

  test('appointment tracking accepts only the customer queue for today', () {
    final appointments = <Map<String, dynamic>>[
      {'queue': 'G010', 'date': '9/8/2026'},
      {'queue': 'G002', 'date': '9/7/2026'},
    ];

    expect(
      validateAppointmentQueueOwnership(
        input: 'g010',
        appointments: appointments,
        now: DateTime(2026, 9, 8),
      ),
      isNull,
    );
    expect(
      validateAppointmentQueueOwnership(
        input: 'G011',
        appointments: appointments,
        now: DateTime(2026, 9, 8),
      ),
      contains('G010'),
    );
  });
}
