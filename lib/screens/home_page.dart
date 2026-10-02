import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../services/customer_onboarding.dart';
import '../services/remembered_login.dart';
import '../theme/app_theme.dart';
import 'admin_page.dart';
import 'customer_home.dart';
import 'customer_login.dart';
import 'customer_onboarding.dart';
import 'customer_register.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Widget> _initialPage;

  @override
  void initState() {
    super.initState();
    _initialPage = _resolveInitialPage();
  }

  Future<Widget> _resolveInitialPage() async {
    if (!await hasCompletedCustomerOnboarding()) {
      return const CustomerOnboarding();
    }

    final rememberLogin = await isRememberedLoginEnabled();
    if (!rememberLogin) {
      // Native Firebase may retain a secure token between launches. A user who
      // did not opt in must not silently reuse it when the app starts again.
      try {
        await configureLoginPersistence(remember: false);
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
      } catch (_) {
        // Firebase is unavailable only in isolated tests or during a startup
        // failure. The login page remains the safe destination.
      }
      _clearCustomerSessionValues();
      return const CustomerLogin();
    }

    try {
      await configureLoginPersistence(remember: true);

      User? user = await FirebaseAuth.instance.authStateChanges().first;
      if (user == null) return _forgetSessionAndShowLogin();

      // Refreshing verifies that Firebase still recognizes the account and
      // that its secure token has not been revoked or expired.
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user == null) return _forgetSessionAndShowLogin();
      await user.getIdToken(true);

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final data = profile.data();
      if (data == null) return _forgetSessionAndShowLogin();

      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      if (role == 'admin') {
        return const AdminPage();
      }

      if ((role == 'customer' || role == 'user') && user.emailVerified) {
        loggedInCustomerNameNotifier.value =
            (data['fullName'] ?? user.displayName ?? '').toString();
        loggedInCustomerEmailNotifier.value =
            (data['email'] ?? user.email ?? '').toString();
        loggedInCustomerIdNotifier.value = user.uid;
        return const CustomerHome();
      }

      return _forgetSessionAndShowLogin();
    } catch (_) {
      return _forgetSessionAndShowLogin();
    }
  }

  Future<Widget> _forgetSessionAndShowLogin() async {
    try {
      await signOutAndClearRememberedLogin();
    } catch (_) {
      await clearRememberedLoginPreference();
    }
    _clearCustomerSessionValues();
    return const CustomerLogin();
  }

  void _clearCustomerSessionValues() {
    loggedInCustomerNameNotifier.value = '';
    loggedInCustomerEmailNotifier.value = '';
    loggedInCustomerIdNotifier.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialPage,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.activeBackground,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.activePrimary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        return snapshot.data ?? const CustomerLogin();
      },
    );
  }
}
