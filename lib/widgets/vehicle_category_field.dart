import 'package:flutter/material.dart' hide Text;

import '../services/app_language.dart';
import '../services/vehicle_category.dart';
import '../theme/app_theme.dart';
import 'localized_text.dart';

/// Both booking and walk-in generation use the same options and validation.
class VehicleCategoryField extends StatelessWidget {
  const VehicleCategoryField({
    super.key,
    required this.formKey,
    required this.category,
    required this.otherController,
    required this.onChanged,
    this.enabled = true,
  });

  final GlobalKey<FormState> formKey;
  final String? category;
  final TextEditingController otherController;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: appText(label),
    prefixIcon: Icon(
      Icons.directions_car_outlined,
      color: AppColors.activePrimary,
    ),
    filled: true,
    fillColor: AppColors.activeBackground,
    errorMaxLines: 2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.activeBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.activePrimary, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            isExpanded: true,
            dropdownColor: AppColors.activeSurface,
            iconEnabledColor: AppColors.activePrimary,
            style: TextStyle(color: AppColors.activePrimary, fontSize: 16),
            decoration: _decoration('Vehicle Category'),
            hint: const Text('Select vehicle category'),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            items: vehicleCategories
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
            validator: (value) {
              final error = value == 'Other'
                  ? null
                  : validateVehicleCategory(value);
              return error == null ? null : appText(error);
            },
          ),
          if (category == 'Other') ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: otherController,
              enabled: enabled,
              maxLength: vehicleCategoryOtherMaxLength,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: AppColors.activePrimary, fontSize: 16),
              decoration: _decoration('Specify vehicle category'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final error = validateVehicleCategory('Other', other: value);
                return error == null ? null : appText(error);
              },
            ),
          ],
        ],
      ),
    );
  }
}
