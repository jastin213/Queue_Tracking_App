import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../services/customer_onboarding.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';
import 'customer_login.dart';

class CustomerOnboarding extends StatefulWidget {
  const CustomerOnboarding({super.key});

  @override
  State<CustomerOnboarding> createState() => _CustomerOnboardingState();
}

class _CustomerOnboardingState extends State<CustomerOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isFinishing = false;

  static const _pages = <_OnboardingContent>[
    _OnboardingContent(
      title: 'Track Your Queue in Real Time',
      description:
          'Know your current queue position, estimated waiting time, and when your turn is getting close.',
      illustration: _OnboardingIllustration.queue,
    ),
    _OnboardingContent(
      title: 'Book Ahead, Wait Less',
      description:
          'Schedule your emission testing appointment and receive your queue number once your booking is approved.',
      illustration: _OnboardingIllustration.appointment,
    ),
    _OnboardingContent(
      title: 'Get Ready at the Right Time',
      description:
          'Receive alerts when your turn is approaching and get estimated travel-time guidance before leaving.',
      illustration: _OnboardingIllustration.alert,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await completeCustomerOnboarding();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerLogin()),
    );
  }

  Future<void> _nextPage() async {
    if (_currentPage == _pages.length - 1) {
      await _finishOnboarding();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final surface = AppColors.activeSurface;
    final muted = AppColors.activeMutedText;
    final border = AppColors.activeBorder;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.activeBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: AppEffects.cardShadow,
                        ),
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NPJN Queue',
                              style: TextStyle(
                                color: primary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              'Emission Testing Center',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: AppMotion.standard,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Text(
                          '${_currentPage + 1}/${_pages.length}',
                          key: ValueKey(_currentPage),
                          style: TextStyle(
                            color: muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _pages.length,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, index) => _OnboardingSlide(
                      content: _pages[index],
                      active: index == _currentPage,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: AppMotion.standard,
                        curve: AppMotion.emphasizedCurve,
                        width: index == _currentPage ? 28 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? primary
                              : border.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border(top: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        height: 50,
                        child: TextButton(
                          onPressed: _isFinishing ? null : _finishOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: muted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedScale(
                        scale: isLastPage ? 1.035 : 1,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        child: SizedBox(
                          width: 158,
                          height: 50,
                          child: FilledButton(
                            onPressed: _isFinishing ? null : _nextPage,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: primary.withValues(alpha: 0.22),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: AppMotion.quick,
                              child: _isFinishing
                                  ? const SizedBox(
                                      key: ValueKey('loading'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : FittedBox(
                                      key: ValueKey(isLastPage),
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isLastPage ? 'Get Started' : 'Next',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          Icon(
                                            isLastPage
                                                ? Icons.check_rounded
                                                : Icons.arrow_forward_rounded,
                                            size: 19,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OnboardingIllustration { queue, appointment, alert }

class _OnboardingContent {
  const _OnboardingContent({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final _OnboardingIllustration illustration;
}

class _OnboardingSlide extends StatefulWidget {
  const _OnboardingSlide({required this.content, required this.active});

  final _OnboardingContent content;
  final bool active;

  @override
  State<_OnboardingSlide> createState() => _OnboardingSlideState();
}

class _OnboardingSlideState extends State<_OnboardingSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _illustrationEntrance;
  late final Animation<double> _titleEntrance;
  late final Animation<double> _descriptionEntrance;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _illustrationEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.72, curve: Curves.easeOutBack),
    );
    _titleEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.22, 0.82, curve: Curves.easeOutCubic),
    );
    _descriptionEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.38, 1, curve: Curves.easeOutCubic),
    );
    if (widget.active) _entranceController.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _entranceController.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _entranceController.animateBack(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInCubic,
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final muted = AppColors.activeMutedText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight = math.min(
          330.0,
          math.max(220.0, constraints.maxHeight * 0.61),
        );

        return AnimatedBuilder(
          animation: _entranceController,
          builder: (context, child) {
            final illustrationValue = _illustrationEntrance.value;
            final titleValue = _titleEntrance.value;
            final descriptionValue = _descriptionEntrance.value;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: (0.28 + (illustrationValue * 0.72)).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Transform.translate(
                        offset: Offset(0, 28 * (1 - illustrationValue)),
                        child: Transform.rotate(
                          angle:
                              math.sin(_entranceController.value * math.pi) *
                              0.012,
                          child: Transform.scale(
                            scale: 0.9 + (illustrationValue * 0.1),
                            child: SizedBox(
                              height: illustrationHeight,
                              width: double.infinity,
                              child: _IllustrationFrame(
                                type: widget.content.illustration,
                                active: widget.active,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: titleValue.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - titleValue)),
                        child: Text(
                          widget.content.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primary,
                            fontSize: 25,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Opacity(
                      opacity: descriptionValue.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - descriptionValue)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 470),
                          child: Text(
                            widget.content.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IllustrationFrame extends StatefulWidget {
  const _IllustrationFrame({required this.type, required this.active});

  final _OnboardingIllustration type;
  final bool active;

  @override
  State<_IllustrationFrame> createState() => _IllustrationFrameState();
}

class _IllustrationFrameState extends State<_IllustrationFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _liveController;

  @override
  void initState() {
    super.initState();
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLiveMotion();
  }

  @override
  void didUpdateWidget(covariant _IllustrationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _syncLiveMotion();
  }

  void _syncLiveMotion() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.active && !reduceMotion) {
      if (!_liveController.isAnimating) _liveController.repeat();
      return;
    }

    _liveController.stop();
    _liveController.value = 0;
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final soft = AppColors.activeSoftPrimary;
    final surface = AppColors.activeSurface;
    final border = AppColors.activeBorder;

    return Semantics(
      image: true,
      label: switch (widget.type) {
        _OnboardingIllustration.queue =>
          'Phone showing a live queue number and progress',
        _OnboardingIllustration.appointment =>
          'Calendar, vehicle, confirmation, and queue ticket',
        _OnboardingIllustration.alert =>
          'Notification, travel route, vehicle, and queue status',
      },
      child: AnimatedBuilder(
        animation: _liveController,
        builder: (context, child) {
          final motion = _liveController.value;
          final phase = motion * math.pi * 2;
          final wave = math.sin(phase);
          final pulse = (wave + 1) / 2;

          return Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: border),
              boxShadow: AppEffects.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(29),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -55 + (wave * 5),
                    right: -35 + (wave * 3),
                    child: Transform.scale(
                      scale: 0.98 + (pulse * 0.04),
                      child: _SoftCircle(size: 165, color: soft),
                    ),
                  ),
                  Positioned(
                    bottom: -72 - (wave * 4),
                    left: -48 - (wave * 3),
                    child: _SoftCircle(
                      size: 190,
                      color: primary.withValues(alpha: 0.055),
                    ),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: 0.9 + (pulse * 0.12),
                      child: Container(
                        width: 230,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(
                            alpha: 0.025 + (pulse * 0.025),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 24 + (wave * 3),
                    left: 28,
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: primary.withValues(alpha: 0.12 + (pulse * 0.1)),
                    ),
                  ),
                  Positioned(
                    bottom: 30 - (wave * 3),
                    right: 30,
                    child: Transform.rotate(
                      angle: wave * 0.1,
                      child: Icon(
                        Icons.circle_outlined,
                        size: 20,
                        color: primary.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Transform.translate(
                      offset: Offset(0, wave * -4),
                      child: Transform.rotate(
                        angle: wave * 0.004,
                        child: Transform.scale(
                          scale: 0.995 + (pulse * 0.01),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 300,
                              height: 260,
                              child: switch (widget.type) {
                                _OnboardingIllustration.queue =>
                                  _QueueIllustration(motion: motion),
                                _OnboardingIllustration.appointment =>
                                  _AppointmentIllustration(motion: motion),
                                _OnboardingIllustration.alert =>
                                  _AlertIllustration(motion: motion),
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

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

class _QueueIllustration extends StatelessWidget {
  const _QueueIllustration({required this.motion});

  final double motion;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final surface = AppColors.activeSurface;
    final border = AppColors.activeBorder;
    final soft = AppColors.activeSoftPrimary;
    final phase = motion * math.pi * 2;
    final wave = math.sin(phase);
    final pulse = (wave + 1) / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 164,
          height: 245,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(27),
            boxShadow: AppEffects.raisedShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'YOUR QUEUE',
                                maxLines: 1,
                                style: TextStyle(
                                  color: AppColors.activeMutedText,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Transform.scale(
                            scale: 0.96 + (pulse * 0.08),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.1 + (pulse * 0.08),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'A12',
                        style: TextStyle(
                          color: primary,
                          fontSize: 43,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Now Serving A8',
                        style: TextStyle(
                          color: AppColors.activeMutedText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 13),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: 0.64 + (pulse * 0.06),
                          minHeight: 7,
                          backgroundColor: soft,
                          valueColor: AlwaysStoppedAnimation(primary),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: primary,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'About 20 minutes',
                                maxLines: 1,
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 28,
          right: 7,
          child: Transform.translate(
            offset: Offset(wave * 2, wave * -3),
            child: _FloatingInfoCard(
              icon: Icons.format_list_numbered_rounded,
              label: '4 IN LINE',
              color: primary,
            ),
          ),
        ),
        Positioned(
          left: 5,
          bottom: 34,
          child: Transform.translate(
            offset: Offset(wave * 4, wave * 2),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: surface,
                shape: BoxShape.circle,
                border: Border.all(color: border),
                boxShadow: AppEffects.cardShadow,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                color: primary,
                size: 31,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentIllustration extends StatelessWidget {
  const _AppointmentIllustration({required this.motion});

  final double motion;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final surface = AppColors.activeSurface;
    final border = AppColors.activeBorder;
    final phase = motion * math.pi * 2;
    final wave = math.sin(phase);
    final pulse = (wave + 1) / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 232,
          height: 210,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: AppEffects.raisedShadow,
          ),
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(23),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.white),
                    SizedBox(width: 9),
                    Text(
                      'APPOINTMENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.activeSoftPrimary,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SEP',
                              style: TextStyle(
                                color: AppColors.activeMutedText,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '24',
                              style: TextStyle(
                                color: primary,
                                fontSize: 31,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Confirmed',
                              style: TextStyle(
                                color: primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '10:30 AM · Gas',
                              style: TextStyle(
                                color: AppColors.activeMutedText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.94 + (pulse * 0.12),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Booking approved',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 1,
          bottom: 15,
          child: Transform.translate(
            offset: Offset(wave * 2, wave * -3),
            child: Transform.scale(
              scale: 0.98 + (pulse * 0.04),
              child: Container(
                width: 84,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: AppEffects.cardShadow,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QUEUE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'G014',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 8,
          child: Transform.translate(
            offset: Offset(wave * 5, wave * 1.5),
            child: Container(
              width: 72,
              height: 54,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: border),
                boxShadow: AppEffects.cardShadow,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                color: primary,
                size: 34,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertIllustration extends StatelessWidget {
  const _AlertIllustration({required this.motion});

  final double motion;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.activePrimary;
    final surface = AppColors.activeSurface;
    final border = AppColors.activeBorder;
    final phase = motion * math.pi * 2;
    final wave = math.sin(phase);
    final pulse = (wave + 1) / 2;
    final bellSwing = math.sin(phase * 2) * 0.075;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 238,
          height: 185,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: AppEffects.raisedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TRAVEL GUIDANCE',
                    style: TextStyle(
                      color: AppColors.activeMutedText,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Transform.rotate(
                    angle: wave * 0.04,
                    child: Icon(Icons.route_rounded, color: primary, size: 20),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _RoutePoint(icon: Icons.home_rounded, color: primary),
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: CustomPaint(
                        painter: _DottedRoutePainter(
                          color: primary,
                          motion: motion,
                        ),
                      ),
                    ),
                  ),
                  const _RoutePoint(
                    icon: Icons.flag_rounded,
                    color: AppColors.success,
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.activeSoftPrimary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: primary, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave in 12 minutes',
                            style: TextStyle(
                              color: primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '3 customers ahead',
                            style: TextStyle(
                              color: AppColors.activeMutedText,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: Transform.rotate(
            angle: bellSwing,
            child: Transform.scale(
              scale: 0.985 + (pulse * 0.03),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                  boxShadow: AppEffects.raisedShadow,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    Positioned(
                      top: 8,
                      right: 7,
                      child: Transform.scale(
                        scale: 0.9 + (pulse * 0.2),
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 1,
          bottom: 8,
          child: Transform.translate(
            offset: Offset(wave * 5, wave * 1.5),
            child: Container(
              width: 66,
              height: 54,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: border),
                boxShadow: AppEffects.cardShadow,
              ),
              child: Icon(
                Icons.directions_car_rounded,
                color: primary,
                size: 33,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingInfoCard extends StatelessWidget {
  const _FloatingInfoCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.activeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.activeBorder),
        boxShadow: AppEffects.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: AppEffects.cardShadow,
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class _DottedRoutePainter extends CustomPainter {
  const _DottedRoutePainter({required this.color, required this.motion});

  final Color color;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.48)
      ..style = PaintingStyle.fill;
    const dots = 9;
    for (var index = 0; index < dots; index++) {
      final progress = index / (dots - 1);
      final x = 8 + ((size.width - 16) * progress);
      final y = (size.height / 2) - math.sin(progress * math.pi) * 5;
      canvas.drawCircle(Offset(x, y), 2.1, paint);
    }

    final travelProgress = Curves.easeInOut.transform(motion);
    final movingX = 8 + ((size.width - 16) * travelProgress);
    final movingY = (size.height / 2) - math.sin(travelProgress * math.pi) * 5;
    canvas.drawCircle(
      Offset(movingX, movingY),
      5,
      Paint()..color = color.withValues(alpha: 0.12),
    );
    canvas.drawCircle(Offset(movingX, movingY), 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DottedRoutePainter oldDelegate) =>
      color != oldDelegate.color || motion != oldDelegate.motion;
}
