import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'book_appointment.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class DailyReport extends StatefulWidget {
  const DailyReport({super.key});

  @override
  State<DailyReport> createState() => _DailyReportState();
}

class _DailyReportState extends State<DailyReport> {
  String selectedDate = "";

  @override
  void initState() {
    super.initState();
    selectedDate = todayDate();
  }

  // ================= DATE HELPERS =================

  String todayDate() {
    final now = DateTime.now();
    return "${now.month}/${now.day}/${now.year}";
  }

  String formatPickedDate(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  DateTime parseDate(String date) {
    final parts = date.split("/");

    if (parts.length != 3) {
      return DateTime(1970);
    }

    final month = int.tryParse(parts[0]) ?? 1;
    final day = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? 1970;

    return DateTime(year, month, day);
  }

  String monthKeyFromDate(String date) {
    final parsed = parseDate(date);
    return "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}";
  }

  String monthLabelFromKey(String key) {
    final parts = key.split("-");
    if (parts.length != 2) return key;

    final year = int.tryParse(parts[0]) ?? 1970;
    final month = int.tryParse(parts[1]) ?? 1;

    const monthNames = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    if (month < 1 || month > 12) return key;

    return "${monthNames[month - 1]} $year";
  }

  // FIXED:
  // Before, this used DateTime.now().
  // Now, Seasonal Detection follows the selected report date.
  String currentMonthKey() {
    return monthKeyFromDate(selectedDate);
  }

  Future<void> pickReportDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: parseDate(selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = formatPickedDate(picked);
      });
    }
  }

  // ================= DATA FILTERS =================

  List<Map<String, dynamic>> getPassedByDate(String date) {
    return dailyServedReportNotifier.value[date] ?? [];
  }

  List<Map<String, dynamic>> getFailedByDate(String date) {
    return dailyFailedReportNotifier.value[date] ?? [];
  }

  List<Map<String, dynamic>> getApprovedByDate(String date) {
    return approvedBookings.value.where((booking) {
      return booking["date"] == date;
    }).toList();
  }

  List<Map<String, dynamic>> getRejectedByDate(String date) {
    return rejectedBookings.value.where((booking) {
      return booking["date"] == date;
    }).toList();
  }

  List<Map<String, dynamic>> getPendingByDate(String date) {
    return pendingBookings.value.where((booking) {
      return booking["date"] == date;
    }).toList();
  }

  bool hasAnyRecordForDate(String date) {
    return getPassedByDate(date).isNotEmpty ||
        getFailedByDate(date).isNotEmpty ||
        getApprovedByDate(date).isNotEmpty ||
        getRejectedByDate(date).isNotEmpty ||
        getPendingByDate(date).isNotEmpty;
  }

  // ================= SEASONAL DETECTION =================

  Map<String, Map<String, int>> getMonthlySummary() {
    final Map<String, Map<String, int>> monthly = {};

    void ensureMonth(String monthKey) {
      monthly.putIfAbsent(
        monthKey,
        () => {
          "passed": 0,
          "failed": 0,
          "approved": 0,
          "rejected": 0,
          "pending": 0,
          "totalServed": 0,
          "bookingActivity": 0,
        },
      );
    }

    dailyServedReportNotifier.value.forEach((date, list) {
      final key = monthKeyFromDate(date);
      ensureMonth(key);
      monthly[key]!["passed"] = monthly[key]!["passed"]! + list.length;
      monthly[key]!["totalServed"] =
          monthly[key]!["totalServed"]! + list.length;
    });

    dailyFailedReportNotifier.value.forEach((date, list) {
      final key = monthKeyFromDate(date);
      ensureMonth(key);
      monthly[key]!["failed"] = monthly[key]!["failed"]! + list.length;
      monthly[key]!["totalServed"] =
          monthly[key]!["totalServed"]! + list.length;
    });

    for (var booking in approvedBookings.value) {
      if (booking["date"] == null) continue;

      final key = monthKeyFromDate(booking["date"]);
      ensureMonth(key);

      monthly[key]!["approved"] = monthly[key]!["approved"]! + 1;
      monthly[key]!["bookingActivity"] =
          monthly[key]!["bookingActivity"]! + 1;
    }

    for (var booking in rejectedBookings.value) {
      if (booking["date"] == null) continue;

      final key = monthKeyFromDate(booking["date"]);
      ensureMonth(key);

      monthly[key]!["rejected"] = monthly[key]!["rejected"]! + 1;
      monthly[key]!["bookingActivity"] =
          monthly[key]!["bookingActivity"]! + 1;
    }

    for (var booking in pendingBookings.value) {
      if (booking["date"] == null) continue;

      final key = monthKeyFromDate(booking["date"]);
      ensureMonth(key);

      monthly[key]!["pending"] = monthly[key]!["pending"]! + 1;
      monthly[key]!["bookingActivity"] =
          monthly[key]!["bookingActivity"]! + 1;
    }

    return monthly;
  }

  double getAverageMonthlyServed(
    Map<String, Map<String, int>> monthly,
    String currentKey,
  ) {
    final previousMonths = monthly.entries.where((entry) {
      return entry.key != currentKey && entry.value["totalServed"]! > 0;
    }).toList();

    if (previousMonths.isEmpty) {
      final allMonths = monthly.entries.where((entry) {
        return entry.value["totalServed"]! > 0;
      }).toList();

      if (allMonths.isEmpty) return 0;

      final total = allMonths.fold<int>(
        0,
        (sum, entry) => sum + entry.value["totalServed"]!,
      );

      return total / allMonths.length;
    }

    final total = previousMonths.fold<int>(
      0,
      (sum, entry) => sum + entry.value["totalServed"]!,
    );

    return total / previousMonths.length;
  }

  MapEntry<String, Map<String, int>>? getPeakMonth(
    Map<String, Map<String, int>> monthly,
  ) {
    if (monthly.isEmpty) return null;

    final entries = monthly.entries.toList();

    entries.sort((a, b) {
      return b.value["totalServed"]!.compareTo(a.value["totalServed"]!);
    });

    return entries.first;
  }

  bool isSeasonalPeak({
    required int currentMonthTotal,
    required double average,
  }) {
    if (average <= 0) return false;
    return currentMonthTotal > average * 1.30;
  }

  int percentageAboveAverage({
    required int currentMonthTotal,
    required double average,
  }) {
    if (average <= 0) return 0;

    final percent = ((currentMonthTotal - average) / average) * 100;
    return percent.round();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final passedList = getPassedByDate(selectedDate);
    final failedList = getFailedByDate(selectedDate);
    final approvedList = getApprovedByDate(selectedDate);
    final rejectedList = getRejectedByDate(selectedDate);
    final pendingList = getPendingByDate(selectedDate);

    final totalServed = passedList.length + failedList.length;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _backgroundColor,
          foregroundColor: _primaryColor,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Daily Report")),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 850;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  children: [
                    buildDateSelector(),
                    const SizedBox(height: 14),
                    buildSeasonalDetectionCard(wide),
                    const SizedBox(height: 14),
                    buildSummarySection(
                      wide: wide,
                      totalServed: totalServed,
                      passed: passedList.length,
                      failed: failedList.length,
                      approved: approvedList.length,
                      rejected: rejectedList.length,
                      pending: pendingList.length,
                    ),
                    const SizedBox(height: 16),
                    buildReportDetails(
                      date: selectedDate,
                      totalServed: totalServed,
                      passedList: passedList,
                      failedList: failedList,
                      approvedList: approvedList,
                      rejectedList: rejectedList,
                      pendingList: pendingList,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= DATE SELECTOR =================

  Widget buildDateSelector() {
    return cardContainer(
      child: Row(
        children: [
          iconBox(Icons.calendar_month_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Report Date: $selectedDate",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: pickReportDate,
            child: const Text(
              "Change",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ================= SEASONAL DETECTION CARD =================

  Widget buildSeasonalDetectionCard(bool wide) {
    final monthly = getMonthlySummary();
    final currentKey = currentMonthKey();
    final currentMonthTotal = monthly[currentKey]?["totalServed"] ?? 0;
    final average = getAverageMonthlyServed(monthly, currentKey);

    final peak = isSeasonalPeak(
      currentMonthTotal: currentMonthTotal,
      average: average,
    );

    final aboveAverage = percentageAboveAverage(
      currentMonthTotal: currentMonthTotal,
      average: average,
    );

    final peakMonth = getPeakMonth(monthly);

    String statusTitle;
    String statusMessage;
    IconData statusIcon;
    Color statusColor;

    if (monthly.length < 2 || average == 0) {
      statusTitle = "Not Enough Data";
      statusMessage = "More monthly records are needed.";
      statusIcon = Icons.info_outline_rounded;
      statusColor = Colors.blue;
    } else if (peak) {
      statusTitle = "Seasonal Peak Detected";
      statusMessage =
          "${monthLabelFromKey(currentKey)} is $aboveAverage% above the usual monthly average.";
      statusIcon = Icons.warning_amber_rounded;
      statusColor = Colors.orange;
    } else {
      statusTitle = "Normal Volume";
      statusMessage = "Queue volume is within normal range.";
      statusIcon = Icons.check_circle_outline_rounded;
      statusColor = Colors.green;
    }

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.trending_up_rounded,
            title: "Seasonal Detection",
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (wide)
            Row(
              children: [
                seasonalMiniCard(
                  title: "Current",
                  value: currentMonthTotal.toString(),
                  subtitle: monthLabelFromKey(currentKey),
                ),
                const SizedBox(width: 10),
                seasonalMiniCard(
                  title: "Average",
                  value: average.toStringAsFixed(1),
                  subtitle: "Monthly served",
                ),
                const SizedBox(width: 10),
                seasonalMiniCard(
                  title: "Peak",
                  value: peakMonth == null
                      ? "-"
                      : "${peakMonth.value['totalServed']}",
                  subtitle: peakMonth == null
                      ? "No data"
                      : monthLabelFromKey(peakMonth.key),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                seasonalMiniBox(
                  title: "Current",
                  value: currentMonthTotal.toString(),
                  subtitle: monthLabelFromKey(currentKey),
                ),
                seasonalMiniBox(
                  title: "Average",
                  value: average.toStringAsFixed(1),
                  subtitle: "Monthly served",
                ),
                seasonalMiniBox(
                  title: "Peak",
                  value: peakMonth == null
                      ? "-"
                      : "${peakMonth.value['totalServed']}",
                  subtitle: peakMonth == null
                      ? "No data"
                      : monthLabelFromKey(peakMonth.key),
                ),
              ],
            ),
          const SizedBox(height: 16),
          sectionHeader(icon: Icons.bar_chart_rounded, title: "Monthly Trend"),
          const SizedBox(height: 12),
          monthly.isEmpty
              ? emptyBox("No monthly trend data yet.")
              : buildMonthlyTrend(monthly),
        ],
      ),
    );
  }

  Widget buildMonthlyTrend(Map<String, Map<String, int>> monthly) {
    final entries = monthly.entries.toList();

    entries.sort((a, b) {
      return a.key.compareTo(b.key);
    });

    final maxValue = entries.fold<int>(0, (max, entry) {
      final value = entry.value["totalServed"] ?? 0;
      return value > max ? value : max;
    });

    return Column(
      children: entries.map((entry) {
        final total = entry.value["totalServed"] ?? 0;
        final percentage = maxValue == 0 ? 0.0 : total / maxValue;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  monthLabelFromKey(entry.key),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: _softPrimaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36,
                child: Text(
                  "$total",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget seasonalMiniCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: seasonalMiniContent(
        title: title,
        value: value,
        subtitle: subtitle,
      ),
    );
  }

  Widget seasonalMiniBox({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return SizedBox(
      width: 150,
      child: seasonalMiniContent(
        title: title,
        value: value,
        subtitle: subtitle,
      ),
    );
  }

  Widget seasonalMiniContent({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SUMMARY SECTION =================

  Widget buildSummarySection({
    required bool wide,
    required int totalServed,
    required int passed,
    required int failed,
    required int approved,
    required int rejected,
    required int pending,
  }) {
    final cards = [
      summaryContent(
        title: "Served",
        value: "$totalServed",
        icon: Icons.groups_rounded,
        color: _primaryColor,
      ),
      summaryContent(
        title: "Passed",
        value: "$passed",
        icon: Icons.check_circle_outline_rounded,
        color: Colors.green,
      ),
      summaryContent(
        title: "Failed",
        value: "$failed",
        icon: Icons.cancel_outlined,
        color: Colors.red,
      ),
      summaryContent(
        title: "Approved",
        value: "$approved",
        icon: Icons.verified_outlined,
        color: Colors.green,
      ),
      summaryContent(
        title: "Rejected",
        value: "$rejected",
        icon: Icons.block_rounded,
        color: Colors.red,
      ),
      summaryContent(
        title: "Pending",
        value: "$pending",
        icon: Icons.pending_actions_rounded,
        color: Colors.orange,
      ),
    ];

    if (wide) {
      return Row(
        children: cards.map((card) {
          final isLast = cards.last == card;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 10),
              child: card,
            ),
          );
        }).toList(),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: cards.map((card) {
        return SizedBox(width: 150, child: card);
      }).toList(),
    );
  }

  Widget summaryContent({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= REPORT DETAILS =================

  Widget buildReportDetails({
    required String date,
    required int totalServed,
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    if (!hasAnyRecordForDate(date)) {
      return cardContainer(child: emptyBox("No report records for $date."));
    }

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.receipt_long_rounded,
            title: "Report Details",
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
            ),
            child: Text(
              "Summary for $date: $totalServed served, ${passedList.length} passed, ${failedList.length} failed, ${approvedList.length} approved booking(s), ${rejectedList.length} rejected booking(s), and ${pendingList.length} pending booking(s).",
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          reportListSection(
            title: "Passed Customers",
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            records: passedList,
            emptyText: "No passed customers for this date.",
          ),
          const SizedBox(height: 14),
          reportListSection(
            title: "Failed Customers",
            icon: Icons.cancel_outlined,
            color: Colors.red,
            records: failedList,
            emptyText: "No failed customers for this date.",
          ),
          const SizedBox(height: 14),
          reportListSection(
            title: "Approved Bookings",
            icon: Icons.verified_outlined,
            color: Colors.green,
            records: approvedList,
            emptyText: "No approved bookings for this date.",
          ),
          const SizedBox(height: 14),
          reportListSection(
            title: "Rejected Bookings",
            icon: Icons.block_rounded,
            color: Colors.red,
            records: rejectedList,
            emptyText: "No rejected bookings for this date.",
          ),
          const SizedBox(height: 14),
          reportListSection(
            title: "Pending Bookings",
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
            records: pendingList,
            emptyText: "No pending bookings for this date.",
          ),
        ],
      ),
    );
  }

  Widget reportListSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> records,
    required String emptyText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${records.length}",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            emptyBox(emptyText)
          else
            Column(
              children: records.map((record) {
                return reportRecordTile(record);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget reportRecordTile(Map<String, dynamic> record) {
    final queue = record["queue"]?.toString() ?? "-";
    final name = record["name"]?.toString() ??
        record["fullName"]?.toString() ??
        record["plate"]?.toString() ??
        "-";
    final vehicle = record["type"]?.toString() ??
        record["vehicle"]?.toString() ??
        "-";
    final source = record["source"]?.toString() ??
        record["status"]?.toString() ??
        "-";
    final time = record["time"]?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              queue.isNotEmpty ? queue.substring(0, 1) : "-",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$queue - $name",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$vehicle • $source${time == null ? "" : " • $time"}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= REUSABLE UI =================

  Widget cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: child,
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _borderColor),
      boxShadow: [
        BoxShadow(
          color: _primaryColor.withOpacity(0.06),
          blurRadius: 14,
        ),
      ],
    );
  }

  Widget iconBox(IconData icon) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Icon(icon, color: _primaryColor, size: 23),
    );
  }

  Widget sectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _mutedTextColor,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}