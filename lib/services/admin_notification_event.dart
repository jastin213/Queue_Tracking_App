import 'notification_time.dart';

enum AdminNotificationEventKind { pending, autoApproved, autoRejected }

class AdminNotificationEvent {
  const AdminNotificationEvent._({
    required this.key,
    required this.legacyReadKey,
    required this.appointmentId,
    required this.kind,
    required this.occurredAt,
    required this.appointment,
  });

  final String key;
  final String legacyReadKey;
  final String appointmentId;
  final AdminNotificationEventKind kind;
  final DateTime? occurredAt;
  final Map<String, dynamic> appointment;

  bool isRead(Set<String> readKeys, {required DateTime legacyReadBefore}) {
    if (readKeys.contains(key)) return true;
    final time = occurredAt;
    return readKeys.contains(legacyReadKey) &&
        (time == null || !time.isAfter(legacyReadBefore));
  }
}

AdminNotificationEvent? adminNotificationEvent(Map<String, dynamic> booking) {
  final status = booking['status']?.toString().trim();
  final decisionSource = booking['decisionSource']?.toString().trim() ?? '';
  final AdminNotificationEventKind kind;
  final String eventType;
  final dynamic eventTime;

  if (status == 'Pending') {
    kind = AdminNotificationEventKind.pending;
    eventType = 'pending';
    eventTime = booking['createdAt'];
  } else if (status == 'Approved' &&
      decisionSource == 'conditional_auto_approval') {
    kind = AdminNotificationEventKind.autoApproved;
    eventType = 'conditional_auto_approval';
    eventTime = booking['autoDecisionAt'] ?? booking['approvedAt'];
  } else if (status == 'Rejected' &&
      decisionSource == 'conditional_auto_rejection') {
    kind = AdminNotificationEventKind.autoRejected;
    eventType = 'conditional_auto_rejection';
    eventTime = booking['autoDecisionAt'] ?? booking['rejectedAt'];
  } else {
    return null;
  }

  final appointmentId = booking['appointmentId']?.toString().trim() ?? '';
  final identity = appointmentId.isNotEmpty
      ? appointmentId
      : '${booking['queue']}:${booking['date']}:${booking['plate']}';
  final legacyType = decisionSource.isNotEmpty ? decisionSource : 'pending';
  final occurredAt = notificationDateTime(eventTime)?.toUtc();
  final timeKey =
      occurredAt?.toUtc().microsecondsSinceEpoch.toString() ?? 'unknown';

  return AdminNotificationEvent._(
    key: '$eventType:$identity:$timeKey',
    legacyReadKey: '$legacyType:$identity',
    appointmentId: appointmentId,
    kind: kind,
    occurredAt: occurredAt,
    appointment: Map<String, dynamic>.unmodifiable(booking),
  );
}

/// Tracks one notification stream for the lifetime of an admin session.
class AdminNotificationPopupGate {
  AdminNotificationPopupGate({required this.sessionStartedAt});

  final DateTime sessionStartedAt;
  final Set<String> _seenKeys = <String>{};
  bool _hasServerBaseline = false;

  static const _maximumAge = Duration(minutes: 5);
  static const _futureTolerance = Duration(minutes: 1);

  bool get hasServerBaseline => _hasServerBaseline;

  /// Rechecks a selected event immediately before its deferred popup appears.
  /// An event being seen does not mean it has been read by the administrator.
  bool canPresent(
    AdminNotificationEvent event, {
    required Set<String> readKeys,
    required DateTime now,
    required bool readStateReady,
  }) {
    if (!_hasServerBaseline ||
        !readStateReady ||
        event.appointmentId.isEmpty ||
        event.isRead(readKeys, legacyReadBefore: sessionStartedAt)) {
      return false;
    }
    final occurredAt = event.occurredAt;
    return occurredAt != null &&
        !occurredAt.isBefore(sessionStartedAt) &&
        !occurredAt.isAfter(now.add(_futureTolerance)) &&
        now.difference(occurredAt) <= _maximumAge;
  }

  AdminNotificationEvent? consider({
    required Iterable<AdminNotificationEvent> events,
    required bool fromCache,
    required bool readStateReady,
    required Set<String> readKeys,
    required DateTime now,
  }) {
    final snapshot = events.toList(growable: false);

    if (fromCache) {
      // Cached history must not become a new event after reconnecting. Once a
      // server baseline exists, leave unseen cached changes for confirmation by
      // the next server snapshot instead of consuming a real event too early.
      if (!_hasServerBaseline) {
        _seenKeys.addAll(snapshot.map((event) => event.key));
      }
      return null;
    }

    if (!_hasServerBaseline) {
      _hasServerBaseline = true;
      _seenKeys.addAll(snapshot.map((event) => event.key));
      return null;
    }

    AdminNotificationEvent? newest;
    for (final event in snapshot) {
      // Consume every authoritative event even when it cannot show a popup.
      // This avoids a delayed backlog when read state becomes ready later.
      if (!_seenKeys.add(event.key)) continue;
      if (!canPresent(
        event,
        readKeys: readKeys,
        now: now,
        readStateReady: readStateReady,
      )) {
        continue;
      }

      final occurredAt = event.occurredAt!;
      final previousTime = newest?.occurredAt;
      if (previousTime == null ||
          occurredAt.isAfter(previousTime) ||
          (occurredAt.isAtSameMomentAs(previousTime) &&
              event.key.compareTo(newest!.key) > 0)) {
        newest = event;
      }
    }
    return newest;
  }
}
