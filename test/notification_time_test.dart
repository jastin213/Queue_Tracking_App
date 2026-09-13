import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/notification_time.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);

  test('formats recent notification times', () {
    expect(
      formatNotificationTime(
        now.subtract(const Duration(seconds: 20)),
        now: now,
      ),
      'Just now',
    );
    expect(
      formatNotificationTime(
        now.subtract(const Duration(minutes: 8)),
        now: now,
      ),
      '8 min ago',
    );
    expect(
      formatNotificationTime(now.subtract(const Duration(hours: 2)), now: now),
      '2 hours ago',
    );
  });

  test('accepts Firestore timestamps', () {
    final timestamp = Timestamp.fromDate(now.subtract(const Duration(days: 1)));
    expect(formatNotificationTime(timestamp, now: now), 'Yesterday');
  });

  test('uses the appropriate appointment decision timestamp', () {
    final approvedAt = Timestamp.fromDate(now);
    expect(
      appointmentDecisionTime({'status': 'Approved', 'approvedAt': approvedAt}),
      approvedAt,
    );
  });

  test('tracks notifications read through a saved timestamp', () {
    final readThrough = DateTime(2026, 9, 10, 10, 0);

    expect(
      notificationWasReadBy(DateTime(2026, 9, 10, 9, 59), readThrough),
      isTrue,
    );
    expect(
      notificationWasReadBy(DateTime(2026, 9, 10, 10, 1), readThrough),
      isFalse,
    );
  });

  test('finds the latest notification timestamp', () {
    expect(
      latestNotificationDate([
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 8),
      ]),
      DateTime(2026, 9, 10),
    );
  });
}
