import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String rememberedLoginPreferenceKey = 'remember_login_session_v1';

/// Stores only the user's Remember Me choice. Firebase Authentication keeps
/// the secure session token; this app never stores the account password.
Future<bool> isRememberedLoginEnabled() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(rememberedLoginPreferenceKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> saveRememberedLoginPreference(bool remember) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(rememberedLoginPreferenceKey, remember);
  } catch (_) {
    // A local preference failure must never turn a successful Firebase sign-in
    // into a login failure. Firebase still keeps the active session secure;
    // the next launch simply falls back to requiring sign-in again.
  }
}

Future<void> clearRememberedLoginPreference() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(rememberedLoginPreferenceKey);
  } catch (_) {
    // Firebase sign-out below still protects the account if preferences are
    // temporarily unavailable.
  }
}

/// Web supports explicit LOCAL and SESSION persistence. On Android/iOS,
/// Firebase stores its token in the platform's protected authentication
/// storage; the startup gate uses the preference above to decide whether that
/// token may be reused.
Future<void> configureLoginPersistence({required bool remember}) async {
  if (!kIsWeb) return;
  await FirebaseAuth.instance.setPersistence(
    remember ? Persistence.LOCAL : Persistence.SESSION,
  );
}

Future<void> prepareLoginSession({required bool remember}) async {
  // Clearing a previous opt-in before an unremembered login is the secure
  // default, even if the following sign-in attempt does not finish.
  if (!remember) {
    await saveRememberedLoginPreference(false);
  }
  await configureLoginPersistence(remember: remember);
}

Future<void> signOutAndClearRememberedLogin() async {
  await clearRememberedLoginPreference();
  await FirebaseAuth.instance.signOut();
}
