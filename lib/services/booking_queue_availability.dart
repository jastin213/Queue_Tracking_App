/// A pending appointment holds a code without joining the live queue yet.
enum BookingQueueCodeState { available, pendingApproval, taken }

Map<String, BookingQueueCodeState> appointmentQueueCodeStates(
  Iterable<Map<String, dynamic>> appointments,
) {
  final states = <String, BookingQueueCodeState>{};
  for (final appointment in appointments) {
    final code = appointment['queue']?.toString().trim() ?? '';
    if (code.isEmpty) continue;
    final status = appointment['status']?.toString().trim().toLowerCase();
    if (status == 'approved') {
      states[code] = BookingQueueCodeState.taken;
    } else if (status == 'pending') {
      // Another approved booking for this code must retain its reservation.
      states.putIfAbsent(code, () => BookingQueueCodeState.pendingApproval);
    }
  }
  return states;
}

Set<String> unavailableLiveQueueCodes(
  Iterable<Map<String, dynamic>> queueItems,
) {
  return queueItems
      .where((item) {
        final status = item['status']?.toString().trim().toLowerCase();
        return status != 'cancelled' && status != 'reset';
      })
      .map((item) => item['queue']?.toString().trim() ?? '')
      .where((code) => code.isNotEmpty)
      .toSet();
}
