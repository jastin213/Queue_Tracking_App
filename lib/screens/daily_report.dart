import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/firestore_query_fields.dart';
import '../theme/app_theme.dart';
import '../widgets/analytics_line_chart.dart';
import '../widgets/app_refresh_indicator.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = AppColors.background;
const Color _primaryColor = AppColors.primary;
const Color _cardColor = AppColors.surface;
const Color _borderColor = AppColors.border;
const Color _mutedTextColor = AppColors.mutedText;
const Color _softPrimaryColor = AppColors.softPrimary;

enum _ReportSection {
  servedCustomers,
  passedCustomers,
  failedCustomers,
  approvedAppointments,
  rejectedAppointments,
  pendingAppointments,
}

class DailyReport extends StatefulWidget {
  const DailyReport({super.key});

  @override
  State<DailyReport> createState() => _DailyReportState();
}

class _DailyReportState extends State<DailyReport> {
  final TextEditingController reportSearchController = TextEditingController();

  String selectedDate = "";
  String reportSearchQuery = "";
  _ReportSection? expandedReportSection;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _selectedQueueSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _selectedAppointmentSubscription;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _selectedQueueItems = [];
  List<Map<String, dynamic>> _selectedAppointments = [];
  List<Map<String, dynamic>> _analyticsQueueItems = [];
  List<Map<String, dynamic>> _analyticsAppointments = [];
  List<Map<String, dynamic>> _searchQueueItems = [];
  List<Map<String, dynamic>> _searchAppointments = [];
  bool _queueLoading = true;
  bool _appointmentsLoading = true;
  bool _analyticsLoading = true;
  bool _searchLoading = false;
  Object? _reportError;
  Object? _searchError;
  final Set<String> _busyReportRecords = <String>{};

