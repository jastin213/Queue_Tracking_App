import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/daily_queue_capacity.dart';

Map<String, dynamic> _booking(
  String id,
  String queue, {
  String status = 'Pending',
}) => {'appointmentId': id, 'queue': queue, 'status': status};

void main() {
  const policy = DailyQueueCapacityPolicy();

  test('default shared limit allocates 40 slots to each source', () {
    expect(policy.dailyLimit, 80);
    expect(policy.sourceLimit, 40);
    expect(const DailyQueueUsage().appointmentRemaining(policy), 40);
    expect(const DailyQueueUsage().walkInRemaining(policy), 40);
  });

  test('shared configuration accepts supported slider values only', () {
    for (var limit = 20; limit <= 150; limit += 10) {
      final parsed = DailyQueueCapacityPolicy.tryParse({'dailyLimit': limit});
      expect(parsed?.dailyLimit, limit);
      expect(parsed?.sourceLimit, limit ~/ 2);
    }
    for (final invalid in [
      null,
      '80',
      0,
      19,
      81,
      160,
      80.5,
      double.infinity,
      double.nan,
      <String, dynamic>{},
    ]) {
      expect(DailyQueueCapacityPolicy.tryParse(invalid), isNull);
    }
    expect(DailyQueueCapacityPolicy.fromData(null).dailyLimit, 80);
    expect(
      () => DailyQueueCapacityPolicy.fromData({'dailyLimit': 81}),
      throwsFormatException,
    );
  });

  test('Gas and Diesel share one appointment allocation', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: List.generate(
        40,
        (i) => _booking('a$i', '${i < 20 ? 'G' : 'D'}${i + 1}'),
      ),
      queueItems: [],
    );
    expect(usage.appointmentUsed, 40);
    expect(usage.appointmentRemaining(policy), 0);
    expect(usage.walkInUsed, 0);
    expect(usage.walkInRemaining(policy), 40);
  });

  test('walk-ins cannot borrow unused appointment slots', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [],
      queueItems: List.generate(
        40,
        (i) => {
          'queue': '${i < 20 ? 'G' : 'D'}${i + 1}',
          'source': 'Walk-in',
          'status': 'Waiting',
        },
      ),
    );
    expect(usage.walkInUsed, 40);
    expect(usage.walkInRemaining(policy), 0);
    expect(usage.appointmentRemaining(policy), 40);
  });

  test('approved appointment and live mirror consume one slot', () {
    final booking = _booking('approved', 'G005', status: 'Approved');
    final usage = DailyQueueUsage.fromRecords(
      appointments: [booking],
      queueItems: [
        {...booking, 'source': 'Appointment', 'status': 'Waiting'},
      ],
    );
    expect(usage.appointmentUsed, 1);
    expect(usage.walkInUsed, 0);
  });

  test('distinct appointment IDs with the same legacy code are preserved', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [_booking('first', 'G005'), _booking('second', 'G005')],
      queueItems: [],
    );
    expect(usage.appointmentUsed, 2);
  });

  test('rejected and expired bookings release unused reservations', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [
        _booking('rejected', 'G001', status: 'Rejected'),
        _booking('expired', 'G002', status: 'Expired'),
        _booking('pending', 'G003'),
      ],
      queueItems: [],
    );
    expect(usage.appointmentUsed, 1);
  });

  test('completed services still consume their original source quota', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [_booking('done', 'G001', status: 'Approved')],
      queueItems: [
        {
          'appointmentId': 'done',
          'queue': 'G001',
          'source': 'Skipped / No Show',
          'status': 'Passed',
        },
        {
          'appointmentId': 'archived',
          'queue': 'D001',
          'source': 'Appointment',
          'status': 'Failed',
        },
        {'queue': 'G002', 'source': 'Walk-in', 'status': 'Passed'},
        {'queue': 'D002', 'source': 'Walk-in', 'status': 'Failed'},
      ],
    );
    expect(usage.appointmentUsed, 2);
    expect(usage.walkInUsed, 2);
  });

  test('cancelled and reset queue records do not consume capacity', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [],
      queueItems: [
        {'queue': 'G001', 'source': 'Walk-in', 'status': 'Cancelled'},
        {'queue': 'D001', 'source': 'Walk-in', 'status': 'Reset'},
        {'queue': 'D002', 'source': 'Appointment', 'status': 'Rejected'},
      ],
    );
    expect(usage.appointmentUsed, 0);
    expect(usage.walkInUsed, 0);
  });

  test('missing IDs use a legacy code without double-counting a mirror', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [
        {'queue': 'G005', 'status': 'Approved'},
        _booking('known', 'D005', status: 'Approved'),
      ],
      queueItems: [
        {'queue': 'G005', 'source': 'Appointment', 'status': 'Waiting'},
        {'queue': 'D005', 'source': 'Appointment', 'status': 'Waiting'},
      ],
    );
    expect(usage.appointmentUsed, 2);
  });

  test(
    'existing over-capacity bookings are preserved without negative slots',
    () {
      final usage = DailyQueueUsage.fromRecords(
        appointments: List.generate(50, (i) => _booking('a$i', 'G${i + 1}')),
        queueItems: [],
      );
      expect(usage.appointmentUsed, 50);
      expect(usage.appointmentRemaining(policy), 0);
      expect(usage.walkInRemaining(policy), 30);
    },
  );

  test(
    'retained completed claims survive deletion of visible report records',
    () {
      final usage = DailyQueueUsage.fromRecords(
        appointments: [],
        queueItems: [],
        completedClaims: {
          'appointment-a': {
            'source': 'appointment',
            'queue': 'G005',
            'appointmentId': 'a',
          },
          'walkin-d': {'source': 'walkin', 'queue': 'D005'},
        },
      );
      expect(usage.appointmentUsed, 1);
      expect(usage.walkInUsed, 1);
      expect(usage.appointmentRemaining(policy), 39);
    },
  );

  test(
    'retained completed claims do not duplicate existing service mirrors',
    () {
      final usage = DailyQueueUsage.fromRecords(
        appointments: [_booking('a', 'G005', status: 'Approved')],
        queueItems: [
          {'queue': 'G005', 'appointmentId': 'a', 'status': 'Passed'},
          {'queueId': 'D005', 'queue': 'D005', 'status': 'Passed'},
        ],
        completedClaims: {
          'a': {'source': 'appointment', 'queue': 'G005', 'appointmentId': 'a'},
          'd': {'source': 'walkin', 'queue': 'D005'},
        },
      );
      expect(usage.appointmentUsed, 1);
      expect(usage.walkInUsed, 1);
    },
  );

  test('immutable appointment quota source overrides an edited display source', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [],
      queueItems: [
        {
          'queue': 'G005',
          'quotaSource': 'appointment',
          'source': 'Walk-in',
          'status': 'Passed',
        },
      ],
    );
    expect(usage.appointmentUsed, 1);
    expect(usage.walkInUsed, 0);
  });

  test('immutable walk-in quota source overrides a stale appointment label', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [],
      queueItems: [
        {
          'queue': 'D005',
          'quotaSource': 'walkin',
          'source': 'Appointment',
          'appointmentId': 'stale-reference',
          'status': 'Passed',
        },
      ],
    );
    expect(usage.appointmentUsed, 0);
    expect(usage.walkInUsed, 1);
  });

  test('legacy document paths preserve distinct appointment identities', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [_booking('new-pending', 'G005')],
      queueItems: [
        {
          'queue': 'G005',
          '_appointmentDocumentPath': 'appointments/old-approved',
          'status': 'Passed',
        },
      ],
    );
    expect(usage.appointmentUsed, 2);
  });

  test('a legacy document path matches the corresponding appointment ID', () {
    final usage = DailyQueueUsage.fromRecords(
      appointments: [_booking('approved', 'G005', status: 'Approved')],
      queueItems: [
        {
          'queue': 'G005',
          '_appointmentDocumentPath': 'appointments/approved',
          'status': 'Passed',
        },
      ],
    );
    expect(usage.appointmentUsed, 1);
  });

  test('grandfathered source usage cannot exceed the combined daily limit', () {
    const usage = DailyQueueUsage(appointmentUsed: 30, walkInUsed: 50);
    expect(usage.totalUsed, 80);
    expect(usage.appointmentRemaining(policy), 0);
    expect(usage.walkInRemaining(policy), 0);
    expect(usage.appointmentUsed, 30);
    expect(usage.walkInUsed, 50);
  });

  test('lowering a limit preserves records while stopping further admissions', () {
    const usage = DailyQueueUsage(appointmentUsed: 25, walkInUsed: 15);
    const lowered = DailyQueueCapacityPolicy(dailyLimit: 40);
    expect(usage.appointmentRemaining(lowered), 0);
    expect(usage.walkInRemaining(lowered), 0);
    expect(usage.totalUsed, 40);
  });
}
