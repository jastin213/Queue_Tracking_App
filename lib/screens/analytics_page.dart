import 'package:flutter/material.dart' hide Text;

import 'daily_report.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({
    super.key,
    this.onNavigationPressed,
    this.navigationIcon = Icons.menu_rounded,
  });

  final VoidCallback? onNavigationPressed;
  final IconData navigationIcon;

  @override
  Widget build(BuildContext context) {
    return DailyReport(
      analyticsOnly: true,
      onNavigationPressed: onNavigationPressed,
      navigationIcon: navigationIcon,
    );
  }
}