  @override
  void initState() {
    super.initState();
    selectedDate = todayDate();
    _listenToSelectedDate();
    _loadAnalyticsWindow();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _selectedQueueSubscription?.cancel();
    _selectedAppointmentSubscription?.cancel();
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
      setState(() {
        selectedDate = formatPickedDate(picked);
        expandedReportSection = null;
      });
      _listenToSelectedDate();
      _loadAnalyticsWindow();
    }
  }

  void toggleReportSection(_ReportSection section) {
    setState(() {
      expandedReportSection = expandedReportSection == section ? null : section;
    });
  }

  // ================= FIRESTORE QUERIES =================

  String queueDateId(String date) => date.replaceAll("/", "-");

  List<Map<String, dynamic>> queueRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        "queueId": data["queueId"] ?? doc.id,
        "_queueDocumentPath": doc.reference.path,
      };
    }).toList();
  }

  List<Map<String, dynamic>> appointmentRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        ...data,
        "appointmentId": data["appointmentId"] ?? doc.id,
        "_appointmentDocumentPath": doc.reference.path,
      };
    }).toList();
  }

  void _listenToSelectedDate() {
    _selectedQueueSubscription?.cancel();
    _selectedAppointmentSubscription?.cancel();

    if (mounted) {
      setState(() {
        _queueLoading = true;
        _appointmentsLoading = true;
        _reportError = null;
      });
    }

    final firestore = FirebaseFirestore.instance;
    _selectedQueueSubscription = firestore
        .collection("queues")
        .doc(queueDateId(selectedDate))
        .collection("items")
        .orderBy("createdAt")
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _selectedQueueItems = queueRecords(snapshot);
              _queueLoading = false;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _queueLoading = false;
              _reportError = error;
            });
          },
        );

    _selectedAppointmentSubscription = firestore
        .collection("appointments")
        .where("date", isEqualTo: selectedDate)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _selectedAppointments = appointmentRecords(snapshot);
              _appointmentsLoading = false;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _appointmentsLoading = false;
              _reportError = error;
            });
          },
        );
  }

  List<String> _analyticsDates() {
    final selected = parseDate(selectedDate);
    final firstMonth = DateTime(selected.year, selected.month - 5);
    final dates = <String>[];

    for (var monthOffset = 0; monthOffset < 6; monthOffset++) {
      final month = DateTime(firstMonth.year, firstMonth.month + monthOffset);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        dates.add("${month.month}/$day/${month.year}");
      }
    }

    return dates;
  }

  Iterable<List<String>> _queryChunks(List<String> values) sync* {
    const chunkSize = 30;
    for (var index = 0; index < values.length; index += chunkSize) {
      final end = (index + chunkSize < values.length)
          ? index + chunkSize
          : values.length;
      yield values.sublist(index, end);
    }
  }

  Future<void> _loadAnalyticsWindow({bool forceServer = false}) async {
    if (mounted) {
      setState(() {
        _analyticsLoading = true;
        _reportError = null;
      });
    }

    try {
      final options = forceServer
          ? const GetOptions(source: Source.server)
          : null;
      final firestore = FirebaseFirestore.instance;
      final dates = _analyticsDates();
      final queueFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      final appointmentFutures =
          <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      for (final chunk in _queryChunks(dates)) {
        queueFutures.add(
          firestore
              .collectionGroup("items")
              .where("date", whereIn: chunk)
              .get(options),
        );
        appointmentFutures.add(
          firestore
              .collection("appointments")
              .where("date", whereIn: chunk)
              .get(options),
        );
      }

      final results = await Future.wait([
        Future.wait(queueFutures),
        Future.wait(appointmentFutures),
      ]);
      final queueSnapshots = results[0];
      final appointmentSnapshots = results[1];

      if (!mounted) return;
      setState(() {
        _analyticsQueueItems = queueSnapshots
            .expand(queueRecords)
            .toList(growable: false);
        _analyticsAppointments = appointmentSnapshots
            .expand(appointmentRecords)
            .toList(growable: false);
        _analyticsLoading = false;
      });
    } catch (_) {
      // Collection-group filters can require a deployed Firestore index.
      // Preserve older deployments by falling back to a one-time history read.
      try {
        final options = forceServer
            ? const GetOptions(source: Source.server)
            : null;
        final results = await Future.wait([
          FirebaseFirestore.instance.collectionGroup("items").get(options),
          FirebaseFirestore.instance.collection("appointments").get(options),
        ]);
        if (!mounted) return;
        setState(() {
          _analyticsQueueItems = queueRecords(results[0]);
          _analyticsAppointments = appointmentRecords(results[1]);
          _analyticsLoading = false;
          _reportError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _analyticsLoading = false;
          _reportError = error;
        });
      }
    }
  }

  Future<void> refreshReport() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final results = await Future.wait([
        firestore
            .collection("queues")
            .doc(queueDateId(selectedDate))
            .collection("items")
            .orderBy("createdAt")
            .get(const GetOptions(source: Source.server)),
        firestore
            .collection("appointments")
            .where("date", isEqualTo: selectedDate)
            .get(const GetOptions(source: Source.server)),
      ]);

      if (mounted) {
        setState(() {
          _selectedQueueItems = queueRecords(results[0]);
          _selectedAppointments = appointmentRecords(results[1]);
          _reportError = null;
        });
      }
      await _loadAnalyticsWindow(forceServer: true);
      if (reportSearchQuery.isNotEmpty) {
        await _searchReports(reportSearchQuery);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _reportError = error);
      rethrow;
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

  Future<Uint8List> generateDailyPdf({
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

    return doc.save();
  }

  String dailyPdfFileName() {
    return "NPJN_Daily_Report_${selectedDate.replaceAll('/', '-')}.pdf";
  }

  Future<void> printDailyPdf({
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
  }) async {
    final bytes = await generateDailyPdf(
      passedList: passedList,
      failedList: failedList,
    );
    await Printing.layoutPdf(
      name: dailyPdfFileName(),
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  Future<void> downloadDailyPdf({
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
  }) async {
    final bytes = await generateDailyPdf(
      passedList: passedList,
      failedList: failedList,
    );
    await saveOrSharePdf(bytes: bytes, fileName: dailyPdfFileName());
  }

  Future<Uint8List> generateMonthlyPdf({
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

    return doc.save();
  }

  String monthlyPdfFileName() {
    return "NPJN_Monthly_Report_${currentMonthKey()}.pdf";
  }

  Future<void> printMonthlyPdf({
    required List<Map<String, dynamic>> queueItems,
  }) async {
    final bytes = await generateMonthlyPdf(queueItems: queueItems);
    await Printing.layoutPdf(
      name: monthlyPdfFileName(),
      onLayout: (PdfPageFormat format) async => bytes,
    );
  }

  Future<void> downloadMonthlyPdf({
    required List<Map<String, dynamic>> queueItems,
  }) async {
    final bytes = await generateMonthlyPdf(queueItems: queueItems);
    await saveOrSharePdf(bytes: bytes, fileName: monthlyPdfFileName());
  }

  Future<void> saveOrSharePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final success = await Printing.sharePdf(bytes: bytes, filename: fileName);
      if (!success) throw StateError("The PDF could not be saved.");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? "$fileName download started."
                : "$fileName is ready to save or share.",
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Unable to download the PDF. Please try again."),
        ),
      );
    }
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
    final queueItems = _selectedQueueItems;
    final appointments = _selectedAppointments;
    final passedList = getPassedByDate(queueItems, selectedDate);
    final failedList = getFailedByDate(queueItems, selectedDate);
    final approvedList = getApprovedByDate(appointments, selectedDate);
    final rejectedList = getRejectedByDate(appointments, selectedDate);
    final pendingList = getPendingByDate(appointments, selectedDate);
    final totalServed = passedList.length + failedList.length;
    final isLoading = _queueLoading || _appointmentsLoading;

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
                final bool desktopWeb = kIsWeb && constraints.maxWidth >= 900;

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
                          else if (_reportError != null)
                            buildErrorCard(_reportError.toString())
                          else ...[
                            buildPdfExportCard(
                              passedList: passedList,
                              failedList: failedList,
                              queueItems: _analyticsQueueItems,
                            ),

                            const SizedBox(height: 14),

                            buildSeasonalDetectionCard(
                              wide: wide,
                              queueItems: _analyticsQueueItems,
                              appointments: _analyticsAppointments,
                            ),
                            if (_analyticsLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: _primaryColor,
                                  backgroundColor: _softPrimaryColor,
                                ),
                              ),

                            const SizedBox(height: 14),

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
            title: "Printable & Downloadable PDF Reports",
          ),
          const SizedBox(height: 10),
          const Text(
            "Print a report or download a soft-copy PDF to save, email, or send to LTO. PDF exports include only Passed and Failed records.",
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool twoColumns = constraints.maxWidth >= 760;
              final double groupWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  buildPdfReportActionGroup(
                    width: groupWidth,
                    title: "Daily Report",
                    subtitle: selectedDate,
                    icon: Icons.today_rounded,
                    color: _primaryColor,
                    onPrint: () => printDailyPdf(
                      passedList: passedList,
                      failedList: failedList,
                    ),
                    onDownload: () => downloadDailyPdf(
                      passedList: passedList,
                      failedList: failedList,
                    ),
                  ),
                  buildPdfReportActionGroup(
                    width: groupWidth,
                    title: "Monthly Report",
                    subtitle: monthLabel,
                    icon: Icons.calendar_view_month_rounded,
                    color: Colors.green,
                    onPrint: () => printMonthlyPdf(queueItems: queueItems),
                    onDownload: () =>
                        downloadMonthlyPdf(queueItems: queueItems),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildPdfReportActionGroup({
    required double width,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Future<void> Function() onPrint,
    required Future<void> Function() onDownload,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(13),
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
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final printButton = OutlinedButton.icon(
                  onPressed: () async => onPrint(),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text("PRINT"),
                );
                final downloadButton = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async => onDownload(),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text("DOWNLOAD"),
                );

                if (constraints.maxWidth < 320) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: printButton),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: downloadButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: printButton),
                    const SizedBox(width: 9),
                    Expanded(child: downloadButton),
                  ],
                );
              },
            ),
          ],
        ),
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
      failedValues: visibleEntries
          .map((entry) => entry.value["failed"] ?? 0)
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

  // ================= REPORT DETAILS =================

  String reportCustomerName(Map<String, dynamic> record) {
    return (record["name"] ?? record["fullName"] ?? record["plate"] ?? "-")
        .toString()
        .trim();
  }

  String normalizedPlateSearchValue(dynamic value) {
    if (value == null) return "";

    return value.toString().trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
  }

  String normalizedNameSearchValue(dynamic value) {
    if (value == null) return "";

    return value.toString().trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  Set<String> legacyNameSearchPrefixes(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return const {};

    final String titleCase = trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return "${word[0].toUpperCase()}${word.substring(1).toLowerCase()}";
        })
        .join(" ");

    return {trimmed, trimmed.toLowerCase(), trimmed.toUpperCase(), titleCase};
  }

  bool recordMatchesReportSearch(
    Map<String, dynamic> record,
    String plateQuery,
    String nameQuery,
  ) {
    final String plate = normalizedPlateSearchValue(record["plate"]);
    final String name = normalizedNameSearchValue(reportCustomerName(record));

    return (plateQuery.isNotEmpty && plate.contains(plateQuery)) ||
        (nameQuery.isNotEmpty && name.contains(nameQuery));
  }

  bool isCurrentReportSearch(String plateQuery, String nameQuery) {
    return normalizedPlateSearchValue(reportSearchController.text) ==
            plateQuery &&
        normalizedNameSearchValue(reportSearchController.text) == nameQuery;
  }

  void _scheduleReportSearch(String value) {
    _searchDebounce?.cancel();
    final String plateQuery = normalizedPlateSearchValue(value);
    final String nameQuery = normalizedNameSearchValue(value);
    final bool hasQuery = plateQuery.isNotEmpty || nameQuery.isNotEmpty;

    setState(() {
      reportSearchQuery = value.trim();
      _searchError = null;
      if (!hasQuery) {
        _searchLoading = false;
        _searchQueueItems = [];
        _searchAppointments = [];
      } else {
        _searchLoading = true;
      }
    });

    if (!hasQuery) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchReports(value.trim()),
    );
  }

  Future<void> _searchReports(String value) async {
    final String plateQuery = normalizedPlateSearchValue(value);
    final String nameQuery = normalizedNameSearchValue(value);
    if (plateQuery.isEmpty && nameQuery.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final queueQueries = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
      final appointmentQueries =
          <Future<QuerySnapshot<Map<String, dynamic>>>>[];

      if (plateQuery.isNotEmpty) {
        queueQueries.add(
          firestore
              .collectionGroup("items")
              .where("plateNormalized", isGreaterThanOrEqualTo: plateQuery)
              .where("plateNormalized", isLessThan: "$plateQuery\uf8ff")
              .limit(50)
              .get(),
        );
        appointmentQueries.add(
          firestore
              .collection("appointments")
              .where("plateNormalized", isGreaterThanOrEqualTo: plateQuery)
              .where("plateNormalized", isLessThan: "$plateQuery\uf8ff")
              .limit(50)
              .get(),
        );
      }

      if (nameQuery.isNotEmpty) {
        queueQueries.add(
          firestore
              .collectionGroup("items")
              .where("nameNormalized", isGreaterThanOrEqualTo: nameQuery)
              .where("nameNormalized", isLessThan: "$nameQuery\uf8ff")
              .limit(50)
              .get(),
        );
        appointmentQueries.add(
          firestore
              .collection("appointments")
              .where("nameNormalized", isGreaterThanOrEqualTo: nameQuery)
              .where("nameNormalized", isLessThan: "$nameQuery\uf8ff")
              .limit(50)
              .get(),
        );
      }

      // Older records only have `plate`; exact lookup keeps them searchable.
      if (plateQuery.length >= 6) {
        queueQueries.add(
          firestore
              .collectionGroup("items")
              .where("plate", isEqualTo: plateQuery)
              .limit(50)
              .get(),
        );
        appointmentQueries.add(
          firestore
              .collection("appointments")
              .where("plate", isEqualTo: plateQuery)
              .limit(50)
              .get(),
        );
      }

      // Legacy records may not have `nameNormalized`, so query common casing
      // variants of their existing name fields as well.
      for (final prefix in legacyNameSearchPrefixes(value)) {
        queueQueries.add(
          firestore
              .collectionGroup("items")
              .where("name", isGreaterThanOrEqualTo: prefix)
              .where("name", isLessThan: "$prefix\uf8ff")
              .limit(50)
              .get(),
        );
        appointmentQueries.add(
          firestore
              .collection("appointments")
              .where("fullName", isGreaterThanOrEqualTo: prefix)
              .where("fullName", isLessThan: "$prefix\uf8ff")
              .limit(50)
              .get(),
        );
      }

      final results = await Future.wait([
        Future.wait(queueQueries),
        Future.wait(appointmentQueries),
      ]);
      if (!mounted || !isCurrentReportSearch(plateQuery, nameQuery)) return;

      final queueSnapshots = results[0];
      final appointmentSnapshots = results[1];
      final queueById = <String, Map<String, dynamic>>{};
      final appointmentsById = <String, Map<String, dynamic>>{};

      for (final record in queueSnapshots.expand(queueRecords)) {
        if (!recordMatchesReportSearch(record, plateQuery, nameQuery)) continue;
        final key =
            "${record["date"]}:"
            "${record["queueId"] ?? record["queue"]}";
        queueById[key] = record;
      }
      for (final record in appointmentSnapshots.expand(appointmentRecords)) {
        if (!recordMatchesReportSearch(record, plateQuery, nameQuery)) continue;
        final key =
            record["appointmentId"]?.toString() ??
            "${record["date"]}:${record["queue"]}";
        appointmentsById[key] = record;
      }

      setState(() {
        _searchQueueItems = queueById.values.toList(growable: false);
        _searchAppointments = appointmentsById.values.toList(growable: false);
        _searchLoading = false;
        _searchError = null;
      });
    } catch (_) {
      if (!mounted || !isCurrentReportSearch(plateQuery, nameQuery)) return;
      try {
        final snapshots = await Future.wait([
          FirebaseFirestore.instance.collectionGroup("items").get(),
          FirebaseFirestore.instance.collection("appointments").get(),
        ]);
        if (!mounted || !isCurrentReportSearch(plateQuery, nameQuery)) return;
        final queueSearchResults = queueRecords(snapshots[0])
            .where(
              (item) => recordMatchesReportSearch(item, plateQuery, nameQuery),
            )
            .toList(growable: false);
        final appointmentSearchResults = appointmentRecords(snapshots[1])
            .where(
              (item) => recordMatchesReportSearch(item, plateQuery, nameQuery),
            )
            .toList(growable: false);
        setState(() {
          _searchQueueItems = queueSearchResults;
          _searchAppointments = appointmentSearchResults;
          _searchLoading = false;
          _searchError = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _searchLoading = false;
          _searchError = error;
        });
      }
    }
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

  String reportCustomerType(Map<String, dynamic> record) {
    final String source =
        record["source"]?.toString().trim().toLowerCase() ?? "";
    final String appointmentId =
        record["appointmentId"]?.toString().trim() ?? "";
    final String appointmentPath =
        record["_appointmentDocumentPath"]?.toString().trim() ?? "";

    if (source == "appointment" ||
        appointmentId.isNotEmpty ||
        appointmentPath.isNotEmpty) {
      return "Appointment";
    }

    return "Walk-in";
  }

  String reportRecordKey(Map<String, dynamic> record) {
    final String queuePath =
        record["_queueDocumentPath"]?.toString().trim() ?? "";
    final String appointmentPath =
        record["_appointmentDocumentPath"]?.toString().trim() ?? "";

    if (queuePath.isNotEmpty) return queuePath;
    if (appointmentPath.isNotEmpty) return appointmentPath;

    return "${record["date"]}:${record["queue"]}:"
        "${record["appointmentId"]}:${reportCustomerName(record)}";
  }

  DocumentReference<Map<String, dynamic>>? reportAppointmentRef(
    Map<String, dynamic> record,
  ) {
    final String path =
        record["_appointmentDocumentPath"]?.toString().trim() ?? "";
    if (path.isNotEmpty) return FirebaseFirestore.instance.doc(path);

    final String appointmentId =
        record["appointmentId"]?.toString().trim() ?? "";
    if (appointmentId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection("appointments")
        .doc(appointmentId);
  }

  Future<DocumentReference<Map<String, dynamic>>?> reportQueueRef(
    Map<String, dynamic> record,
  ) async {
    final String path = record["_queueDocumentPath"]?.toString().trim() ?? "";
    if (path.isNotEmpty) return FirebaseFirestore.instance.doc(path);

    final String date = record["date"]?.toString().trim() ?? "";
    final String queue = record["queue"]?.toString().trim() ?? "";
    final String appointmentId =
        record["appointmentId"]?.toString().trim() ?? "";
    if (date.isEmpty || queue.isEmpty || appointmentId.isEmpty) return null;

    final candidate = FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(date))
        .collection("items")
        .doc(queue);
    final snapshot = await candidate.get();
    final linkedAppointmentId =
        snapshot.data()?["appointmentId"]?.toString().trim() ?? "";

    return snapshot.exists && linkedAppointmentId == appointmentId
        ? candidate
        : null;
  }

  String editableReportValue(dynamic value) {
    final String text = value?.toString().trim() ?? "";
    return text == "-" || text == "Not available" ? "" : text;
  }

  String normalizedEditablePlate(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Future<void> showEditReportRecordDialog(Map<String, dynamic> record) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: editableReportValue(record["name"] ?? record["fullName"]),
    );
    final plateController = TextEditingController(
      text: editableReportValue(record["plate"]),
    );
    final municipalityController = TextEditingController(
      text: editableReportValue(record["municipality"]),
    );
    final emailController = TextEditingController(
      text: editableReportValue(record["customerEmail"]),
    );
    final String queue = record["queue"]?.toString().trim() ?? "-";

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            InputDecoration fieldDecoration({
              required String label,
              required IconData icon,
              String? hint,
            }) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: Icon(icon),
                filled: true,
                fillColor: _backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                "Edit Customer - $queue",
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: fieldDecoration(
                            label: "Customer Name",
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? "Customer name is required."
                              : null,
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: plateController,
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 7,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(7),
                          ],
                          decoration: fieldDecoration(
                            label: "Plate Number",
                            hint: "ABC1234",
                            icon: Icons.pin_outlined,
                          ).copyWith(counterText: ""),
                          validator: (value) {
                            final plate = normalizedEditablePlate(value ?? "");
                            return RegExp(r'^[A-Z0-9]{6,7}$').hasMatch(plate)
                                ? null
                                : "Enter exactly 6–7 letters and numbers.";
                          },
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: municipalityController,
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: fieldDecoration(
                            label: "Municipality",
                            icon: Icons.location_city_outlined,
                          ),
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: emailController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.emailAddress,
                          decoration: fieldDecoration(
                            label: "Email (optional)",
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? "";
                            if (email.isEmpty) return null;
                            return RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)
                                ? null
                                : "Enter a valid email address.";
                          },
                        ),
                        const SizedBox(height: 13),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _softPrimaryColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Text(
                            "Queue number, date, result, customer type, and "
                            "vehicle type stay unchanged.",
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              actions: [
                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final success = await updateReportRecord(
                            record: record,
                            name: nameController.text.trim(),
                            plate: normalizedEditablePlate(
                              plateController.text,
                            ),
                            municipality: municipalityController.text.trim(),
                            email: emailController.text.trim(),
                          );

                          if (!dialogContext.mounted) return;
                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text("SAVE CHANGES"),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    plateController.dispose();
    municipalityController.dispose();
    emailController.dispose();
  }

  Future<bool> updateReportRecord({
    required Map<String, dynamic> record,
    required String name,
    required String plate,
    required String municipality,
    required String email,
  }) async {
    final String key = reportRecordKey(record);
    final String date = record["date"]?.toString().trim() ?? "";

    setState(() => _busyReportRecords.add(key));
    try {
      final queueRef = await reportQueueRef(record);
      final appointmentRef = reportAppointmentRef(record);
      final queueSnapshot = await queueRef?.get();
      final appointmentSnapshot = await appointmentRef?.get();
      final hasQueue = queueSnapshot?.exists ?? false;
      final hasAppointment = appointmentSnapshot?.exists ?? false;

      if (!hasQueue && !hasAppointment) {
        throw StateError("The report record no longer exists.");
      }

      final batch = FirebaseFirestore.instance.batch();
      final queryFields = firestoreQueryFields(
        date: date,
        plate: plate,
        name: name,
      );

      if (hasQueue && queueRef != null) {
        batch.update(queueRef, {
          "name": name,
          "plate": plate,
          "municipality": municipality,
          "customerEmail": email,
          ...queryFields,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
      if (hasAppointment && appointmentRef != null) {
        batch.update(appointmentRef, {
          "fullName": name,
          "plate": plate,
          "municipality": municipality,
          "customerEmail": email,
          ...queryFields,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await refreshReportAfterMutation();

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Customer details updated successfully.")),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to update customer details: $error")),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busyReportRecords.remove(key));
    }
  }

  Future<void> showDeleteReportRecordDialog(Map<String, dynamic> record) async {
    final String name = reportCustomerName(record);
    final String queue = record["queue"]?.toString().trim() ?? "-";
    final String type = reportCustomerType(record);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          "Delete Customer Record?",
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900),
        ),
        content: Text(
          "Permanently delete $queue for $name ($type)? Linked queue and "
          "appointment records, including uploaded appointment documents, "
          "will also be removed. The customer's login account will not be "
          "deleted. This action cannot be undone.",
          style: const TextStyle(color: _mutedTextColor, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirmed == true) await deleteReportRecord(record);
  }

  Future<void> deleteFirestoreRefs(
    List<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (int start = 0; start < references.length; start += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final int end = start + 400 < references.length
          ? start + 400
          : references.length;
      for (final reference in references.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteAppointmentFiles(
    DocumentReference<Map<String, dynamic>> appointmentRef,
    Map<String, dynamic> appointment,
  ) async {
    final storagePaths = <String>{
      for (final field in const [
        "idStoragePath",
        "orStoragePath",
        "crStoragePath",
      ])
        if ((appointment[field]?.toString().trim() ?? "").isNotEmpty)
          appointment[field].toString().trim(),
    };

    for (final path in storagePaths) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } on FirebaseException catch (error) {
        if (error.code != "object-not-found") rethrow;
      }
    }

    final documents = await appointmentRef.collection("documents").get();
    final documentRefs = <DocumentReference<Map<String, dynamic>>>[];
    for (final document in documents.docs) {
      final chunks = await document.reference.collection("chunks").get();
      await deleteFirestoreRefs(
        chunks.docs.map((chunk) => chunk.reference).toList(),
      );
      documentRefs.add(document.reference);
    }
    await deleteFirestoreRefs(documentRefs);
  }

  Future<void> deleteReportRecord(Map<String, dynamic> record) async {
    final String key = reportRecordKey(record);
    final String queue = record["queue"]?.toString().trim() ?? "Customer";

    setState(() => _busyReportRecords.add(key));
    try {
      final queueRef = await reportQueueRef(record);
      final appointmentRef = reportAppointmentRef(record);
      final appointmentSnapshot = await appointmentRef?.get();

      if (appointmentRef != null && (appointmentSnapshot?.exists ?? false)) {
        await deleteAppointmentFiles(
          appointmentRef,
          appointmentSnapshot!.data() ?? record,
        );
      }

      final batch = FirebaseFirestore.instance.batch();
      if (queueRef != null) batch.delete(queueRef);
      if (appointmentRef != null) batch.delete(appointmentRef);
      if (queueRef == null && appointmentRef == null) {
        throw StateError("The report record could not be located.");
      }
      await batch.commit();
      await refreshReportAfterMutation();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$queue was permanently deleted.")),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to delete customer record: $error")),
        );
      }
    } finally {
      if (mounted) setState(() => _busyReportRecords.remove(key));
    }
  }

  Future<void> refreshReportAfterMutation() async {
    await _loadAnalyticsWindow(forceServer: true);
    final String query = reportSearchController.text.trim();
    if (query.isNotEmpty) await _searchReports(query);
  }

  Widget buildReportSearchField() {
    return TextField(
      controller: reportSearchController,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      onChanged: _scheduleReportSearch,
      decoration: InputDecoration(
        labelText: "Search plate number or customer name",
        hintText: "Enter a plate number or name",
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: reportSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: "Clear search",
                onPressed: () {
                  _searchDebounce?.cancel();
                  reportSearchController.clear();
                  setState(() {
                    reportSearchQuery = "";
                    _searchLoading = false;
                    _searchError = null;
                    _searchQueueItems = [];
                    _searchAppointments = [];
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

  Widget buildReportSearchResults() {
    final queueItems = _searchQueueItems;
    final appointments = _searchAppointments;
    final allPassed = queueItems.where((record) {
      return record["status"]?.toString().trim().toLowerCase() == "passed";
    }).toList();
    final allFailed = queueItems.where((record) {
      return record["status"]?.toString().trim().toLowerCase() == "failed";
    }).toList();
    final allApproved = appointments.where((record) {
      return record["status"]?.toString().trim().toLowerCase() == "approved";
    }).toList();
    final allRejected = appointments.where((record) {
      return record["status"]?.toString().trim().toLowerCase() == "rejected";
    }).toList();
    final allPending = appointments.where((record) {
      return record["status"]?.toString().trim().toLowerCase() == "pending";
    }).toList();
    final String plateQuery = normalizedPlateSearchValue(reportSearchQuery);
    final String nameQuery = normalizedNameSearchValue(reportSearchQuery);
    final results =
        consolidatedReportRecords(
            passedList: allPassed,
            failedList: allFailed,
            approvedList: allApproved,
            rejectedList: allRejected,
            pendingList: allPending,
          ).where((record) {
            return recordMatchesReportSearch(record, plateQuery, nameQuery);
          }).toList()
          ..sort((a, b) {
            final String aDate = a["date"]?.toString() ?? "";
            final String bDate = b["date"]?.toString() ?? "";
            final int dateComparison = parseDate(
              bDate,
            ).compareTo(parseDate(aDate));

            if (dateComparison != 0) return dateComparison;

            return (a["queue"]?.toString() ?? "").compareTo(
              b["queue"]?.toString() ?? "",
            );
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
                  "Search Results — All Dates",
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
          if (_searchLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            )
          else if (_searchError != null)
            emptyBox("Search is temporarily unavailable. Please try again.")
          else if (results.isEmpty)
            emptyBox(
              'No records found for “$reportSearchQuery” by plate or name '
              'across all dates.',
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
    final String customerType = reportCustomerType(record);
    final bool isBusy = _busyReportRecords.contains(reportRecordKey(record));

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
                  reportSearchDetailItem(
                    "Customer Type",
                    customerType,
                    itemWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(color: _borderColor, height: 1),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => showEditReportRecordDialog(record),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("EDIT DETAILS"),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                  ),
                  onPressed: isBusy
                      ? null
                      : () => showDeleteReportRecordDialog(record),
                  icon: isBusy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(isBusy ? "WORKING..." : "DELETE RECORD"),
                ),
              ],
            ),
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
    final bool hasSelectedDateRecords = hasAnyRecordForDate(
      date: date,
      queueItems: queueItems,
      appointments: appointments,
    );

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
            buildReportSearchResults()
          else if (!hasSelectedDateRecords)
            emptyBox("No report records for $date.")
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
                        icon: Icons.groups_rounded,
                        section: _ReportSection.servedCustomers,
                      ),
                      (
                        label: "Passed",
                        value: passedList.length,
                        color: Colors.green,
                        icon: Icons.check_circle_outline_rounded,
                        section: _ReportSection.passedCustomers,
                      ),
                      (
                        label: "Failed",
                        value: failedList.length,
                        color: Colors.red,
                        icon: Icons.cancel_outlined,
                        section: _ReportSection.failedCustomers,
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
                        icon: Icons.verified_outlined,
                        section: _ReportSection.approvedAppointments,
                      ),
                      (
                        label: "Rejected",
                        value: rejectedList.length,
                        color: Colors.red,
                        icon: Icons.block_rounded,
                        section: _ReportSection.rejectedAppointments,
                      ),
                      (
                        label: "Pending",
                        value: pendingList.length,
                        color: Colors.orange,
                        icon: Icons.pending_actions_rounded,
                        section: _ReportSection.pendingAppointments,
                      ),
                    ],
                  ),
                  if (expandedReportSection != null) ...[
                    const SizedBox(height: 14),
                    buildExpandedSummaryRecords(
                      section: expandedReportSection!,
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
          ],
        ],
      ),
    );
  }

  Widget reportSummaryGroup({
    required String title,
    required IconData icon,
    required List<
      ({
        String label,
        int value,
        Color color,
        IconData icon,
        _ReportSection section,
      })
    >
    items,
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => toggleReportSection(items[index].section),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: expandedReportSection == items[index].section
                            ? items[index].color.withValues(alpha: 0.07)
                            : _cardColor,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: expandedReportSection == items[index].section
                              ? items[index].color
                              : _borderColor,
                          width: expandedReportSection == items[index].section
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: items[index].color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              items[index].icon,
                              color: items[index].color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 5),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  items[index].label,
                                  style: const TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                AnimatedRotation(
                                  turns:
                                      expandedReportSection ==
                                          items[index].section
                                      ? 0.5
                                      : 0,
                                  duration: const Duration(milliseconds: 180),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _mutedTextColor,
                                    size: 16,
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
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget buildExpandedSummaryRecords({
    required _ReportSection section,
    required List<Map<String, dynamic>> passedList,
    required List<Map<String, dynamic>> failedList,
    required List<Map<String, dynamic>> approvedList,
    required List<Map<String, dynamic>> rejectedList,
    required List<Map<String, dynamic>> pendingList,
  }) {
    switch (section) {
      case _ReportSection.servedCustomers:
        return reportRecordsPanel(
          title: "Served Customers",
          icon: Icons.groups_rounded,
          color: _primaryColor,
          records: [...passedList, ...failedList],
          emptyText: "No served customers for this date.",
        );
      case _ReportSection.passedCustomers:
        return reportRecordsPanel(
          title: "Passed Customers",
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green,
          records: passedList,
          emptyText: "No passed customers for this date.",
        );
      case _ReportSection.failedCustomers:
        return reportRecordsPanel(
          title: "Failed Customers",
          icon: Icons.cancel_outlined,
          color: Colors.red,
          records: failedList,
          emptyText: "No failed customers for this date.",
        );
      case _ReportSection.approvedAppointments:
        return reportRecordsPanel(
          title: "Approved Appointments",
          icon: Icons.verified_outlined,
          color: Colors.green,
          records: approvedList,
          emptyText: "No approved appointments for this date.",
        );
      case _ReportSection.rejectedAppointments:
        return reportRecordsPanel(
          title: "Rejected Appointments",
          icon: Icons.block_rounded,
          color: Colors.red,
          records: rejectedList,
          emptyText: "No rejected appointments for this date.",
        );
      case _ReportSection.pendingAppointments:
        return reportRecordsPanel(
          title: "Pending Appointments",
          icon: Icons.pending_actions_rounded,
          color: Colors.orange,
          records: pendingList,
          emptyText: "No pending appointments for this date.",
        );
    }
  }

  Widget reportRecordsPanel({
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                "${records.length} record${records.length == 1 ? "" : "s"}",
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: "Hide records",
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() {
                    expandedReportSection = null;
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          const Divider(height: 18, color: _borderColor),
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
