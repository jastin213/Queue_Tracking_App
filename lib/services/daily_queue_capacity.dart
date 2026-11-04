import 'queue_source.dart';

/// One configured limit shared by Gas and Diesel, divided equally by source.
class DailyQueueCapacityPolicy {
  const DailyQueueCapacityPolicy({this.dailyLimit = 80})
    : assert(dailyLimit >= 20 && dailyLimit <= 150 && dailyLimit % 10 == 0);

  final int dailyLimit;

  int get sourceLimit => dailyLimit ~/ 2;

  static DailyQueueCapacityPolicy? tryParse(Object? value) {
    final limit = value is Map ? value['dailyLimit'] : value;
    if (limit is! num || !limit.isFinite || limit != limit.roundToDouble()) {
      return null;
    }
    final integer = limit.toInt();
    if (integer < 20 || integer > 150 || integer % 10 != 0) return null;
    return DailyQueueCapacityPolicy(dailyLimit: integer);
  }

  static DailyQueueCapacityPolicy fromData(Map<String, dynamic>? data) {
    if (data == null) return const DailyQueueCapacityPolicy();
    final policy = tryParse(data);
    if (policy == null) {
      throw const FormatException('The daily queue limit is invalid.');
    }
    return policy;
  }
}

String _capacityText(Object? value) => value?.toString().trim() ?? '';

String _capacityStatus(Map<String, dynamic> record) =>
    _capacityText(record['status']).toLowerCase();

/// Usage for records from one appointment date; callers filter dates first.
/// Completed services continue to consume their original source's daily quota.
class DailyQueueUsage {
  const DailyQueueUsage({this.appointmentUsed = 0, this.walkInUsed = 0});

  final int appointmentUsed;
  final int walkInUsed;

  int get totalUsed => appointmentUsed + walkInUsed;

  factory DailyQueueUsage.fromRecords({
    required Iterable<Map<String, dynamic>> appointments,
    required Iterable<Map<String, dynamic>> queueItems,
    Map<String, dynamic> completedClaims = const {},
  }) {
    final appointmentIds = <String>{};
    final identifiedAppointmentCodes = <String>{};
    final anonymousAppointmentCodes = <String>{};
    final walkInIds = <String>{};
    var unidentifiedAppointments = 0;
    var unidentifiedWalkIns = 0;

    void addAppointment(Map<String, dynamic> record) {
      var id = _capacityText(record['appointmentId']);
      if (id.isEmpty) {
        id = _capacityText(record['_appointmentDocumentPath']).split('/').last;
      }
      final code = _capacityText(record['queue']);
      if (id.isNotEmpty) {
        appointmentIds.add(id);
        if (code.isNotEmpty) identifiedAppointmentCodes.add(code);
      } else if (code.isNotEmpty) {
        anonymousAppointmentCodes.add(code);
      } else {
        // Unknown legacy identities are counted conservatively, never dropped.
        unidentifiedAppointments++;
      }
    }

    for (final appointment in appointments) {
      final status = _capacityStatus(appointment);
      if (status == 'pending' || status == 'approved') {
        addAppointment(appointment);
      }
    }

    final retainedCompleted = completedClaims.entries
        .where((entry) => entry.value is Map)
        .map((entry) {
          final claim = Map<String, dynamic>.from(entry.value as Map);
          return {
            ...claim,
            'queueId': claim['queueId'] ?? claim['queue'] ?? entry.key,
            'status': 'Passed',
          };
        });
    for (final item in [...queueItems, ...retainedCompleted]) {
      if (const {
        'cancelled',
        'reset',
        'rejected',
        'expired',
      }.contains(_capacityStatus(item))) {
        continue;
      }
      final quotaSource = _capacityText(item['quotaSource']).toLowerCase();
      final isAppointment = quotaSource == 'appointment' ||
          (quotaSource != 'walkin' &&
              normalizedQueueSource(item) == appointmentQueueSource);
      if (isAppointment) {
        addAppointment(item);
      } else {
        final id = _capacityText(item['queueId']);
        final code = _capacityText(item['queue']);
        if (id.isNotEmpty || code.isNotEmpty) {
          walkInIds.add(id.isNotEmpty ? id : code);
        } else {
          unidentifiedWalkIns++;
        }
      }
    }

    return DailyQueueUsage(
      appointmentUsed:
          appointmentIds.length +
          anonymousAppointmentCodes
              .difference(identifiedAppointmentCodes)
              .length +
          unidentifiedAppointments,
      walkInUsed: walkInIds.length + unidentifiedWalkIns,
    );
  }

  int _remaining(int sourceUsed, DailyQueueCapacityPolicy policy) {
    final sourceRemaining = (policy.sourceLimit - sourceUsed)
        .clamp(0, policy.sourceLimit)
        .toInt();
    final combinedRemaining = (policy.dailyLimit - totalUsed)
        .clamp(0, policy.dailyLimit)
        .toInt();
    return sourceRemaining < combinedRemaining
        ? sourceRemaining
        : combinedRemaining;
  }

  int appointmentRemaining(DailyQueueCapacityPolicy policy) =>
      _remaining(appointmentUsed, policy);

  int walkInRemaining(DailyQueueCapacityPolicy policy) =>
      _remaining(walkInUsed, policy);
}
