import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Adds a restrained lift, scale, and shadow response to interactive cards on
/// pointer-based devices. Touch devices keep their existing tap behavior.
class AppHoverLift extends StatefulWidget {
  const AppHoverLift({
    super.key,
    required this.child,
    this.enabled = true,
    this.borderRadius = AppRadii.card,
    this.lift = 3,
    this.scale = 1.006,
  });

  final Widget child;
  final bool enabled;
  final double borderRadius;
  final double lift;
  final double scale;

  @override
  State<AppHoverLift> createState() => _AppHoverLiftState();
}

class _AppHoverLiftState extends State<AppHoverLift> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final hovered = widget.enabled && _hovered && !reduceMotion;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: hovered ? widget.scale : 1,
        duration: AppMotion.quick,
        curve: AppMotion.emphasizedCurve,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.emphasizedCurve,
          transform: Matrix4.translationValues(
            0,
            hovered ? -widget.lift : 0,
            0,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: hovered ? AppEffects.raisedShadow : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Gently calls attention to a live status without flashing or changing the
/// underlying layout.
class AppStatusPulse extends StatefulWidget {
  const AppStatusPulse({
    super.key,
    required this.child,
    required this.active,
    required this.color,
    this.borderRadius = AppRadii.card,
  });

  final Widget child;
  final bool active;
  final Color color;
  final double borderRadius;

  @override
  State<AppStatusPulse> createState() => _AppStatusPulseState();
}

class _AppStatusPulseState extends State<AppStatusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.statusPulse,
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AppStatusPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.active || reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08 + (0.10 * value)),
                blurRadius: 10 + (8 * value),
                spreadRadius: 0.5 + (1.5 * value),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Notification icon with a short one-time bell motion when its unread count
/// increases. The badge itself remains visible until the existing read logic
/// clears it.
class AppNotificationBell extends StatefulWidget {
  const AppNotificationBell({
    super.key,
    required this.count,
    required this.badgeBorderColor,
    this.iconColor,
    this.badgeColor = Colors.red,
  });

  final int count;
  final Color badgeBorderColor;
  final Color? iconColor;
  final Color badgeColor;

  @override
  State<AppNotificationBell> createState() => _AppNotificationBellState();
}

class _AppNotificationBellState extends State<AppNotificationBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.notificationAttention,
    );
    if (widget.count > 0) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AppNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_outlined, color: widget.iconColor),
        if (widget.count > 0)
          Positioned(
            top: -6,
            right: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.badgeColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.badgeBorderColor, width: 1.5),
              ),
              child: Text(
                widget.count > 9 ? '9+' : '${widget.count}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );

    if (reduceMotion) return bell;

    return AnimatedBuilder(
      animation: _controller,
      child: bell,
      builder: (context, child) {
        final progress = _controller.value;
        final rotation =
            math.sin(progress * math.pi * 5) * (1 - progress) * 0.13;
        return Transform.rotate(angle: rotation, child: child);
      },
    );
  }
}

/// Reveals charts smoothly from left to right whenever a chart widget enters
/// the tree or its keyed view changes.
class AppChartReveal extends StatelessWidget {
  const AppChartReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.chartEntrance,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Opacity(opacity: 0.45 + (0.55 * value), child: child),
          ),
        );
      },
    );
  }
}
