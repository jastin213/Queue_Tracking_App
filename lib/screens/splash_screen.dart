import 'package:flutter/material.dart' hide Text;

import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoEntrance;
  late final Animation<double> _textEntrance;
  late final Animation<double> _progressEntrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.58, curve: Curves.easeOutBack),
    );
    _textEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.76, curve: Curves.easeOutCubic),
    );
    _progressEntrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 1, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, animation, secondaryAnimation) => const HomePage(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final background = AppColors.activeBackground;
    final surface = AppColors.activeSurface;
    final muted = AppColors.activeMutedText;
    final soft = AppColors.activeSoftPrimary;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -125,
            right: -90,
            child: _SplashOrb(
              size: 310,
              color: primary.withValues(alpha: 0.075),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -125,
            child: _SplashOrb(size: 360, color: soft.withValues(alpha: 0.72)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final logoValue = disableAnimations
                          ? 1.0
                          : _logoEntrance.value;
                      final textValue = disableAnimations
                          ? 1.0
                          : _textEntrance.value;
                      final progressValue = disableAnimations
                          ? 1.0
                          : _progressEntrance.value;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: logoValue.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - logoValue)),
                              child: Transform.scale(
                                scale: 0.72 + (0.28 * logoValue),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.scale(
                                      scale: 0.84 + (0.22 * logoValue),
                                      child: Container(
                                        width: 172,
                                        height: 172,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: primary.withValues(
                                            alpha: 0.07 * (1 - logoValue),
                                          ),
                                          border: Border.all(
                                            color: primary.withValues(
                                              alpha: 0.14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 132,
                                      height: 132,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: surface,
                                        borderRadius: BorderRadius.circular(36),
                                        border: Border.all(
                                          color: AppColors.activeBorder,
                                        ),
                                        boxShadow: AppEffects.raisedShadow,
                                      ),
                                      child: Image.asset(
                                        'assets/branding/vehicle_queue_logo_v2.png',
                                        fit: BoxFit.contain,
                                        semanticLabel:
                                            'NPJN vehicle queue system logo',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Opacity(
                            opacity: textValue.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - textValue)),
                              child: Column(
                                children: [
                                  Text(
                                    'NPJN Queue',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 30,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    'Smart Queue Management',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Fast. Clear. Convenient.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: muted.withValues(alpha: 0.82),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          Opacity(
                            opacity: progressValue.clamp(0.0, 1.0),
                            child: Column(
                              children: [
                                Container(
                                  width: 220,
                                  height: 5,
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: soft,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: progressValue.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Preparing your queue experience',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  const _SplashOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
