import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? notificationDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? latestNotificationDate(Iterable<dynamic> values) {
  DateTime? latest;
  for (final value in values) {
    final date = notificationDateTime(value);
    if (date != null && (latest == null || date.isAfter(latest))) {
      latest = date;
    }
  }
  return latest;
}

bool notificationWasReadBy(dynamic value, DateTime? readThrough) {
  if (readThrough == null) return false;
  final date = notificationDateTime(value);
  return date != null && !date.isAfter(readThrough);
}

String formatNotificationTime(dynamic value, {DateTime? now}) {
  final date = notificationDateTime(value);
  if (date == null) return 'Time unavailable';

  final difference = (now ?? DateTime.now()).difference(date);
  if (difference.isNegative || difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference.inDays == 1) return 'Yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';

  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} • $hour:$minute $period';
}

dynamic appointmentDecisionTime(Map<String, dynamic> appointment) {
  final status = appointment['status']?.toString();
  if (status == 'Approved') {
    return appointment['approvedAt'] ??
        appointment['updatedAt'] ??
        appointment['createdAt'];
  }
  if (status == 'Rejected') {
    return appointment['rejectedAt'] ??
        appointment['updatedAt'] ??
        appointment['createdAt'];
  }
  return appointment['createdAt'] ?? appointment['updatedAt'];
}
