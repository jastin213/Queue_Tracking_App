import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/queue_source.dart';

void main() {
  test('keeps walk-in as the report source after a customer is skipped', () {
    expect(
      normalizedQueueSource({
        'source': 'Skipped / No Show',
        'status': 'Passed',
      }),
      walkInQueueSource,
    );
  });

  test('recovers appointment source from an old skipped queue record', () {
    expect(
      normalizedQueueSource({
        'source': 'Skipped / No Show',
        'appointmentId': 'appointment-123',
        'status': 'Passed',
      }),
      appointmentQueueSource,
    );
  });

  test('prefers the preserved original source', () {
    expect(
      normalizedQueueSource({
        'source': 'Skipped / No Show',
        'originalSource': 'Appointment',
        'status': 'Failed',
      }),
      appointmentQueueSource,
    );
  });
}
