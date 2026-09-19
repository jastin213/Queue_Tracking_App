import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

const _voiceAlertsKey = 'customer_voice_alerts_enabled';
const _voiceLanguageKey = 'customer_voice_language';
const _remindersKey = 'customer_appointment_reminders_enabled';

final ValueNotifier<bool> customerVoiceAlertsEnabledNotifier = ValueNotifier(
  true,
);
final ValueNotifier<String> customerVoiceLanguageNotifier = ValueNotifier(
  'English',
);
final ValueNotifier<String> customerAppLanguageNotifier = appLanguageNotifier;
final ValueNotifier<bool> customerAppointmentRemindersEnabledNotifier =
    ValueNotifier(true);

Future<void> initializeCustomerPreferences() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    customerVoiceAlertsEnabledNotifier.value =
        preferences.getBool(_voiceAlertsKey) ?? true;
    customerVoiceLanguageNotifier.value =
        preferences.getString(_voiceLanguageKey) ?? 'English';
    customerAppointmentRemindersEnabledNotifier.value =
        preferences.getBool(_remindersKey) ?? true;
  } catch (_) {
    // Defaults remain available when local preferences cannot be read.
  }
}

Future<void> setCustomerVoiceAlertsEnabled(bool value) async {
  customerVoiceAlertsEnabledNotifier.value = value;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_voiceAlertsKey, value);
  } catch (_) {}
}

Future<void> setCustomerVoiceLanguage(String value) async {
  customerVoiceLanguageNotifier.value = value;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_voiceLanguageKey, value);
  } catch (_) {}
}

Future<void> setCustomerAppLanguage(String value) async {
  await setAppLanguage(value);
}

Future<void> setCustomerAppointmentRemindersEnabled(bool value) async {
  customerAppointmentRemindersEnabledNotifier.value = value;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_remindersKey, value);
  } catch (_) {}
}

String customerText(String english, String filipino) {
  return appText(english, filipino);
}
