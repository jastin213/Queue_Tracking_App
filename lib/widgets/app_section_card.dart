import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard card used to group related controls or information throughout the
/// app. The optional header keeps section hierarchy consistent on phone and
/// web layouts.
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.showShadow = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || icon != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.activeSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.activeBorder),
        boxShadow: showShadow ? AppEffects.raisedShadow : AppEffects.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.activeSoftPrimary,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: Border.all(color: AppColors.activeBorder),
                    ),
                    child: Icon(icon, color: AppColors.activePrimary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            color: AppColors.activePrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: AppColors.activeMutedText,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}
