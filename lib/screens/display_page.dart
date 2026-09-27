import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/localized_text.dart';

import '../theme/app_theme.dart';
import '../widgets/app_motion.dart';
import 'admin_settings.dart';

// ============================================================================
// THEME COLORS
// ============================================================================

Color get _primaryColor => AppColors.activePrimary;
Color get _mutedTextColor => AppColors.activeMutedText;
Color _dangerColor = AppColors.danger;

const Color _displayBackdropColor = Color(0xFF0B1426);
const Color _displayFrameColor = Color(0xFFEAF1F5);
const Color _displayNavyColor = Color(0xFF0F2B48);
const Color _displayDeepNavyColor = Color(0xFF0B1B2B);
const Color _displayAmberColor = Color(0xFFF59E0B);
const Color _displayGreenColor = Color(0xFF10B981);

const String displayPageRoute = '/display';

Uri displayPageUri(Uri currentUri) {
  return currentUri.replace(fragment: displayPageRoute);
}

bool isDisplayPageLaunch(Uri currentUri, {String? initialRouteName}) {
  String normalizedRoute(String value) {
    final withoutQuery = value.split('?').first.trim();
    if (withoutQuery.isEmpty) return '/';
    return withoutQuery.startsWith('/') ? withoutQuery : '/$withoutQuery';
  }

  final routeName = normalizedRoute(initialRouteName ?? '');
  final fragmentRoute = normalizedRoute(currentUri.fragment);
  final pathRoute = normalizedRoute(currentUri.path);

  return routeName == displayPageRoute ||
      fragmentRoute == displayPageRoute ||
      pathRoute == displayPageRoute;
}

// Used only for display estimate.
const int _estimatedMinutesPerCustomer = 9;
const int displayWaitingQueueLimit = 4;

List<Map<String, dynamic>> visibleWaitingQueues(
  Iterable<Map<String, dynamic>> waitingQueue,
) {
  return waitingQueue.take(displayWaitingQueueLimit).toList(growable: false);
}

