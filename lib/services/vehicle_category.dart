const List<String> vehicleCategories = [
  'Motorcycle',
  'Motorcycle with Sidecar/Tricycle',
  'Car/Sedan',
  'SUV/AUV',
  'Van',
  'Pickup',
  'Jeepney',
  'Truck',
  'Bus',
  'Other',
];

const int vehicleCategoryOtherMaxLength = 60;

String _categoryText(Object? value) =>
    value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

String? validateVehicleCategory(String? category, {String? other}) {
  if (!vehicleCategories.contains(category)) {
    return 'Please select a vehicle category.';
  }
  if (category == 'Other') {
    final description = _categoryText(other);
    if (description.isEmpty) return 'Please specify the vehicle category.';
    if (description.length > vehicleCategoryOtherMaxLength) {
      return 'Use at most 60 characters for the vehicle category.';
    }
  }
  return null;
}

Map<String, dynamic> vehicleCategoryFields({
  required String category,
  String? other,
}) {
  final error = validateVehicleCategory(category, other: other);
  if (error != null) throw ArgumentError(error);
  return {
    'vehicleCategory': category,
    'vehicleCategoryOther': category == 'Other' ? _categoryText(other) : '',
  };
}

/// Existing records may predate category collection; keep them readable.
String vehicleCategoryLabel(Map<String, dynamic> record) {
  final category = _categoryText(record['vehicleCategory']);
  if (category.isEmpty) return 'Not specified';
  final other = _categoryText(record['vehicleCategoryOther']);
  return category == 'Other' && other.isNotEmpty ? 'Other: $other' : category;
}
