import 'package:flutter/material.dart';

import 'admin_page.dart';
import 'admin_settings.dart';

// ============================================================================
// THEME COLORS
// ============================================================================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);
const Color _dangerColor = Color(0xFFE53935);

// Used only for display estimate.
// You can adjust this later depending on your real average testing time.
const int _estimatedMinutesPerCustomer = 9;

// ============================================================================
// DISPLAY PAGE
// ============================================================================

class DisplayPage extends StatelessWidget {
  const DisplayPage({super.key});

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  String todayDate() {
    final now = DateTime.now();
    return "${now.month}/${now.day}/${now.year}";
  }

  // ==========================================================================
  // QUEUE HELPERS
  // ==========================================================================

  Map<String, dynamic>? getTodayNowServing() {
    final today = todayDate();

    if (nowServingNotifier.value == null) {
      return null;
    }

    final customer = nowServingNotifier.value!;

    if (customer["date"] == today) {
      return customer;
    }

    return null;
  }

  List<Map<String, dynamic>> getTodayWaitingQueue() {
    final today = todayDate();

    return waitingQueueNotifier.value.where((customer) {
      return customer["date"] == today;
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
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _primaryColor,
          onPrimary: Colors.white,
          surface: _cardColor,
          onSurface: _primaryColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 900;
              final bool isShort = constraints.maxHeight < 700;

              final double pagePadding = isWide ? 32 : 16;
              final double titleSize = isWide ? 30 : 22;
              final double queueFontSize = isWide ? 110 : 76;

              return SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  children: [
                    buildHeader(
                      today: today,
                      titleSize: titleSize,
                      isShort: isShort,
                    ),

                    SizedBox(height: isShort ? 18 : 24),

                    buildNowServingCard(
                      queueFontSize: queueFontSize,
                      isShort: isShort,
                    ),

                    SizedBox(height: isShort ? 18 : 24),

                    buildNextInLineCard(
                      today: today,
                      isWide: isWide,
                      isShort: isShort,
                    ),

                    SizedBox(height: isShort ? 14 : 20),

                    buildAnnouncement(),
                  ],
                ),
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
    required String today,
    required double titleSize,
    required bool isShort,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 22,
        vertical: isShort ? 16 : 20,
      ),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 16),

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
                      color: _primaryColor,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Queue Display • $today",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // NOW SERVING CARD
  // ==========================================================================

  Widget buildNowServingCard({
    required double queueFontSize,
    required bool isShort,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isShort ? 18 : 24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _dangerColor.withOpacity(0.30), width: 2),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.08), blurRadius: 18),
        ],
      ),
      child: ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: nowServingNotifier,
        builder: (context, customer, _) {
          final todayCustomer = getTodayNowServing();

          return Column(
            children: [
              const Text(
                "NOW SERVING",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: isShort ? 14 : 20),

              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: isShort ? 18 : 26,
                ),
                decoration: BoxDecoration(
                  color: _dangerColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _dangerColor, width: 3),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    todayCustomer == null ? "-" : todayCustomer["queue"],
                    style: TextStyle(
                      color: _dangerColor,
                      fontSize: queueFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              ValueListenableBuilder<bool>(
                valueListenable: showCustomerNameNotifier,
                builder: (context, showName, _) {
                  if (!showName) {
                    return const SizedBox.shrink();
                  }

                  return Text(
                    todayCustomer == null
                        ? "Please wait for today's queue number"
                        : todayCustomer["name"] ?? "",
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),

              ValueListenableBuilder<bool>(
                valueListenable: showVehicleTypeNotifier,
                builder: (context, showVehicle, _) {
                  if (!showVehicle || todayCustomer == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      todayCustomer["type"] ?? "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // NEXT IN LINE CARD
  // ==========================================================================

  Widget buildNextInLineCard({
    required String today,
    required bool isWide,
    required bool isShort,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isShort ? 16 : 22),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.groups_rounded,
            title: "NEXT IN LINE",
            trailing: today,
          ),

          const SizedBox(height: 16),

          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: waitingQueueNotifier,
            builder: (context, queueList, _) {
              final todayQueue = getTodayWaitingQueue();

              if (todayQueue.isEmpty) {
                return emptyQueueBox();
              }

              final visibleList = todayQueue.take(8).toList();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleList.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 2.9 : 2.2,
                ),
                itemBuilder: (context, index) {
                  final customer = visibleList[index];

                  return queueTile(customer: customer, index: index);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget queueTile({
    required Map<String, dynamic> customer,
    required int index,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              customer["queue"] ?? "-",
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
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
                  style: const TextStyle(
                    color: _mutedTextColor,
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
                  style: const TextStyle(
                    color: _mutedTextColor,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _softPrimaryColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_rounded,
                color: _primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 15,
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
        Icon(icon, color: _primaryColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              color: _mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_rounded, color: _primaryColor, size: 44),
          SizedBox(height: 10),
          Text(
            "No waiting queue for today",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _borderColor),
      boxShadow: [
        BoxShadow(color: _primaryColor.withOpacity(0.08), blurRadius: 18),
      ],
    );
  }
}