// ============================================================================
// DISPLAY PAGE
// ============================================================================

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  String todayDate() {
    final now = DateTime.now();
    return "${now.month}/${now.day}/${now.year}";
  }

  String displayTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute:$second $period';
  }

  String displayLongDate(DateTime value) {
    const months = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String queueDateId(String date) {
    return date.replaceAll("/", "-");
  }

  // ==========================================================================
  // FIRESTORE STREAM
  // ==========================================================================

  Stream<List<Map<String, dynamic>>> todayQueueStream() {
    final String today = todayDate();

    return FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(today))
        .collection("items")
        .orderBy("createdAt")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return {...data, "queueId": data["queueId"] ?? doc.id};
          }).toList();
        });
  }

  Map<String, dynamic>? getNowServing(List<Map<String, dynamic>> items) {
    final nowServing = items.where((item) {
      return item["status"]?.toString() == "Now Serving";
    }).toList();

    if (nowServing.isEmpty) {
      return null;
    }

    return nowServing.last;
  }

  List<Map<String, dynamic>> getWaitingQueue(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final status = item["status"]?.toString() ?? "Waiting";
      return status == "Waiting" || status == "Skipped";
    }).toList();
  }

  String estimateWaitingTime(int index) {
    final minutes = (index + 1) * _estimatedMinutesPerCustomer;
    return "Est. $minutes min";
  }

  // ==========================================================================
  // BUILD PAGE
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final String today = todayDate();

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _displayBackdropColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _displayNavyColor,
          onPrimary: Colors.white,
          surface: _displayFrameColor,
          onSurface: _displayDeepNavyColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: _displayBackdropColor,
        body: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: todayQueueStream(),
            builder: (context, snapshot) {
              final List<Map<String, dynamic>> queueItems = snapshot.data ?? [];

              final Map<String, dynamic>? nowServing = getNowServing(
                queueItems,
              );

              final List<Map<String, dynamic>> waitingQueue = getWaitingQueue(
                queueItems,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 900;
                  final bool isShort = constraints.maxHeight < 700;

                  final double pagePadding = isWide ? 24 : 10;
                  final double framePadding = isWide ? 22 : 12;
                  final double titleSize = isWide ? 28 : 19;
                  final double queueFontSize = isWide ? 128 : 72;

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(pagePadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1260),
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight - (pagePadding * 2),
                          ),
                          padding: EdgeInsets.all(framePadding),
                          decoration: BoxDecoration(
                            color: _displayFrameColor,
                            borderRadius: BorderRadius.circular(
                              isWide ? 24 : 20,
                            ),
                            border: Border.all(
                              color: const Color(0xFF24364A),
                              width: isWide ? 6 : 4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 34,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              buildHeader(
                                titleSize: titleSize,
                                isWide: isWide,
                                isShort: isShort,
                                showBackButton: showBackButton,
                                onBack: () => Navigator.maybePop(context),
                              ),

                              SizedBox(height: isShort ? 14 : 20),

                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData)
                                buildLoadingCard()
                              else if (snapshot.hasError)
                                buildErrorCard(snapshot.error.toString())
                              else ...[
                                buildNowServingCard(
                                  nowServing: nowServing,
                                  queueFontSize: queueFontSize,
                                  isShort: isShort,
                                ),

                                SizedBox(height: isShort ? 14 : 20),

                                buildNextInLineCard(
                                  today: today,
                                  waitingQueue: waitingQueue,
                                  isWide: isWide,
                                  isShort: isShort,
                                ),

                                SizedBox(height: isShort ? 12 : 16),

                                buildAnnouncement(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget buildHeader({
    required double titleSize,
    required bool isWide,
    required bool isShort,
    required bool showBackButton,
    required VoidCallback onBack,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isShort ? 14 : 18,
        vertical: isShort ? 13 : 16,
      ),
      decoration: BoxDecoration(
        color: _displayNavyColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B1B2B),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: "Back",
              onPressed: onBack,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _displayDeepNavyColor,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          if (showBackButton) const SizedBox(width: 10),
          Container(
            height: isShort ? 46 : 54,
            width: isShort ? 46 : 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 8),
              ],
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: _displayNavyColor,
              size: isShort ? 27 : 31,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "NPJN EMISSION CENTER",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _displayGreenColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        "Onsite Display Monitor  •  Counter 1 Active",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _displayGreenColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: isWide ? 16 : 8),
          StreamBuilder<int>(
            stream: Stream<int>.periodic(
              const Duration(seconds: 1),
              (value) => value,
            ),
            builder: (context, snapshot) {
              final now = DateTime.now();
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 17 : 9,
                  vertical: isShort ? 7 : 10,
                ),
                decoration: BoxDecoration(
                  color: _displayDeepNavyColor,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayTime(now),
                      style: TextStyle(
                        color: _displayAmberColor,
                        fontSize: isWide ? 20 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    if (isWide) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayLongDate(now),
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOADING / ERROR
  // ==========================================================================

  Widget buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: cardDecoration(),
      child: Column(
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 14),
          Text(
            "Loading queue display...",
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: _dangerColor, size: 46),
          const SizedBox(height: 12),
          Text(
            "Unable to load queue display",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dangerColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedTextColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // NOW SERVING CARD
  // ==========================================================================

  Widget buildNowServingCard({
    required Map<String, dynamic>? nowServing,
    required double queueFontSize,
    required bool isShort,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isShort ? 18 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E3B64), Color(0xFF0B3155)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF274F73), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x550B1B2B),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(height: 1, color: const Color(0x66F59E0B)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _displayAmberColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _displayAmberColor.withValues(alpha: 0.42),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      color: _displayAmberColor,
                      size: 21,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "NOW SERVING",
                      style: TextStyle(
                        color: Color(0xFFFCD34D),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(height: 1, color: const Color(0x66F59E0B)),
              ),
            ],
          ),

          SizedBox(height: isShort ? 10 : 14),

          AppStatusPulse(
            active: nowServing != null,
            color: _displayAmberColor,
            borderRadius: 24,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isShort ? 6 : 10,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  nowServing == null ? "-" : nowServing["queue"] ?? "-",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: queueFontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: const [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 12,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          ValueListenableBuilder<bool>(
            valueListenable: showCustomerNameNotifier,
            builder: (context, showName, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: showVehicleTypeNotifier,
                builder: (context, showVehicle, _) {
                  final showVehicleDetails = showVehicle && nowServing != null;
                  if (!showName && !showVehicleDetails) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: isShort ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color: _displayDeepNavyColor.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        if (showName)
                          Text(
                            nowServing == null
                                ? "Please wait for today's queue number"
                                : nowServing["name"] ?? "",
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _displayAmberColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (showName && showVehicleDetails)
                          const SizedBox(height: 7),
                        if (showVehicleDetails)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1D4ED8,
                              ).withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(
                                  0xFF60A5FA,
                                ).withValues(alpha: 0.36),
                              ),
                            ),
                            child: Text(
                              "${nowServing["type"] ?? ""} Vehicle",
                              style: const TextStyle(
                                color: Color(0xFFBFDBFE),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // NEXT IN LINE CARD
  // ==========================================================================

  Widget buildNextInLineCard({
    required String today,
    required List<Map<String, dynamic>> waitingQueue,
    required bool isWide,
    required bool isShort,
  }) {
    final visibleQueue = visibleWaitingQueues(waitingQueue);
    final hiddenQueueCount = waitingQueue.length - visibleQueue.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isShort ? 15 : 20),
      decoration: BoxDecoration(
        color: _displayNavyColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27435F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F2B48),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.format_list_numbered_rounded,
            title: "UP NEXT",
            trailing: "${waitingQueue.length} waiting • $today",
          ),

          const SizedBox(height: 16),

          if (waitingQueue.isEmpty)
            emptyQueueBox()
          else if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int index = 0; index < visibleQueue.length; index++) ...[
                  if (index > 0) const SizedBox(width: 14),
                  Expanded(
                    child: queueTile(
                      customer: visibleQueue[index],
                      index: index,
                    ),
                  ),
                ],
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int index = 0; index < visibleQueue.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    SizedBox(
                      width: 155,
                      child: queueTile(
                        customer: visibleQueue[index],
                        index: index,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (hiddenQueueCount > 0) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _displayDeepNavyColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF29445F)),
                ),
                child: Text(
                  "+$hiddenQueueCount more waiting",
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget queueTile({
    required Map<String, dynamic> customer,
    required int index,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: _displayDeepNavyColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: index == 0 ? _displayAmberColor : const Color(0xFF29445F),
          width: index == 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "NEXT #${index + 1}",
            style: const TextStyle(
              color: Color(0xFF9FB4C8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              customer["queue"] ?? "-",
              style: TextStyle(
                color: index == 0 ? _displayAmberColor : Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: showVehicleTypeNotifier,
            builder: (context, showVehicle, _) {
              if (!showVehicle) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  customer["type"] ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: showEstimatedWaitingTimeNotifier,
            builder: (context, showTime, _) {
              if (!showTime) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  estimateWaitingTime(index),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF9FB4C8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ANNOUNCEMENT
  // ==========================================================================

  Widget buildAnnouncement() {
    return ValueListenableBuilder<String>(
      valueListenable: displayAnnouncementNotifier,
      builder: (context, announcement, _) {
        final message = announcement.trim().isEmpty
            ? "Please stay alert and proceed when your queue number is called."
            : announcement.trim();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _displayDeepNavyColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _displayAmberColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      color: _displayDeepNavyColor,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "ANNOUNCEMENT",
                      style: TextStyle(
                        color: _displayDeepNavyColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // REUSABLE WIDGETS
  // ==========================================================================

  Widget sectionHeader({
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: _displayAmberColor, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _displayDeepNavyColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF29445F)),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget emptyQueueBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _displayDeepNavyColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29445F)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: Color(0xFF94A3B8), size: 42),
          const SizedBox(height: 10),
          Text(
            "No waiting queue for today",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFCBD5E1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x220F2B48),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}
