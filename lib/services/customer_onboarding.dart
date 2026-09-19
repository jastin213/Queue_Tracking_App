import 'package:shared_preferences/shared_preferences.dart';

const String _customerOnboardingVersion = 'v1';
const String _completionKey =
    'customer_onboarding_${_customerOnboardingVersion}_complete';

Future<bool> hasCompletedCustomerOnboarding() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completionKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> completeCustomerOnboarding() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completionKey, true);
  } catch (_) {
    // Completion still continues when local device storage is unavailable.
  }
}
