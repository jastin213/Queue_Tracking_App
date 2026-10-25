import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/admin_notification_read_state.dart';

void main() {
  group('mergeAdminNotificationReadKeys', () {
    test('normalizes nonempty strings and removes duplicate keys', () {
      expect(
        mergeAdminNotificationReadKeys(
          [' pending:old ', '', ' \n\t ', 'pending:shared'],
          ['pending:shared', ' pending:new ', 'pending:new', null, ''],
        ),
        {'pending:old', 'pending:shared', 'pending:new'},
      );
    });

    test('malformed stored values never replace existing history', () {
      for (final stored in <Object?>[
        null,
        123,
        true,
        'pending:not-an-array',
        {'pending:map-key': true},
      ]) {
        expect(
          mergeAdminNotificationReadKeys([' pending:retained '], stored),
          {'pending:retained'},
          reason: 'Unexpected stored shape: $stored',
        );
      }
    });

    test('ignores nonstrings without converting them into false read keys', () {
      expect(
        mergeAdminNotificationReadKeys(const [], [
          ' pending:valid ',
          123,
          9.5,
          true,
          null,
          {'key': 'pending:map'},
          ['pending:nested'],
          StringBuffer('pending:string-buffer'),
        ]),
        {'pending:valid'},
      );
    });

    test('retains shared legacy and separate per-event identities', () {
      const legacy = 'conditional_auto_approval:appointment-1';
      const firstEvent = '$legacy:1000';
      const secondEvent = '$legacy:2000';
      expect(
        mergeAdminNotificationReadKeys(
          [legacy, firstEvent],
          [legacy, secondEvent],
        ),
        {legacy, firstEvent, secondEvent},
      );
    });

    test('does not prune unknown keys or historical records', () {
      final history = List<String>.generate(
        1000,
        (index) => 'unknown-old-format:$index',
      );
      final merged = mergeAdminNotificationReadKeys(history, [
        'pending:recent',
      ]);

      expect(merged, hasLength(1001));
      expect(merged, containsAll(history));
      expect(merged, contains('pending:recent'));
    });

    test('concurrent local and cloud reads merge monotonically', () {
      final local = mergeAdminNotificationReadKeys(
        ['pending:previous'],
        ['pending:read-on-this-device'],
      );
      final combined = mergeAdminNotificationReadKeys(local, [
        'pending:previous',
        'pending:read-on-another-device',
      ]);

      expect(combined, {
        'pending:previous',
        'pending:read-on-this-device',
        'pending:read-on-another-device',
      });
      expect(
        mergeAdminNotificationReadKeys(combined, ['pending:previous']),
        combined,
      );
      expect(
        adminNotificationReadKeysToSync(
          local: combined,
          cloud: ['pending:previous', 'pending:read-on-another-device'],
        ),
        ['pending:read-on-this-device'],
      );
    });

    test('does not mutate either input and always returns a fresh set', () {
      final existing = <String>{' pending:local '};
      final stored = <String>[' pending:cloud '];
      final merged = mergeAdminNotificationReadKeys(existing, stored);

      expect(existing, {' pending:local '});
      expect(stored, [' pending:cloud ']);
      expect(identical(merged, existing), isFalse);
      merged.add('pending:after-merge');
      expect(existing, {' pending:local '});
      expect(stored, [' pending:cloud ']);
    });

    test('empty inputs return an empty independently mutable set', () {
      final first = mergeAdminNotificationReadKeys(const [], const []);
      final second = mergeAdminNotificationReadKeys(const [], const []);
      first.add('pending:one');
      expect(second, isEmpty);
      expect(first, {'pending:one'});
    });
  });

  group('adminNotificationReadKeysToSync', () {
    test('returns a normalized, deduplicated, sorted difference', () {
      final local = [' pending:z ', 'pending:b', 'pending:a', 'pending:b', ''];
      final cloud = [' pending:b ', null, 123, 'pending:cloud-only'];

      expect(adminNotificationReadKeysToSync(local: local, cloud: cloud), [
        'pending:a',
        'pending:z',
      ]);
      expect(local, [' pending:z ', 'pending:b', 'pending:a', 'pending:b', '']);
      expect(cloud, [' pending:b ', null, 123, 'pending:cloud-only']);
    });

    test('malformed cloud history cannot silently acknowledge local keys', () {
      for (final cloud in <Object?>[
        null,
        123,
        'pending:local',
        {'pending:local': true},
        [
          false,
          null,
          42,
          ['pending:local'],
        ],
      ]) {
        expect(
          adminNotificationReadKeysToSync(
            local: [' pending:local '],
            cloud: cloud,
          ),
          ['pending:local'],
        );
      }
    });

    test('keeps historical and per-event keys in a sync difference', () {
      expect(
        adminNotificationReadKeysToSync(
          local: [
            'unknown-old-format:old',
            'pending:appointment-1',
            'pending:appointment-1:1000',
            'pending:appointment-1:2000',
          ],
          cloud: ['pending:appointment-1', 'pending:appointment-1:1000'],
        ),
        ['pending:appointment-1:2000', 'unknown-old-format:old'],
      );
    });

    test('returns no writes when cloud already includes every local key', () {
      expect(
        adminNotificationReadKeysToSync(
          local: ['pending:local'],
          cloud: ['pending:local', 'pending:cloud-only'],
        ),
        isEmpty,
      );
      expect(
        adminNotificationReadKeysToSync(
          local: const [],
          cloud: ['pending:cloud-only'],
        ),
        isEmpty,
      );
    });
  });
}
