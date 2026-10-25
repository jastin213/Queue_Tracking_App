import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/admin_notification_event.dart';

void main() {
  final sessionStart = DateTime.utc(2026, 10, 25, 9);
  final now = sessionStart.add(const Duration(minutes: 2));

  Map<String, dynamic> pending({
    String id = 'appointment-1',
    Object? createdAt,
  }) => {
    'appointmentId': id,
    'status': 'Pending',
    'queue': 'G006',
    'date': '10/25/2026',
    'plate': 'TEST123',
    'createdAt': createdAt,
  };

  Map<String, dynamic> decision({
    String id = 'appointment-1',
    bool approved = true,
    Object? decidedAt,
  }) => {
    'appointmentId': id,
    'status': approved ? 'Approved' : 'Rejected',
    'decisionSource': approved
        ? 'conditional_auto_approval'
        : 'conditional_auto_rejection',
    'autoDecisionAt': decidedAt,
  };

  AdminNotificationPopupGate gate() =>
      AdminNotificationPopupGate(sessionStartedAt: sessionStart);

  AdminNotificationEvent? consider(
    AdminNotificationPopupGate popupGate,
    Iterable<Map<String, dynamic>> bookings, {
    bool fromCache = false,
    bool ready = true,
    Set<String> readKeys = const <String>{},
    DateTime? at,
  }) => popupGate.consider(
    events: bookings
        .map(adminNotificationEvent)
        .whereType<AdminNotificationEvent>(),
    fromCache: fromCache,
    readStateReady: ready,
    readKeys: readKeys,
    now: at ?? now,
  );

  group('event parsing', () {
    test('pending uses creation time and preserves appointment data', () {
      final booking = pending(createdAt: Timestamp.fromDate(now));
      final event = adminNotificationEvent(booking)!;

      expect(event.kind, AdminNotificationEventKind.pending);
      expect(event.occurredAt, now);
      expect(event.appointmentId, 'appointment-1');
      expect(event.legacyReadKey, 'pending:appointment-1');
      expect(event.key, 'pending:appointment-1:${now.microsecondsSinceEpoch}');
      expect(event.appointment, booking);
      booking['queue'] = 'G007';
      expect(event.appointment['queue'], 'G006');
    });

    test(
      'pending never uses OCR updates, decision time, or appointment date',
      () {
        final event = adminNotificationEvent({
          ...pending(),
          'autoDecisionAt': now,
          'updatedAt': now,
          'date': now.toIso8601String(),
        })!;

        expect(event.occurredAt, isNull);
        expect(event.key, 'pending:appointment-1:unknown');
      },
    );

    test('automatic approval uses its decision time before approved time', () {
      final event = adminNotificationEvent({
        ...decision(decidedAt: Timestamp.fromDate(now)),
        'approvedAt': sessionStart,
        'updatedAt': now.add(const Duration(minutes: 1)),
      })!;

      expect(event.kind, AdminNotificationEventKind.autoApproved);
      expect(event.occurredAt, now);
      expect(event.legacyReadKey, 'conditional_auto_approval:appointment-1');
    });

    test(
      'automatic decisions fall back only to their matching status time',
      () {
        final approved = adminNotificationEvent({
          ...decision(),
          'approvedAt': now.toIso8601String(),
        })!;
        final rejected = adminNotificationEvent({
          ...decision(approved: false),
          'rejectedAt': Timestamp.fromDate(now),
        })!;
        expect(approved.occurredAt, now);
        expect(rejected.kind, AdminNotificationEventKind.autoRejected);
        expect(rejected.occurredAt, now);
        expect(
          rejected.legacyReadKey,
          'conditional_auto_rejection:appointment-1',
        );

        for (final approvedStatus in [true, false]) {
          expect(
            adminNotificationEvent({
              ...decision(approved: approvedStatus),
              'updatedAt': now,
              'createdAt': now,
              'date': now.toIso8601String(),
            })!.occurredAt,
            isNull,
          );
        }
      },
    );

    test('manual decisions and source/status mismatches are not events', () {
      for (final booking in [
        {'status': 'Approved', 'approvedAt': now},
        {'status': 'Rejected', 'decisionSource': 'manual'},
        {'status': 'Expired', 'decisionSource': 'conditional_auto_rejection'},
        {'status': 'Approved', 'decisionSource': 'conditional_auto_rejection'},
        {'status': 'Rejected', 'decisionSource': 'conditional_auto_approval'},
        <String, dynamic>{},
      ]) {
        expect(adminNotificationEvent(booking), isNull);
      }
    });

    test(
      'kind, appointment ID, and event time each contribute to identity',
      () {
        final events =
            [
                  pending(createdAt: now),
                  pending(id: 'appointment-2', createdAt: now),
                  pending(createdAt: now.add(const Duration(microseconds: 1))),
                  decision(decidedAt: now),
                  decision(approved: false, decidedAt: now),
                ]
                .map(adminNotificationEvent)
                .whereType<AdminNotificationEvent>()
                .toList();

        expect(events.map((event) => event.key).toSet(), hasLength(5));
        expect(
          adminNotificationEvent({
            ...pending(createdAt: now),
            'updatedAt': now.add(const Duration(minutes: 1)),
            'documentReview': {'status': 'completed', 'score': 100},
          })!.key,
          events.first.key,
        );
      },
    );

    test('equivalent timezone representations produce the same key', () {
      final utc = adminNotificationEvent(pending(createdAt: now))!;
      final offset = adminNotificationEvent(
        pending(createdAt: '2026-10-25T17:02:00+08:00'),
      )!;
      expect(offset.key, utc.key);
    });

    test(
      'Timestamp and local DateTime normalize to the same UTC event time',
      () {
        final timestamp = adminNotificationEvent(
          pending(createdAt: Timestamp.fromDate(now)),
        )!;
        final local = adminNotificationEvent(
          pending(createdAt: now.toLocal()),
        )!;

        expect(timestamp.occurredAt, now);
        expect(timestamp.occurredAt!.isUtc, isTrue);
        expect(local.occurredAt, now);
        expect(local.occurredAt!.isUtc, isTrue);
        expect(local.key, timestamp.key);
      },
    );

    test(
      'missing ID keeps historical fallback identity without inventing ID',
      () {
        final event = adminNotificationEvent(pending(id: '', createdAt: now))!;
        expect(event.appointmentId, isEmpty);
        expect(event.legacyReadKey, 'pending:G006:10/25/2026:TEST123');
        expect(
          event.key,
          'pending:G006:10/25/2026:TEST123:${now.microsecondsSinceEpoch}',
        );

        final sparse = adminNotificationEvent({'status': 'Pending'})!;
        expect(sparse.legacyReadKey, 'pending:null:null:null');
      },
    );

    test('legacy read key exactly preserves an existing decision source', () {
      final event = adminNotificationEvent({
        ...pending(createdAt: now),
        'decisionSource': ' conditional_auto_approval ',
      })!;
      expect(event.kind, AdminNotificationEventKind.pending);
      expect(event.key, startsWith('pending:'));
      expect(event.legacyReadKey, 'conditional_auto_approval:appointment-1');
    });

    test(
      'legacy read keys apply to history but not later events on same ID',
      () {
        final historical = adminNotificationEvent(
          pending(createdAt: sessionStart),
        )!;
        final newer = adminNotificationEvent(pending(createdAt: now))!;
        final missingTime = adminNotificationEvent(pending())!;
        final legacyKeys = {historical.legacyReadKey};

        expect(
          historical.isRead(legacyKeys, legacyReadBefore: sessionStart),
          isTrue,
        );
        expect(
          missingTime.isRead(legacyKeys, legacyReadBefore: sessionStart),
          isTrue,
        );
        expect(
          newer.isRead(legacyKeys, legacyReadBefore: sessionStart),
          isFalse,
        );
        expect(
          newer.isRead({newer.key}, legacyReadBefore: sessionStart),
          isTrue,
        );
      },
    );
  });

  group('popup gating', () {
    test('first server snapshot is history even when its events are fresh', () {
      final popupGate = gate();
      final fresh = pending(createdAt: now);
      expect(consider(popupGate, [fresh]), isNull);
      expect(consider(popupGate, [fresh]), isNull);
    });

    test(
      'cache bootstrap and first server snapshot do not generate popups',
      () {
        final popupGate = gate();
        final cached = pending(createdAt: now);
        final serverOnly = pending(id: 'server-only', createdAt: now);

        expect(consider(popupGate, [cached], fromCache: true), isNull);
        expect(consider(popupGate, [cached, serverOnly]), isNull);
        expect(consider(popupGate, [cached, serverOnly]), isNull);
        expect(
          consider(popupGate, [
            pending(id: 'new', createdAt: now),
          ])?.appointmentId,
          'new',
        );
      },
    );

    test(
      'cached history absent from first server snapshot remains consumed',
      () {
        final popupGate = gate();
        final cached = pending(createdAt: now);
        consider(popupGate, [cached], fromCache: true);
        consider(popupGate, []);
        expect(consider(popupGate, [cached]), isNull);
      },
    );

    test(
      'new event pops only after its server confirmation following cache',
      () {
        final popupGate = gate();
        consider(popupGate, []);
        final fresh = pending(createdAt: now);

        expect(consider(popupGate, [fresh], fromCache: true), isNull);
        expect(consider(popupGate, [fresh])?.appointmentId, 'appointment-1');
        expect(consider(popupGate, [fresh]), isNull);
      },
    );

    test(
      'October 2 D002 approval stays silent after October 25 Analyze Again',
      () {
        final popupGate = gate();
        final old = decision(decidedAt: DateTime.utc(2026, 10, 2, 0, 50))
          ..['queue'] = 'D002'
          ..['date'] = '10/2/2026';
        consider(popupGate, [old]);
        expect(
          consider(popupGate, [
            {
              ...old,
              'updatedAt': now,
              'documentReview': {'score': 100, 'status': 'completed'},
            },
          ]),
          isNull,
        );
      },
    );

    test('new appointment today after baseline pops once', () {
      final popupGate = gate();
      consider(popupGate, []);
      final fresh = pending(
        createdAt: sessionStart.add(const Duration(seconds: 1)),
      );
      expect(
        consider(popupGate, [fresh])?.kind,
        AdminNotificationEventKind.pending,
      );
      expect(consider(popupGate, [fresh]), isNull);
    });

    test(
      'approval after pending is a separate event on the same appointment',
      () {
        final popupGate = gate();
        consider(popupGate, [pending(createdAt: sessionStart)]);
        expect(
          consider(popupGate, [decision(decidedAt: now)])?.kind,
          AdminNotificationEventKind.autoApproved,
        );
      },
    );

    test(
      'exact read key or legacy key for a session-start event suppress it',
      () {
        for (final createdAt in [now, sessionStart]) {
          final fresh = pending(createdAt: createdAt);
          final event = adminNotificationEvent(fresh)!;
          final readKey = createdAt == sessionStart
              ? event.legacyReadKey
              : event.key;
          final popupGate = gate();
          consider(popupGate, []);
          expect(consider(popupGate, [fresh], readKeys: {readKey}), isNull);
          expect(consider(popupGate, [fresh]), isNull);
        }
      },
    );

    test(
      'legacy key does not suppress a genuinely new event after session start',
      () {
        final popupGate = gate();
        consider(popupGate, []);
        final fresh = decision(decidedAt: now);
        final event = adminNotificationEvent(fresh)!;
        expect(
          consider(popupGate, [fresh], readKeys: {event.legacyReadKey})?.key,
          event.key,
        );
      },
    );

    test('observed events do not pop later when read state becomes ready', () {
      final popupGate = gate();
      consider(popupGate, []);
      final fresh = pending(createdAt: now);
      expect(consider(popupGate, [fresh], ready: false), isNull);
      expect(consider(popupGate, [fresh], ready: true), isNull);
    });

    test('events before session, missing time, or missing ID do not pop', () {
      final popupGate = gate();
      consider(popupGate, []);
      expect(
        consider(popupGate, [
          pending(
            createdAt: sessionStart.subtract(const Duration(microseconds: 1)),
          ),
          pending(id: 'missing-time'),
          pending(id: '', createdAt: now),
        ]),
        isNull,
      );
      expect(
        consider(popupGate, [
          pending(id: 'at-start', createdAt: sessionStart),
        ])?.appointmentId,
        'at-start',
      );
    });

    test('events more than five minutes old stay silent', () {
      final popupGate = gate();
      final later = sessionStart.add(const Duration(minutes: 10));
      consider(popupGate, [], at: later);
      expect(
        consider(popupGate, [
          pending(
            createdAt: later.subtract(
              const Duration(minutes: 5, microseconds: 1),
            ),
          ),
        ], at: later),
        isNull,
      );
      expect(
        consider(popupGate, [
          pending(
            id: 'boundary',
            createdAt: later.subtract(const Duration(minutes: 5)),
          ),
        ], at: later)?.appointmentId,
        'boundary',
      );
    });

    test(
      'small clock skew is tolerated but future events are not replayed',
      () {
        final popupGate = gate();
        consider(popupGate, []);
        final future = pending(
          createdAt: now.add(const Duration(minutes: 1, microseconds: 1)),
        );
        expect(consider(popupGate, [future]), isNull);
        expect(
          consider(popupGate, [
            future,
          ], at: now.add(const Duration(minutes: 2))),
          isNull,
        );
        expect(
          consider(popupGate, [
            pending(
              id: 'small-skew',
              createdAt: now.add(const Duration(minutes: 1)),
            ),
          ])?.appointmentId,
          'small-skew',
        );
      },
    );

    test(
      'disappearing and reappearing events do not popup after reconnect',
      () {
        final popupGate = gate();
        consider(popupGate, []);
        final fresh = pending(createdAt: now);
        expect(consider(popupGate, [fresh]), isNotNull);
        consider(popupGate, []);
        expect(consider(popupGate, [fresh], fromCache: true), isNull);
        expect(consider(popupGate, [fresh]), isNull);
      },
    );

    test(
      'multiple fresh notifications display only latest and consume all',
      () {
        final popupGate = gate();
        consider(popupGate, []);
        final bookings = [
          pending(
            id: 'older',
            createdAt: now.subtract(const Duration(seconds: 30)),
          ),
          decision(id: 'latest', approved: false, decidedAt: now),
          decision(
            id: 'middle',
            decidedAt: now.subtract(const Duration(seconds: 10)),
          ),
        ];
        final event = consider(popupGate, bookings)!;
        expect(event.appointmentId, 'latest');
        expect(event.kind, AdminNotificationEventKind.autoRejected);
        expect(consider(popupGate, bookings), isNull);
        expect(consider(popupGate, [bookings.first]), isNull);
      },
    );

    test('a read latest event does not hide an eligible unread new event', () {
      final popupGate = gate();
      consider(popupGate, []);
      final newer = decision(id: 'read', decidedAt: now);
      final older = pending(
        id: 'unread',
        createdAt: now.subtract(const Duration(seconds: 1)),
      );
      expect(
        consider(
          popupGate,
          [newer, older],
          readKeys: {adminNotificationEvent(newer)!.key},
        )?.appointmentId,
        'unread',
      );
    });

    test(
      'deferred popup recheck respects remote read state after selection',
      () {
        final popupGate = gate();
        final event = adminNotificationEvent(pending(createdAt: now))!;
        expect(popupGate.hasServerBaseline, isFalse);
        expect(
          popupGate.canPresent(
            event,
            readKeys: {},
            now: now,
            readStateReady: true,
          ),
          isFalse,
        );
        consider(popupGate, []);
        expect(popupGate.hasServerBaseline, isTrue);
        expect(consider(popupGate, [event.appointment])?.key, event.key);
        expect(
          popupGate.canPresent(
            event,
            readKeys: {},
            now: now,
            readStateReady: true,
          ),
          isTrue,
        );
        expect(
          popupGate.canPresent(
            event,
            readKeys: {event.key},
            now: now,
            readStateReady: true,
          ),
          isFalse,
        );
        expect(
          popupGate.canPresent(
            event,
            readKeys: {},
            now: now,
            readStateReady: false,
          ),
          isFalse,
        );
        expect(
          popupGate.canPresent(
            event,
            readKeys: {},
            now: now.add(const Duration(minutes: 6)),
            readStateReady: true,
          ),
          isFalse,
        );
      },
    );
  });
}
