import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/screens/admin_page.dart';
import 'package:queue_tracking_app/screens/book_appointment.dart';
import 'package:queue_tracking_app/services/app_language.dart';
import 'package:queue_tracking_app/services/booking_queue_availability.dart';
import 'package:queue_tracking_app/services/daily_queue_capacity.dart';
import 'package:queue_tracking_app/theme/app_theme.dart';

const _bookingDate = '10/25/2026';

Map<String, dynamic> _appointment(String queue, String status) => {
  'queue': queue,
  'status': status,
  'date': _bookingDate,
};

Finder _queuePill(String code) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      (widget.properties.label?.contains(code) ?? false),
);

Future<dynamic> _pumpBookingPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const BookAppointment()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(appText('I UNDERSTAND')));
  await tester.pumpAndSettle();
  final dynamic state = tester.state(find.byType(BookAppointment));
  state.setState(() {
    state.selectedDate = DateTime(2026, 10, 25);
    state.selectedQueueCode = 'G001';
  });
  await tester.pump();
  return state;
}

void main() {
  setUp(() {
    appLanguageNotifier.value = englishLanguage;
    appThemeModeNotifier.value = ThemeMode.light;
    final pending = pendingBookings.value;
    final approved = approvedBookings.value;
    final issued = issuedQueueCodesNotifier.value;
    final waiting = waitingQueueNotifier.value;
    final serving = nowServingNotifier.value;
    addTearDown(() {
      pendingBookings.value = pending;
      approvedBookings.value = approved;
      issuedQueueCodesNotifier.value = issued;
      waitingQueueNotifier.value = waiting;
      nowServingNotifier.value = serving;
    });
    pendingBookings.value = [];
    approvedBookings.value = [];
    issuedQueueCodesNotifier.value = {};
    waitingQueueNotifier.value = [];
    nowServingNotifier.value = null;
  });

  test('Pending reserves a code while Approved marks it taken', () {
    expect(
      appointmentQueueCodeStates([
        _appointment('G005', 'Pending'),
        _appointment('G006', 'Approved'),
      ]),
      {
        'G005': BookingQueueCodeState.pendingApproval,
        'G006': BookingQueueCodeState.taken,
      },
    );
  });

  test('rejected, expired and cancelled appointments release reservations', () {
    expect(
      appointmentQueueCodeStates([
        _appointment('G005', 'Rejected'),
        _appointment('G006', 'Expired'),
        _appointment('G007', 'Cancelled'),
      ]),
      isEmpty,
    );
    expect(appointmentQueueCodeStates([]), isEmpty);
  });

  test('another active appointment still reserves the same code', () {
    expect(
      appointmentQueueCodeStates([
        _appointment('G005', 'Rejected'),
        _appointment('G005', 'Pending'),
      ])['G005'],
      BookingQueueCodeState.pendingApproval,
    );
  });

  test('Approved takes precedence over Pending in either record order', () {
    final records = [
      _appointment('G005', 'Pending'),
      _appointment('G005', 'Approved'),
    ];
    for (final order in [records, records.reversed]) {
      expect(
        appointmentQueueCodeStates(order)['G005'],
        BookingQueueCodeState.taken,
      );
    }
  });

  test('live queue claims preserve existing statuses and release resets', () {
    expect(
      unavailableLiveQueueCodes([
        _appointment('G001', 'Waiting'),
        _appointment('G002', 'Now Serving'),
        _appointment('G003', 'Skipped'),
        _appointment('G004', 'Passed'),
        _appointment('G005', 'Failed'),
        _appointment('G006', 'Cancelled'),
        _appointment('G007', 'Reset'),
      ]),
      {'G001', 'G002', 'G003', 'G004', 'G005'},
    );
  });

  test('blank queue codes cannot create reservations', () {
    expect(
      appointmentQueueCodeStates([
        {'status': 'Pending'},
      ]),
      isEmpty,
    );
    expect(
      unavailableLiveQueueCodes([
        {'status': 'Waiting'},
      ]),
      isEmpty,
    );
  });

  testWidgets(
    'Pending to Rejected restores the pill and count despite stale local data',
    (tester) async {
      pendingBookings.value = [_appointment('G005', 'Pending')];
      final dynamic state = await _pumpBookingPage(tester);
      state.updateQueueAvailability(
        appointments: [
          _appointment('G005', 'Pending'),
          _appointment('G006', 'Approved'),
        ],
        queueItems: [_appointment('G007', 'Waiting')],
      );
      await tester.pumpAndSettle();

      expect(
        state.queueCodeState('G005'),
        BookingQueueCodeState.pendingApproval,
      );
      expect(state.isQueueTaken('G005'), isTrue);
      expect(find.text('Live availability • 3 unavailable'), findsOneWidget);
      expect(find.text('17 available in this range'), findsOneWidget);
      final reserved = tester.widget<Semantics>(_queuePill('G005'));
      expect(reserved.properties.enabled, isFalse);
      expect(reserved.properties.label, contains('Pending Approval'));

      state.updateQueueAvailability(
        appointments: [
          _appointment('G005', 'Rejected'),
          _appointment('G006', 'Approved'),
        ],
      );
      await tester.pumpAndSettle();

      expect(pendingBookings.value.single['status'], 'Pending');
      expect(state.queueCodeState('G005'), BookingQueueCodeState.available);
      expect(state.isQueueTaken('G005'), isFalse);
      expect(state.isQueueTaken('G006'), isTrue);
      expect(state.isQueueTaken('G007'), isTrue);
      expect(find.text('Live availability • 2 unavailable'), findsOneWidget);
      expect(find.text('18 available in this range'), findsOneWidget);
      expect(
        tester.widget<Semantics>(_queuePill('G005')).properties.enabled,
        isTrue,
      );

      await tester.ensureVisible(_queuePill('G005'));
      await tester.pumpAndSettle();
      await tester.tap(_queuePill('G005'));
      await tester.pumpAndSettle();
      expect(state.selectedQueueCode, 'G005');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rejection cannot release an existing live queue claim', (
    tester,
  ) async {
    pendingBookings.value = [_appointment('G005', 'Pending')];
    final dynamic state = await _pumpBookingPage(tester);
    state.updateQueueAvailability(
      appointments: [_appointment('G005', 'Rejected')],
      queueItems: [_appointment('G005', 'Waiting')],
    );
    await tester.pumpAndSettle();
    expect(state.queueCodeState('G005'), BookingQueueCodeState.taken);
    expect(
      tester.widget<Semantics>(_queuePill('G005')).properties.enabled,
      isFalse,
    );

    state.updateQueueAvailability(queueItems: <Map<String, dynamic>>[]);
    await tester.pumpAndSettle();
    expect(state.queueCodeState('G005'), BookingQueueCodeState.available);
    expect(
      tester.widget<Semantics>(_queuePill('G005')).properties.enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'fallback reservations stay scoped to appointment date and fuel',
    (tester) async {
      pendingBookings.value = [
        _appointment('G005', 'Pending'),
        _appointment('D001', 'Pending'),
        {..._appointment('G006', 'Pending'), 'date': '10/26/2026'},
      ];
      approvedBookings.value = [_appointment('G007', 'Approved')];
      final dynamic state = await _pumpBookingPage(tester);
      expect(
        state.queueCodeState('G005'),
        BookingQueueCodeState.pendingApproval,
      );
      expect(state.queueCodeState('G006'), BookingQueueCodeState.available);
      expect(state.queueCodeState('G007'), BookingQueueCodeState.taken);

      state.setState(() => state.selectedVehicle = 'Diesel');
      await tester.pump();
      expect(state.getQueueCodes(), everyElement(startsWith('D')));
      expect(state.getFirstAvailableQueueCode(), 'D002');

      state.setState(() {
        state.selectedVehicle = 'Gas';
        state.selectedDate = DateTime(2026, 10, 26);
      });
      await tester.pump();
      expect(state.queueCodeState('G005'), BookingQueueCodeState.available);
      expect(
        state.queueCodeState('G006'),
        BookingQueueCodeState.pendingApproval,
      );
      expect(state.queueCodeState('G007'), BookingQueueCodeState.available);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('authoritative empty data releases stale local approved claims', (
    tester,
  ) async {
    pendingBookings.value = [_appointment('G005', 'Pending')];
    approvedBookings.value = [_appointment('G005', 'Approved')];
    issuedQueueCodesNotifier.value = {
      _bookingDate: ['G005'],
    };
    final dynamic state = await _pumpBookingPage(tester);
    expect(state.queueCodeState('G005'), BookingQueueCodeState.taken);

    state.updateQueueAvailability(
      appointments: <Map<String, dynamic>>[],
      queueItems: <Map<String, dynamic>>[],
    );
    await tester.pumpAndSettle();
    expect(state.queueCodeState('G005'), BookingQueueCodeState.available);
    expect(find.text('20 available in this range'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'combined appointment quota disables selection without marking free codes taken',
    (tester) async {
      final dynamic state = await _pumpBookingPage(tester);
      final bookings = List.generate(40, (index) {
        final prefix = index < 20 ? 'G' : 'D';
        final number = 2 * (index % 20) + 1;
        return {
          ..._appointment(
            '$prefix${number.toString().padLeft(3, '0')}',
            'Pending',
          ),
          'appointmentId': 'booking-$index',
        };
      });
      state.updateQueueAvailability(
        appointments: bookings,
        queueItems: <Map<String, dynamic>>[],
      );
      await tester.pumpAndSettle();

      expect(state.queueCapacityUsage.appointmentUsed, 40);
      expect(state.queueCapacityUsage.walkInUsed, 0);
      expect(state.appointmentSlotsRemaining, 0);
      expect(state.isAppointmentQuotaFull, isTrue);
      expect(state.getFirstAvailableQueueCode(), isEmpty);
      expect(state.queueCodeState('G002'), BookingQueueCodeState.available);
      final freePill = tester.widget<Semantics>(_queuePill('G002'));
      expect(freePill.properties.enabled, isFalse);
      expect(freePill.properties.label, contains('appointment slots full'));
      expect(find.text('Appointment slots remaining: 0 of 40'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(
                of: find.text('SUBMIT APPOINTMENT'),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed,
        isNull,
      );

      bookings[0] = {...bookings[0], 'status': 'Rejected'};
      state.updateQueueAvailability(appointments: bookings);
      await tester.pumpAndSettle();
      expect(state.appointmentSlotsRemaining, 1);
      expect(state.isAppointmentQuotaFull, isFalse);
      expect(state.getFirstAvailableQueueCode(), 'G001');
      expect(
        tester.widget<Semantics>(_queuePill('G002')).properties.enabled,
        isTrue,
      );
      expect(find.text('Appointment slots remaining: 1 of 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('approval mirror does not consume another appointment slot', (
    tester,
  ) async {
    final dynamic state = await _pumpBookingPage(tester);
    final approved = {
      ..._appointment('G005', 'Approved'),
      'appointmentId': 'approved-booking',
    };
    state.updateQueueAvailability(
      appointments: [approved],
      queueItems: [
        {...approved, 'source': 'Appointment', 'status': 'Waiting'},
      ],
    );
    await tester.pumpAndSettle();
    expect(state.queueCapacityUsage.appointmentUsed, 1);
    expect(state.appointmentSlotsRemaining, 39);
    expect(find.text('Appointment slots remaining: 39 of 40'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'configured capacity updates code choices and source allocation',
    (tester) async {
      final dynamic state = await _pumpBookingPage(tester);
      state.updateCapacityPolicy(
        const DailyQueueCapacityPolicy(dailyLimit: 100),
      );
      state.updateQueueAvailability(
        appointments: <Map<String, dynamic>>[],
        queueItems: <Map<String, dynamic>>[],
      );
      await tester.pumpAndSettle();
      expect(state.getQueueCodes(), hasLength(100));
      expect(state.getQueueCodes().last, 'G100');
      expect(state.appointmentSlotsRemaining, 50);
      expect(
        find.text('Appointment slots remaining: 50 of 50'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'completed capacity claims remain after report records disappear',
    (tester) async {
      final dynamic state = await _pumpBookingPage(tester);
      state.updateQueueAvailability(
        appointments: <Map<String, dynamic>>[],
        queueItems: <Map<String, dynamic>>[],
      );
      state.updateCompletedCapacityClaims({
        'completed-a': {
          'source': 'appointment',
          'queue': 'G005',
          'appointmentId': 'a',
        },
      });
      await tester.pumpAndSettle();
      expect(state.queueCapacityUsage.appointmentUsed, 1);
      expect(state.appointmentSlotsRemaining, 39);
      expect(state.queueCodeState('G005'), BookingQueueCodeState.taken);
      expect(
        find.text('Appointment slots remaining: 39 of 40'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [360.0, 1080.0]) {
    testWidgets('appointment capacity summary fits a $width pixel screen', (
      tester,
    ) async {
      final dynamic state = await _pumpBookingPage(tester);
      state.updateQueueAvailability(
        appointments: [
          {..._appointment('G005', 'Pending'), 'appointmentId': 'gas-booking'},
          {
            ..._appointment('D005', 'Pending'),
            'appointmentId': 'diesel-booking',
          },
        ],
        queueItems: <Map<String, dynamic>>[],
      );
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Appointment slots remaining: 38 of 40'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Appointment slots remaining: 38 of 40'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Gas and Diesel share the appointment allocation. Walk-in slots are reserved separately.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final language in [englishLanguage, filipinoLanguage]) {
    testWidgets('reserved label fits narrow $language screen at 2x text size', (
      tester,
    ) async {
      final dynamic state = await _pumpBookingPage(tester);
      state.updateQueueAvailability(
        appointments: [_appointment('G005', 'Pending')],
        queueItems: <Map<String, dynamic>>[],
      );
      await tester.pumpAndSettle();
      // Exercise the production queue section independently from unrelated
      // form dropdowns. No callbacks are invoked after its source page closes.
      final Widget queueView = state.queueCodesView(state.getQueueCodes());
      appLanguageNotifier.value = language;
      tester.view.physicalSize = const Size(360, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: queueView,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _queuePill('G005'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Semantics>(_queuePill('G005')).properties.label,
        contains(appText('Reserved—Pending Approval')),
      );
      expect(
        find.descendant(
          of: _queuePill('G005'),
          matching: find.text(appText('Reserved—Pending Approval')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
