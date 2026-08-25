import 'package:cloud_firestore/cloud_firestore.dart';

String normalizePlateForQuery(dynamic value) {
  if (value == null) return '';
  return value.toString().trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]'),
    '',
  );
}

String normalizeNameForQuery(dynamic value) {
  if (value == null) return '';
  return value.toString().trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? dateFromMdy(dynamic value) {
  final parts = value?.toString().split('/') ?? const <String>[];
  if (parts.length != 3) return null;

  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

Map<String, dynamic> firestoreQueryFields({
  required dynamic date,
  required dynamic plate,
  dynamic name,
}) {
  final parsedDate = dateFromMdy(date);
  final normalizedPlate = normalizePlateForQuery(plate);
  final normalizedName = normalizeNameForQuery(name);

  return {
    if (parsedDate != null) 'dateTimestamp': Timestamp.fromDate(parsedDate),
    if (normalizedPlate.isNotEmpty) 'plateNormalized': normalizedPlate,
    if (normalizedName.isNotEmpty) 'nameNormalized': normalizedName,
  };
}
