import 'package:flutter/material.dart' hide Text;

import '../services/customer_onboarding.dart';
import '../theme/app_theme.dart';
import 'customer_login.dart';
import 'customer_onboarding.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<bool> _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _onboardingCompleted = hasCompletedCustomerOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingCompleted,
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

        return snapshot.data == true
            ? const CustomerLogin()
            : const CustomerOnboarding();
      },
    );
  }
}
