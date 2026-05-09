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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= CALENDAR SELECTOR =================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Report Date: $selectedDate",
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
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
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
            ),

            const SizedBox(height: 20),

            // ================= REPORT DETAILS =================

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: !hasAnyRecordForDate(selectedDate)
                    ? Center(
                        child: Text(
                          "No report records for $selectedDate.",
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: reportDateCard(
                          date: selectedDate,
                          totalServed: totalServed,
                          passedList: passedList,
                          failedList: failedList,
                          approvedList: approvedList,
                          rejectedList: rejectedList,
                          pendingList: pendingList,
                        ),
                      ),
              ),
            ),
          ],
        ),
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
            ),
          ],
        ),
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
          // DATE HEADER

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
}