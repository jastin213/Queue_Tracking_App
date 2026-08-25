import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centers page content and prevents controls from becoming excessively wide
/// on desktop browsers. It has no visual effect on compact phone layouts.
class AppResponsiveContent extends StatelessWidget {
  const AppResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Supplies the horizontal page padding used by both compact and wide layouts.
EdgeInsets appPagePadding(
  BuildContext context, {
  double top = AppSpacing.md,
  double bottom = AppSpacing.xxl,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= AppBreakpoints.medium
      ? AppSpacing.xxl
      : AppSpacing.lg;

  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}
