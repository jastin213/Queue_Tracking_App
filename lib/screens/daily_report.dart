import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/analytics_line_chart.dart';
import '../widgets/app_refresh_indicator.dart';

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
  final TextEditingController reportSearchController = TextEditingController();

  String selectedDate = "";
  String reportSearchQuery = "";

  @override
  void initState() {
    super.initState();
    selectedDate = todayDate();
  }

  @override
  void dispose() {
    reportSearchController.dispose();
    super.dispose();
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

  String shortMonthLabelFromKey(String key) {
    final parts = key.split("-");
    if (parts.length != 2) return key;

    const monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 0;

    if (month < 1 || month > 12) return key;

    return "${monthNames[month - 1]}\n${year.toString().padLeft(4, '0').substring(2)}";
  }

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
      reportSearchController.clear();

      setState(() {
        selectedDate = formatPickedDate(picked);
        reportSearchQuery = "";
      });
    }
  }

  // ================= FIRESTORE STREAMS =================

  Stream<List<Map<String, dynamic>>> queueReportStream() {
    return FirebaseFirestore.instance.collectionGroup("items").snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {...data, "queueId": data["queueId"] ?? doc.id};
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> appointmentStream() {
    return FirebaseFirestore.instance
        .collection("appointments")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return {...data, "appointmentId": data["appointmentId"] ?? doc.id};
          }).toList();
        });
  }

  Future<void> refreshReport() async {
    await Future.wait([
      FirebaseFirestore.instance
          .collectionGroup("items")
          .get(const GetOptions(source: Source.server)),
      FirebaseFirestore.instance
          .collection("appointments")
          .get(const GetOptions(source: Source.server)),
    ]);

    if (mounted) {
      setState(() {});
    }
  }

  // ================= DATA FILTERS =================

  List<Map<String, dynamic>> getPassedByDate(
    List<Map<String, dynamic>> queueItems,
    String date,
  ) {
    return queueItems.where((item) {
      return item["date"] == date && item["status"] == "Passed";
    }).toList();
  }

  List<Map<String, dynamic>> getFailedByDate(
    List<Map<String, dynamic>> queueItems,
    String date,
  ) {
    return queueItems.where((item) {
      return item["date"] == date && item["status"] == "Failed";
    }).toList();
  }

  List<Map<String, dynamic>> getPassedByMonth(
    List<Map<String, dynamic>> queueItems,
    String monthKey,
  ) {
    return queueItems.where((item) {
      final date = item["date"]?.toString() ?? "";
      return date.isNotEmpty &&
          monthKeyFromDate(date) == monthKey &&
          item["status"] == "Passed";
    }).toList();
  }

  List<Map<String, dynamic>> getFailedByMonth(
    List<Map<String, dynamic>> queueItems,
    String monthKey,
  ) {
    return queueItems.where((item) {
      final date = item["date"]?.toString() ?? "";
      return date.isNotEmpty &&
          monthKeyFromDate(date) == monthKey &&
          item["status"] == "Failed";
    }).toList();
  }

  List<Map<String, dynamic>> getApprovedByDate(
    List<Map<String, dynamic>> appointments,
    String date,
  ) {
    return appointments.where((appointment) {
      return appointment["date"] == date && appointment["status"] == "Approved";
    }).toList();
  }

  List<Map<String, dynamic>> getRejectedByDate(
    List<Map<String, dynamic>> appointments,
    String date,
  ) {
    return appointments.where((appointment) {
      return appointment["date"] == date && appointment["status"] == "Rejected";
    }).toList();
  }

  List<Map<String, dynamic>> getPendingByDate(
    List<Map<String, dynamic>> appointments,
    String date,
  ) {
    return appointments.where((appointment) {
      return appointment["date"] == date && appointment["status"] == "Pending";
    }).toList();
  }

  bool hasAnyRecordForDate({
    required String date,
    required List<Map<String, dynamic>> queueItems,
    required List<Map<String, dynamic>> appointments,
  }) {
    return getPassedByDate(queueItems, date).isNotEmpty ||
        getFailedByDate(queueItems, date).isNotEmpty ||
        getApprovedByDate(appointments, date).isNotEmpty ||
        getRejectedByDate(appointments, date).isNotEmpty ||
        getPendingByDate(appointments, date).isNotEmpty;
  }

  // ================= PDF HELPERS =================

  String safeText(dynamic value) {
    if (value == null) return "-";
    final text = value.toString().trim();
    return text.isEmpty ? "-" : text;
  }

  String recordName(Map<String, dynamic> record) {
    return safeText(
      record["name"] ?? record["fullName"] ?? record["plate"] ?? "-",
    );
  }

  String recordVehicle(Map<String, dynamic> record) {
    return safeText(record["type"] ?? record["vehicle"] ?? "-");
  }

  String recordSource(Map<String, dynamic> record) {
    return safeText(record["source"] ?? "-");
  }

  List<List<String>> pdfRowsFromRecords(
    List<Map<String, dynamic>> records,
    String result,
  ) {
    return records.map((record) {
      return [
        safeText(record["queue"]),
        recordName(record),
        recordVehicle(record),
        recordSource(record),
        safeText(record["time"]),
        result,
      ];
    }).toList();
  }

  pw.Widget pdfSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget pdfEmptyText(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(message, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget pdfRecordsTable(List<Map<String, dynamic>> records, String result) {
    if (records.isEmpty) {
      return pdfEmptyText("No $result records.");
    }

    return pw.Table.fromTextArray(
      headers: ["Queue", "Name", "Vehicle", "Source", "Time", "Result"],
      data: pdfRowsFromRecords(records, result),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(5),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    );
  }

  Future<void> printDailyPdf({
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
  }) async {
    final doc = pw.Document();

    final totalServed = passedList.length + failedList.length;
    final generatedAt = DateTime.now().toString().split(".").first;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Text(
              "NPJN Emission Testing Center",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Daily Report",
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("Report Date: $selectedDate"),
            pw.Text("Generated: $generatedAt"),
            pw.SizedBox(height: 16),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text("Served: $totalServed"),
                  pw.Text("Passed: ${passedList.length}"),
                  pw.Text("Failed: ${failedList.length}"),
                ],
              ),
            ),

            pdfSectionTitle("Passed Customers"),
            pdfRecordsTable(passedList, "Passed"),

            pdfSectionTitle("Failed Customers"),
            pdfRecordsTable(failedList, "Failed"),

            pw.SizedBox(height: 20),
            pw.Text(
              "This PDF report includes only Passed and Failed emission test results.",
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: "NPJN_Daily_Report_$selectedDate.pdf",
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  Future<void> printMonthlyPdf({
    required List<Map<String, dynamic>> queueItems,
  }) async {
    final monthKey = currentMonthKey();
    final monthLabel = monthLabelFromKey(monthKey);

    final passedList = getPassedByMonth(queueItems, monthKey);
    final failedList = getFailedByMonth(queueItems, monthKey);

    final totalServed = passedList.length + failedList.length;
    final generatedAt = DateTime.now().toString().split(".").first;

    final Map<String, Map<String, int>> dailySummary = {};

    void ensureDate(String date) {
      dailySummary.putIfAbsent(
        date,
        () => {"passed": 0, "failed": 0, "served": 0},
      );
    }

    for (final record in passedList) {
      final date = safeText(record["date"]);
      ensureDate(date);
      dailySummary[date]!["passed"] = dailySummary[date]!["passed"]! + 1;
      dailySummary[date]!["served"] = dailySummary[date]!["served"]! + 1;
    }

    for (final record in failedList) {
      final date = safeText(record["date"]);
      ensureDate(date);
      dailySummary[date]!["failed"] = dailySummary[date]!["failed"]! + 1;
      dailySummary[date]!["served"] = dailySummary[date]!["served"]! + 1;
    }

    final dailyEntries = dailySummary.entries.toList();
    dailyEntries.sort((a, b) {
      return parseDate(a.key).compareTo(parseDate(b.key));
    });

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Text(
              "NPJN Emission Testing Center",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Monthly Report",
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text("Report Month: $monthLabel"),
            pw.Text("Generated: $generatedAt"),
            pw.SizedBox(height: 16),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text("Served: $totalServed"),
                  pw.Text("Passed: ${passedList.length}"),
                  pw.Text("Failed: ${failedList.length}"),
                ],
              ),
            ),

            pdfSectionTitle("Daily Summary"),
            if (dailyEntries.isEmpty)
              pdfEmptyText("No Passed or Failed records for this month.")
            else
              pw.Table.fromTextArray(
                headers: ["Date", "Served", "Passed", "Failed"],
                data: dailyEntries.map((entry) {
                  return [
                    entry.key,
                    "${entry.value["served"]}",
                    "${entry.value["passed"]}",
                    "${entry.value["failed"]}",
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.all(5),
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
              ),

            pdfSectionTitle("Passed Customers"),
            pdfRecordsTable(passedList, "Passed"),

            pdfSectionTitle("Failed Customers"),
            pdfRecordsTable(failedList, "Failed"),

            pw.SizedBox(height: 20),
            pw.Text(
              "This PDF report includes only Passed and Failed emission test results.",
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: "NPJN_Monthly_Report_$monthKey.pdf",
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  // ================= SEASONAL DETECTION =================

  Map<String, Map<String, int>> getMonthlySummary({
    required List<Map<String, dynamic>> queueItems,
    required List<Map<String, dynamic>> appointments,
  }) {
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
          "appointmentActivity": 0,
        },
      );
    }

    for (final item in queueItems) {
      final date = item["date"]?.toString();
      final status = item["status"]?.toString();

      if (date == null || date.isEmpty) continue;

      final key = monthKeyFromDate(date);
      ensureMonth(key);

      if (status == "Passed") {
        monthly[key]!["passed"] = monthly[key]!["passed"]! + 1;
        monthly[key]!["totalServed"] = monthly[key]!["totalServed"]! + 1;
      }

      if (status == "Failed") {
        monthly[key]!["failed"] = monthly[key]!["failed"]! + 1;
        monthly[key]!["totalServed"] = monthly[key]!["totalServed"]! + 1;
      }
    }

    for (final appointment in appointments) {
      final date = appointment["date"]?.toString();
      final status = appointment["status"]?.toString();

      if (date == null || date.isEmpty) continue;

      final key = monthKeyFromDate(date);
      ensureMonth(key);

      if (status == "Approved") {
        monthly[key]!["approved"] = monthly[key]!["approved"]! + 1;
        monthly[key]!["appointmentActivity"] =
            monthly[key]!["appointmentActivity"]! + 1;
      }

      if (status == "Rejected") {
        monthly[key]!["rejected"] = monthly[key]!["rejected"]! + 1;
        monthly[key]!["appointmentActivity"] =
            monthly[key]!["appointmentActivity"]! + 1;
      }

      if (status == "Pending") {
        monthly[key]!["pending"] = monthly[key]!["pending"]! + 1;
        monthly[key]!["appointmentActivity"] =
            monthly[key]!["appointmentActivity"]! + 1;
      }
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: queueReportStream(),
      builder: (context, queueSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: appointmentStream(),
          builder: (context, appointmentSnapshot) {
            final queueItems = queueSnapshot.data ?? [];
            final appointments = appointmentSnapshot.data ?? [];

            final passedList = getPassedByDate(queueItems, selectedDate);
            final failedList = getFailedByDate(queueItems, selectedDate);
            final approvedList = getApprovedByDate(appointments, selectedDate);
            final rejectedList = getRejectedByDate(appointments, selectedDate);
            final pendingList = getPendingByDate(appointments, selectedDate);

            final totalServed = passedList.length + failedList.length;

            final bool isLoading =
                (queueSnapshot.connectionState == ConnectionState.waiting &&
                    !queueSnapshot.hasData) ||
                (appointmentSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !appointmentSnapshot.hasData);

            final Object? error =
                queueSnapshot.error ?? appointmentSnapshot.error;

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
                  child: AppRefreshIndicator(
                    onRefresh: refreshReport,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool wide = constraints.maxWidth >= 850;
                        final bool desktopWeb =
                            kIsWeb && constraints.maxWidth >= 900;

                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            desktopWeb ? 24 : 16,
                            10,
                            desktopWeb ? 24 : 16,
                            18,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: desktopWeb ? 1240 : double.infinity,
                              ),
                              child: Column(
                                children: [
                                  buildDateSelector(),

                                  const SizedBox(height: 14),

                                  if (isLoading)
                                    cardContainer(
                                      child: const Column(
                                        children: [
                                          CircularProgressIndicator(
                                            color: _primaryColor,
                                          ),
                                          SizedBox(height: 14),
                                          Text(
                                            "Loading report records...",
                                            style: TextStyle(
                                              color: _mutedTextColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (error != null)
                                    buildErrorCard(error.toString())
                                  else ...[
                                    buildPdfExportCard(
                                      passedList: passedList,
                                      failedList: failedList,
                                      queueItems: queueItems,
                                    ),

                                    const SizedBox(height: 14),

                                    buildSeasonalDetectionCard(
                                      wide: wide,
                                      queueItems: queueItems,
                                      appointments: appointments,
                                    ),

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
                                      queueItems: queueItems,
                                      appointments: appointments,
                                      passedList: passedList,
                                      failedList: failedList,
                                      approvedList: approvedList,
                                      rejectedList: rejectedList,
                                      pendingList: pendingList,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Widget buildPdfExportCard({
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> queueItems,
  }) {
    final monthLabel = monthLabelFromKey(currentMonthKey());

    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.picture_as_pdf_rounded,
            title: "Printable PDF Reports",
          ),
          const SizedBox(height: 10),
          const Text(
            "PDF exports include only Passed and Failed records.",
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool narrow = constraints.maxWidth < 520;
              final bool desktopWeb = kIsWeb && constraints.maxWidth >= 720;
              final double buttonHeight = desktopWeb ? 44 : 48;

              final dailyButton = SizedBox(
                width: desktopWeb
                    ? 320
                    : narrow
                    ? double.infinity
                    : null,
                height: buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await printDailyPdf(
                      passedList: passedList,
                      failedList: failedList,
                    );
                  },
                  icon: const Icon(Icons.today_rounded),
                  label: Text("Daily PDF - $selectedDate"),
                ),
              );

              final monthlyButton = SizedBox(
                width: desktopWeb
                    ? 320
                    : narrow
                    ? double.infinity
                    : null,
                height: buttonHeight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await printMonthlyPdf(queueItems: queueItems);
                  },
                  icon: const Icon(Icons.calendar_view_month_rounded),
                  label: Text("Monthly PDF - $monthLabel"),
                ),
              );

              if (desktopWeb) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [dailyButton, monthlyButton],
                );
              }

              if (narrow) {
                return Column(
                  children: [
                    dailyButton,
                    const SizedBox(height: 10),
                    monthlyButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: dailyButton),
                  const SizedBox(width: 12),
                  Expanded(child: monthlyButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildErrorCard(String error) {
    return cardContainer(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 46),
          const SizedBox(height: 12),
          const Text(
            "Unable to load daily report",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _mutedTextColor, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ================= SEASONAL DETECTION CARD =================

  Widget buildSeasonalDetectionCard({
    required bool wide,
    required List<Map<String, dynamic>> queueItems,
    required List<Map<String, dynamic>> appointments,
  }) {
    final monthly = getMonthlySummary(
      queueItems: queueItems,
      appointments: appointments,
    );

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
          sectionHeader(
            icon: Icons.show_chart_rounded,
            title: "Analytics Line Graph",
          ),
          const SizedBox(height: 12),
          monthly.isEmpty
              ? emptyBox("No analytics data yet.")
              : buildAnalyticsLineGraph(monthly),
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

  Widget buildAnalyticsLineGraph(Map<String, Map<String, int>> monthly) {
    final entries = monthly.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final visibleEntries = entries.length > 6
        ? entries.sublist(entries.length - 6)
        : entries;

    return AnalyticsLineChart(
      labels: visibleEntries
          .map((entry) => shortMonthLabelFromKey(entry.key))
          .toList(),
      servedValues: visibleEntries
          .map((entry) => entry.value["totalServed"] ?? 0)
          .toList(),
      appointmentValues: visibleEntries
          .map((entry) => entry.value["appointmentActivity"] ?? 0)
          .toList(),
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

  String reportCustomerName(Map<String, dynamic> record) {
    return (record["name"] ?? record["fullName"] ?? record["plate"] ?? "-")
        .toString()
        .trim();
  }

  List<Map<String, dynamic>> consolidatedReportRecords({
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    final recordsByKey = <String, Map<String, dynamic>>{};
    final records = [
      ...approvedList,
      ...rejectedList,
      ...pendingList,
      ...passedList,
      ...failedList,
    ];

    for (final record in records) {
      final String appointmentId =
          record["appointmentId"]?.toString().trim() ?? "";
      final String queue = record["queue"]?.toString().trim() ?? "";
      final String date = record["date"]?.toString().trim() ?? "";
      final String name = reportCustomerName(record).toLowerCase();
      final String key = appointmentId.isNotEmpty
          ? "appointment:$appointmentId"
          : "record:$date:$queue:$name";

      recordsByKey[key] = {...?recordsByKey[key], ...record};
    }

    return recordsByKey.values.toList();
  }

  Widget buildReportSearchField() {
    return TextField(
      controller: reportSearchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          reportSearchQuery = value.trim();
        });
      },
      decoration: InputDecoration(
        labelText: "Search customer name",
        hintText: "Enter a full or partial name",
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: reportSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: "Clear search",
                onPressed: () {
                  reportSearchController.clear();
                  setState(() {
                    reportSearchQuery = "";
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: _softPrimaryColor,
        labelStyle: const TextStyle(color: _mutedTextColor),
        hintStyle: const TextStyle(color: _mutedTextColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget buildReportSearchResults({
    required String date,
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    final String query = reportSearchQuery.toLowerCase();
    final results =
        consolidatedReportRecords(
            passedList: passedList,
            failedList: failedList,
            approvedList: approvedList,
            rejectedList: rejectedList,
            pendingList: pendingList,
          ).where((record) {
            return reportCustomerName(record).toLowerCase().contains(query);
          }).toList()
          ..sort((a, b) {
            return reportCustomerName(
              a,
            ).toLowerCase().compareTo(reportCustomerName(b).toLowerCase());
          });

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
              const Icon(
                Icons.manage_search_rounded,
                color: _primaryColor,
                size: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Search Results for $date",
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _softPrimaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${results.length}",
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            emptyBox(
              'No customer named “$reportSearchQuery” was found for $date.',
            )
          else
            ...results.map(buildReportSearchResultCard),
        ],
      ),
    );
  }

  Widget buildReportSearchResultCard(Map<String, dynamic> record) {
    final String name = reportCustomerName(record);
    final String status = record["status"]?.toString().trim() ?? "Unknown";
    final String queue = record["queue"]?.toString().trim() ?? "-";
    final String plate = record["plate"]?.toString().trim() ?? "-";
    final String vehicle = (record["vehicle"] ?? record["type"] ?? "-")
        .toString()
        .trim();
    final String municipality =
        record["municipality"]?.toString().trim() ?? "-";
    final String email =
        record["customerEmail"]?.toString().trim() ?? "Not available";
    final String date = record["date"]?.toString().trim() ?? selectedDate;

    final Color statusColor = switch (status.toLowerCase()) {
      "passed" || "approved" => Colors.green,
      "failed" || "rejected" => Colors.red,
      "pending" => Colors.orange,
      _ => _primaryColor,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  queue.isNotEmpty ? queue.substring(0, 1) : "-",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool useTwoColumns = constraints.maxWidth >= 360;
              final double itemWidth = useTwoColumns
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  reportSearchDetailItem("Queue Number", queue, itemWidth),
                  reportSearchDetailItem("Plate Number", plate, itemWidth),
                  reportSearchDetailItem("Vehicle", vehicle, itemWidth),
                  reportSearchDetailItem(
                    "Municipality",
                    municipality,
                    itemWidth,
                  ),
                  reportSearchDetailItem("Email", email, itemWidth),
                  reportSearchDetailItem("Report Date", date, itemWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget reportSearchDetailItem(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _mutedTextColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.isEmpty ? "-" : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildReportDetails({
    required String date,
    required int totalServed,
    required List<Map<String, dynamic>> queueItems,
    required List<Map<String, dynamic>> appointments,
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    if (!hasAnyRecordForDate(
      date: date,
      queueItems: queueItems,
      appointments: appointments,
    )) {
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
          buildReportSearchField(),
          const SizedBox(height: 16),
          if (reportSearchQuery.isNotEmpty)
            buildReportSearchResults(
              date: date,
              passedList: passedList,
              failedList: failedList,
              approvedList: approvedList,
              rejectedList: rejectedList,
              pendingList: pendingList,
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softPrimaryColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Summary for $date",
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  reportSummaryGroup(
                    title: "Queue Results",
                    icon: Icons.groups_rounded,
                    items: [
                      (
                        label: "Served",
                        value: totalServed,
                        color: _primaryColor,
                      ),
                      (
                        label: "Passed",
                        value: passedList.length,
                        color: Colors.green,
                      ),
                      (
                        label: "Failed",
                        value: failedList.length,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  reportSummaryGroup(
                    title: "Appointments",
                    icon: Icons.calendar_month_rounded,
                    items: [
                      (
                        label: "Approved",
                        value: approvedList.length,
                        color: Colors.green,
                      ),
                      (
                        label: "Rejected",
                        value: rejectedList.length,
                        color: Colors.red,
                      ),
                      (
                        label: "Pending",
                        value: pendingList.length,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
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
              title: "Approved Appointments",
              icon: Icons.verified_outlined,
              color: Colors.green,
              records: approvedList,
              emptyText: "No approved appointments for this date.",
            ),
            const SizedBox(height: 14),
            reportListSection(
              title: "Rejected Appointments",
              icon: Icons.block_rounded,
              color: Colors.red,
              records: rejectedList,
              emptyText: "No rejected appointments for this date.",
            ),
            const SizedBox(height: 14),
            reportListSection(
              title: "Pending Appointments",
              icon: Icons.pending_actions_rounded,
              color: Colors.orange,
              records: pendingList,
              emptyText: "No pending appointments for this date.",
            ),
          ],
        ],
      ),
    );
  }

  Widget reportSummaryGroup({
    required String title,
    required IconData icon,
    required List<({String label, int value, Color color})> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: _primaryColor),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "${items[index].value}",
                        style: TextStyle(
                          color: items[index].color,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[index].label,
                          style: const TextStyle(
                            color: _mutedTextColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
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

    final name =
        record["name"]?.toString() ??
        record["fullName"]?.toString() ??
        record["plate"]?.toString() ??
        "-";

    final vehicle =
        record["type"]?.toString() ?? record["vehicle"]?.toString() ?? "-";

    final source =
        record["source"]?.toString() ?? record["status"]?.toString() ?? "-";

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
        BoxShadow(color: _primaryColor.withOpacity(0.06), blurRadius: 14),
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

  Widget sectionHeader({required IconData icon, required String title}) {
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
