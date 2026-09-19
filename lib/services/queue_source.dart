const String appointmentQueueSource = 'Appointment';
const String walkInQueueSource = 'Walk-in';

/// Returns the customer's actual entry source, never a temporary queue status.
///
/// Older records used `Skipped / No Show` as their source when a customer was
/// moved to the bottom of the queue. Appointment references are used to repair
/// those records when they are displayed in reports.
String normalizedQueueSource(Map<String, dynamic> record) {
  final source = record['source']?.toString().trim() ?? '';
  final originalSource = record['originalSource']?.toString().trim() ?? '';
  final appointmentId = record['appointmentId']?.toString().trim() ?? '';
  final appointmentPath =
      record['_appointmentDocumentPath']?.toString().trim() ?? '';

  final sourceValues = [
    originalSource,
    source,
  ].map((value) => value.toLowerCase()).where((value) => value.isNotEmpty);

  if (appointmentId.isNotEmpty ||
      appointmentPath.isNotEmpty ||
      sourceValues.any((value) => value.contains('appointment'))) {
    return appointmentQueueSource;
  }

  return walkInQueueSource;
}
