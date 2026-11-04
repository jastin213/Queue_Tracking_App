import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/daily_queue_capacity.dart';
import 'package:queue_tracking_app/services/daily_queue_capacity_service.dart';

CapacityDayTransaction day({
  Map<String, dynamic> appointments = const {},
  Map<String, dynamic> walkIns = const {},
  Map<String, dynamic> completed = const {},
  Map<String, dynamic> legacy = const {},
  int limit = 80,
}) => CapacityDayTransaction.fromData(
  '11/4/2026',
  DailyQueueCapacityPolicy(dailyLimit: limit),
  {
    'appointmentClaims': appointments,
    'walkInClaims': walkIns,
    'completedClaims': completed,
    'legacyQueueClaims': legacy,
  },
);

void main() {
  test(
    'the fortieth combined-fuel appointment fits and the next cannot borrow',
    () {
      final claims = {
        for (var n = 1; n <= 39; n++)
          'a$n': '${n.isEven ? 'G' : 'D'}${n.toString().padLeft(3, '0')}',
      };
      final last = day(appointments: claims);
      last.reserveAppointment('last', 'D040');
      expect(last.appointmentClaims.length, 40);
      final full = day(appointments: last.appointmentClaims);
      expect(
        () => full.reserveAppointment('extra', 'G041'),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'resource-exhausted',
          ),
        ),
      );
      expect(full.walkInClaims, isEmpty);
    },
  );
  test(
    'walk-ins have an independent half but cannot exceed combined capacity',
    () {
      final fullAppointments = {
        for (var n = 1; n <= 40; n++) 'a$n': 'G${n.toString().padLeft(3, '0')}',
      };
      final independent = day(appointments: fullAppointments);
      independent.reserveWalkIn('walkin', 'D001');
      expect(independent.walkInClaims.length, 1);
      final legacy = day(
        appointments: {for (var n = 1; n <= 50; n++) 'a$n': 'G$n'},
        walkIns: {for (var n = 1; n <= 30; n++) 'w$n': 'D$n'},
      );
      expect(
        () => legacy.reserveWalkIn('extra', 'D031'),
        throwsA(isA<FirebaseException>()),
      );
    },
  );
  test('another legacy claim keeps a rejected duplicate code reserved', () {
    final transaction = day(appointments: {'first': 'G005', 'second': 'G005'});
    transaction.releaseAppointment('first', 'G005');
    expect(transaction.codeIsReserved('G005'), isTrue);
    expect(transaction.appointmentClaims, {'second': 'G005'});
  });
  test('a completed appointment cannot release its source allocation', () {
    final transaction = day(
      appointments: {'a': 'G001'},
      completed: {
        'appointment:a': {
          'source': 'appointment',
          'queue': 'G001',
          'appointmentId': 'a',
        },
      },
    );
    transaction.releaseAppointment('a', 'G001');
    expect(transaction.hasMutation, isFalse);
    expect(transaction.codeIsReserved('G001'), isTrue);
  });
  test(
    'completion uses immutable migrated identity without rewriting the queue',
    () {
      final transaction = day(
        appointments: {'old': 'G001'},
        legacy: {
          'G001': {'source': 'appointment', 'claimId': 'old'},
        },
      );
      transaction.completeQueue({
        'queue': 'G001',
        'source': 'Walk-in',
        'status': 'Passed',
      });
      expect(transaction.completedClaims['appointment:old'], {
        'source': 'appointment',
        'queue': 'G001',
        'appointmentId': 'old',
      });
      expect(transaction.appointmentClaims.length, 1);
      expect(transaction.walkInClaims, isEmpty);
    },
  );
  test(
    'explicit walk-in identity takes precedence after a cancelled legacy slot is reused',
    () {
      final transaction = day(
        walkIns: {'new': 'G001'},
        legacy: {
          'G001': {'source': 'appointment', 'claimId': 'old'},
        },
      );
      transaction.completeQueue({
        'queue': 'G001',
        'quotaSource': 'walkin',
        'capacityRequestId': 'new',
        'status': 'Passed',
      });
      expect(transaction.completedClaims['walkin:new'], {
        'source': 'walkin',
        'queue': 'G001',
      });
    },
  );
  test('completion is idempotent and cannot double-count a visible mirror', () {
    final transaction = day(
      walkIns: {'w': 'G001'},
      completed: {
        'walkin:w': {'source': 'walkin', 'queue': 'G001'},
      },
    );
    transaction.completeQueue({
      'queue': 'G001',
      'quotaSource': 'walkin',
      'capacityRequestId': 'w',
      'status': 'Passed',
    });
    expect(transaction.hasMutation, isFalse);
    expect(transaction.walkInClaims.length, 1);
  });
  test(
    'a transaction cannot silently mutate several claims under one proof',
    () {
      final transaction = day();
      transaction.reserveAppointment('a', 'G001');
      expect(() => transaction.reserveWalkIn('w', 'D001'), throwsStateError);
    },
  );
}
