import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/appointment_lifecycle.dart';

void main() {
  group('appointment lifecycle', () {
    test('parses the app appointment date format', () {
      final parsed = parseAppointmentDate('8/31/2026');

      expect(parsed, DateTime(2026, 8, 31));
    });

    test('identifies only pending appointments before today as overdue', () {
      final now = DateTime(2026, 9, 8, 14, 30);

      expect(
        isPastPendingAppointment({
          'status': 'Pending',
          'date': '9/7/2026',
        }, now: now),
        isTrue,
      );
      expect(
        isPastPendingAppointment({
          'status': 'Pending',
          'date': '9/8/2026',
        }, now: now),
        isFalse,
      );
      expect(
        isPastPendingAppointment({
          'status': 'Approved',
          'date': '9/7/2026',
        }, now: now),
        isFalse,
      );
    });

    test('does not expire an invalid or missing date', () {
      final now = DateTime(2026, 9, 8);

      expect(isPastAppointmentDate('not-a-date', now: now), isFalse);
      expect(isPastAppointmentDate(null, now: now), isFalse);
    });
  });
}
