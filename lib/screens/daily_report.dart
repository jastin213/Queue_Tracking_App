import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'book_appointment.dart';

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

    return "${monthNames[month - 1]} $year";
  }

  String currentMonthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  Future<void> pickReportDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: parseDate(selectedDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),
      appBar: AppBar(
        title: const Text("Daily Report / History"),
        backgroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = constraints.maxWidth >= 850;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildSeasonalDetectionCard(wide),

                const SizedBox(height: 15),

                // ================= CALENDAR SELECTOR =================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Report Date: $selectedDate",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: pickReportDate,
                        child: const Text("Choose Date"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // ================= SELECTED DATE SUMMARY =================

                if (wide)
                  Row(
                    children: [
                      summaryCard(
                        title: "Served",
                        value: "$totalServed",
                        subtitle: "Passed + Failed",
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        title: "Passed",
                        value: "${passedList.length}",
                        subtitle: "Successful",
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        title: "Failed",
                        value: "${failedList.length}",
                        subtitle: "Failed",
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        title: "Approved",
                        value: "${approvedList.length}",
                        subtitle: "Bookings",
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        title: "Rejected",
                        value: "${rejectedList.length}",
                        subtitle: "Bookings",
                      ),
                      const SizedBox(width: 10),
                      summaryCard(
                        title: "Pending",
                        value: "${pendingList.length}",
                        subtitle: "Bookings",
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      summaryBox(
                        title: "Served",
                        value: "$totalServed",
                        subtitle: "Passed + Failed",
                      ),
                      summaryBox(
                        title: "Passed",
                        value: "${passedList.length}",
                        subtitle: "Successful",
                      ),
                      summaryBox(
                        title: "Failed",
                        value: "${failedList.length}",
                        subtitle: "Failed",
                      ),
                      summaryBox(
                        title: "Approved",
                        value: "${approvedList.length}",
                        subtitle: "Bookings",
                      ),
                      summaryBox(
                        title: "Rejected",
                        value: "${rejectedList.length}",
                        subtitle: "Bookings",
                      ),
                      summaryBox(
                        title: "Pending",
                        value: "${pendingList.length}",
                        subtitle: "Bookings",
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // ================= REPORT DETAILS =================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: !hasAnyRecordForDate(selectedDate)
                      ? Padding(
                          padding: const EdgeInsets.all(30),
                          child: Center(
                            child: Text(
                              "No report records for $selectedDate.",
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : reportDateCard(
                          date: selectedDate,
                          totalServed: totalServed,
                          passedList: passedList,
                          failedList: failedList,
                          approvedList: approvedList,
                          rejectedList: rejectedList,
                          pendingList: pendingList,
                        ),
                ),
              ],
            ),
          );
        },
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
      statusTitle = "Not Enough Historical Data";
      statusMessage =
          "Seasonal Detection will become more accurate after more monthly reports are recorded.";
      statusIcon = Icons.info_outline;
      statusColor = Colors.blue;
    } else if (peak) {
      statusTitle = "SEASONAL PEAK DETECTED";
      statusMessage =
          "This month is $aboveAverage% higher than the usual monthly average.";
      statusIcon = Icons.warning_amber_rounded;
      statusColor = Colors.orange;
    } else {
      statusTitle = "Normal Queue Volume";
      statusMessage =
          "This month is within the normal range based on available report history.";
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER

          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Seasonal Detection",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusMessage,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (wide)
            Row(
              children: [
                seasonalMiniCard(
                  "Current Month",
                  currentMonthTotal.toString(),
                  monthLabelFromKey(currentKey),
                ),
                const SizedBox(width: 10),
                seasonalMiniCard(
                  "Monthly Average",
                  average.toStringAsFixed(1),
                  "Based on report history",
                ),
                const SizedBox(width: 10),
                seasonalMiniCard(
                  "Peak Month",
                  peakMonth == null
                      ? "-"
                      : "${peakMonth.value['totalServed']}",
                  peakMonth == null
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
                  "Current Month",
                  currentMonthTotal.toString(),
                  monthLabelFromKey(currentKey),
                ),
                seasonalMiniBox(
                  "Monthly Average",
                  average.toStringAsFixed(1),
                  "Based on history",
                ),
                seasonalMiniBox(
                  "Peak Month",
                  peakMonth == null
                      ? "-"
                      : "${peakMonth.value['totalServed']}",
                  peakMonth == null
                      ? "No data"
                      : monthLabelFromKey(peakMonth.key),
                ),
              ],
            ),

          const SizedBox(height: 18),

          sectionTitle("Recommendation"),

          Text(
            peak
                ? "• Add staff or assign backup personnel\n"
                    "• Monitor queue volume earlier than usual\n"
                    "• Prepare documents, printers, parking, and inspection lanes\n"
                    "• Consider opening earlier during peak days"
                : "• Continue monitoring daily queue reports\n"
                    "• Use this trend as more historical data is collected\n"
                    "• Prepare early if the monthly total rises above normal",
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          sectionTitle("Monthly Queue Trend"),

          monthly.isEmpty
              ? const Text(
                  "No monthly trend data yet.",
                  style: TextStyle(color: Colors.grey),
                )
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
                width: 115,
                child: Text(
                  monthLabelFromKey(entry.key),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 45,
                child: Text(
                  "$total",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget seasonalMiniCard(String title, String value, String subtitle) {
    return Expanded(
      child: seasonalMiniContent(title, value, subtitle),
    );
  }

  Widget seasonalMiniBox(String title, String value, String subtitle) {
    return SizedBox(
      width: 170,
      child: seasonalMiniContent(title, value, subtitle),
    );
  }

  Widget seasonalMiniContent(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SUMMARY CARD =================

  Widget summaryCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: summaryContent(
        title: title,
        value: value,
        subtitle: subtitle,
      ),
    );
  }

  Widget summaryBox({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return SizedBox(
      width: 150,
      child: summaryContent(
        title: title,
        value: value,
        subtitle: subtitle,
      ),
    );
  }

  Widget summaryContent({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ================= REPORT DATE CARD =================

  Widget reportDateCard({
    required String date,
    required int totalServed,
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$date: $totalServed served",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            "Passed: ${passedList.length}   Failed: ${failedList.length}   Approved: ${approvedList.length}   Rejected: ${rejectedList.length}   Pending: ${pendingList.length}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 15),

          sectionTitle("Queue Summary"),

          if (passedList.isEmpty && failedList.isEmpty)
            const Text(
              "No served queue records.",
              style: TextStyle(color: Colors.grey),
            ),

          if (passedList.isNotEmpty)
            queueWrap(
              label: "Passed",
              list: passedList,
            ),

          if (failedList.isNotEmpty)
            queueWrap(
              label: "Failed",
              list: failedList,
            ),

          const SizedBox(height: 15),

          sectionTitle("Booking History"),

          if (approvedList.isEmpty &&
              rejectedList.isEmpty &&
              pendingList.isEmpty)
            const Text(
              "No booking records.",
              style: TextStyle(color: Colors.grey),
            ),

          if (approvedList.isNotEmpty)
            bookingList(
              label: "Approved Bookings",
              list: approvedList,
            ),

          if (rejectedList.isNotEmpty)
            bookingList(
              label: "Rejected Bookings",
              list: rejectedList,
            ),

          if (pendingList.isNotEmpty)
            bookingList(
              label: "Pending Bookings",
              list: pendingList,
            ),
        ],
      ),
    );
  }

  // ================= SECTION TITLE =================

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // ================= QUEUE WRAP =================

  Widget queueWrap({
    required String label,
    required List<Map<String, dynamic>> list,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((customer) {
              return Chip(
                label: Text(
                  "${customer['queue']} - ${customer['name'] ?? ''}",
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ================= BOOKING LIST =================

  Widget bookingList({
    required String label,
    required List<Map<String, dynamic>> list,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Column(
            children: list.map((booking) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${booking['queue']} • ${booking['fullName']} • ${booking['vehicle']} • ${booking['plate']}",
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ================= COMMON DECORATION =================

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10,
        ),
      ],
    );
  }
}