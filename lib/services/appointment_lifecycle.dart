import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'daily_queue_capacity_service.dart';

final Set<String> _appointmentIdsBeingExpired = <String>{};

DateTime? parseAppointmentDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;

  final slashParts = text.split('/');
  if (slashParts.length == 3) {
    final month = int.tryParse(slashParts[0]);
    final day = int.tryParse(slashParts[1]);
    final year = int.tryParse(slashParts[2]);
    if (month != null && day != null && year != null) {
      final parsed = DateTime(year, month, day);
      if (parsed.year == year && parsed.month == month && parsed.day == day) {
        return parsed;
      }
    }
  }

  return DateTime.tryParse(text);
}

bool isPastAppointmentDate(Object? value, {DateTime? now}) {
  final appointmentDate = parseAppointmentDate(value);
  if (appointmentDate == null) return false;

  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final dateOnly = DateTime(
    appointmentDate.year,
    appointmentDate.month,
    appointmentDate.day,
  );
  return dateOnly.isBefore(today);
}

bool isPastPendingAppointment(
  Map<String, dynamic> appointment, {
  DateTime? now,
}) {
  final status = appointment['status']?.toString().trim().toLowerCase() ?? '';
  return status == 'pending' &&
      isPastAppointmentDate(appointment['date'], now: now);
}

/// Expires overdue pending appointments together with their capacity claims.
///
/// The appointment record is intentionally preserved for audit/report history;
/// only its active Pending state is removed.
Future<int> expirePastPendingAppointmentDocuments(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
  DateTime? now,
}) async {
  final expiredDocuments = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  for (final document in documents) {
    if (!isPastPendingAppointment(document.data(), now: now)) continue;
    if (_appointmentIdsBeingExpired.add(document.id)) {
      expiredDocuments.add(document);
    }
  }

  if (expiredDocuments.isEmpty) return 0;

  try {
    var expiredCount = 0;
    for (final document in expiredDocuments) {
      final expired = await DailyQueueCapacityService.runDayTransaction<bool>(
        document.data()['date']?.toString() ?? '',
        (transaction, day) async {
          final snapshot = await transaction.get(document.reference);
          final current = snapshot.data();
          if (current == null || !isPastPendingAppointment(current, now: now)) {
            return false;
          }
          day.releaseAppointment(
            document.id,
            current['queue']?.toString() ?? '',
          );
          transaction.update(document.reference, {
            'status': 'Expired',
            'expiredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        },
      );
      if (expired) expiredCount++;
    }
    return expiredCount;
  } catch (error) {
    debugPrint('Unable to expire overdue appointments: $error');
    rethrow;
  } finally {
    _appointmentIdsBeingExpired.removeAll(
      expiredDocuments.map((document) => document.id),
    );
  }
}
