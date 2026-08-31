import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../services/firestore_query_fields.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_responsive_content.dart';
import 'book_appointment.dart';
import 'admin_page.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = AppColors.background;
const Color _primaryColor = AppColors.primary;
const Color _cardColor = AppColors.surface;
const Color _borderColor = AppColors.border;
const Color _mutedTextColor = AppColors.mutedText;
const Color _softPrimaryColor = AppColors.softPrimary;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  DateTime calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedCalendarDate;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _monthSubscriptions = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSubscription;
  final Map<int, List<Map<String, dynamic>>> _monthAppointmentChunks = {};
  List<Map<String, dynamic>> _pendingAppointments = [];
  int _monthListenGeneration = 0;
  bool _appointmentsLoading = true;
  bool _isRefreshing = false;
  Object? _appointmentsError;
  String? _expandedOverviewStatus;

  @override
  void initState() {
    super.initState();
    _listenToPendingAppointments();
    _listenToAppointmentMonth();
  }

  @override
  void dispose() {
    _pendingSubscription?.cancel();
    for (final subscription in _monthSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  // ================= FIRESTORE HELPERS =================

  String queueDateId(String date) {
    return date.replaceAll("/", "-");
  }

  CollectionReference<Map<String, dynamic>> queueItemsRef(String date) {
    return FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(date))
        .collection("items");
  }

  List<Map<String, dynamic>> appointmentRecords(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, "appointmentId": data["appointmentId"] ?? doc.id};
    }).toList();

    list.sort((a, b) {
      final aDate = a["createdAt"];
      final bDate = b["createdAt"];
      if (aDate is Timestamp && bDate is Timestamp) {
        return bDate.compareTo(aDate);
      }
      return 0;
    });
    return list;
  }

  List<String> _calendarMonthDates() {
    final days = DateTime(calendarMonth.year, calendarMonth.month + 1, 0).day;
    return [
      for (var day = 1; day <= days; day++)
        "${calendarMonth.month}/$day/${calendarMonth.year}",
    ];
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

  void _listenToPendingAppointments() {
    _pendingSubscription?.cancel();
    _pendingSubscription = FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: "Pending")
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            final records = appointmentRecords(snapshot);
            setState(() {
              _pendingAppointments = records;
              _appointmentsLoading = false;
              _appointmentsError = null;
            });
            pendingBookings.value = records;
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _appointmentsLoading = false;
              _appointmentsError = error;
            });
          },
        );
  }

  void _listenToAppointmentMonth() {
    final generation = ++_monthListenGeneration;
    for (final subscription in _monthSubscriptions) {
      subscription.cancel();
    }
    _monthSubscriptions.clear();
    _monthAppointmentChunks.clear();
    if (mounted) {
      setState(() {
        _appointmentsLoading = true;
        _appointmentsError = null;
      });
    }

    var chunkIndex = 0;
    for (final dates in _queryChunks(_calendarMonthDates())) {
      final index = chunkIndex++;
      final subscription = FirebaseFirestore.instance
          .collection("appointments")
          .where("date", whereIn: dates)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted || generation != _monthListenGeneration) return;
              setState(() {
                _monthAppointmentChunks[index] = appointmentRecords(snapshot);
                _appointmentsLoading =
                    _monthAppointmentChunks.length < chunkIndex;
                _appointmentsError = null;
              });
            },
            onError: (Object error) {
              if (!mounted || generation != _monthListenGeneration) return;
              setState(() {
                _appointmentsLoading = false;
                _appointmentsError = error;
              });
            },
          );
      _monthSubscriptions.add(subscription);
    }
  }

  List<Map<String, dynamic>> get _monthAppointments {
    final byId = <String, Map<String, dynamic>>{};
    for (final record in _monthAppointmentChunks.values.expand(
      (records) => records,
    )) {
      final key =
          record["appointmentId"]?.toString() ??
          "${record["date"]}:${record["queue"]}";
      byId[key] = record;
    }
    return byId.values.toList(growable: false);
  }

  int _monthStatusCount(String status) {
    final normalizedStatus = status.trim().toLowerCase();
    return _monthAppointments.where((appointment) {
      return appointment["status"]?.toString().trim().toLowerCase() ==
          normalizedStatus;
    }).length;
  }

  List<Map<String, dynamic>> get _loadedAppointments {
    final byId = <String, Map<String, dynamic>>{};
    for (final record in [..._monthAppointments, ..._pendingAppointments]) {
      final key =
          record["appointmentId"]?.toString() ??
          "${record["date"]}:${record["queue"]}";
      byId[key] = record;
    }
    return byId.values.toList(growable: false);
  }

  Future<void> refreshAppointments() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);

    try {
      final collection = FirebaseFirestore.instance.collection("appointments");
      final monthFutures = _queryChunks(_calendarMonthDates())
          .map(
            (dates) => collection
                .where("date", whereIn: dates)
                .get(const GetOptions(source: Source.server)),
          )
          .toList();
      final results = await Future.wait([
        Future.wait(monthFutures),
        collection
            .where("status", isEqualTo: "Pending")
            .get(const GetOptions(source: Source.server)),
      ]);
      final monthSnapshots =
          results[0] as List<QuerySnapshot<Map<String, dynamic>>>;
      final pendingSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _monthAppointmentChunks
            ..clear()
            ..addEntries(
              monthSnapshots.asMap().entries.map(
                (entry) => MapEntry(entry.key, appointmentRecords(entry.value)),
              ),
            );
          _pendingAppointments = appointmentRecords(pendingSnapshot);
          _appointmentsError = null;
        });
        pendingBookings.value = _pendingAppointments;
      }
    } catch (error) {
      if (mounted) setState(() => _appointmentsError = error);
      rethrow;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> refreshAppointmentsFromWebButton() async {
    try {
      await refreshAppointments();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Appointments refreshed just now.")),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text("Unable to refresh appointments. Please try again."),
          ),
        );
    }
  }

  // ================= CHECK IF QUEUE IS ALREADY USED =================

  bool isQueueAlreadyUsedLocally(Map<String, dynamic> booking) {
    final String bookingQueue = booking["queue"]?.toString() ?? "";
    final String bookingDate = booking["date"]?.toString() ?? "";

    bool inIssued =
        issuedQueueCodesNotifier.value[bookingDate]?.contains(bookingQueue) ??
        false;

    bool inWaitingQueue = waitingQueueNotifier.value.any((customer) {
      return customer["queue"] == bookingQueue &&
          customer["date"] == bookingDate;
    });

    bool inNowServing =
        nowServingNotifier.value != null &&
        nowServingNotifier.value!["queue"] == bookingQueue &&
        nowServingNotifier.value!["date"] == bookingDate;

    return inIssued || inWaitingQueue || inNowServing;
  }

  Future<bool> isQueueAlreadyUsedInApprovedAppointments(
    Map<String, dynamic> booking,
  ) async {
    final String bookingQueue = booking["queue"]?.toString() ?? "";
    final String bookingDate = booking["date"]?.toString() ?? "";
    final String appointmentId = booking["appointmentId"]?.toString() ?? "";

    if (bookingQueue.isEmpty || bookingDate.isEmpty) {
      return false;
    }

    final query = await FirebaseFirestore.instance
        .collection("appointments")
        .where("date", isEqualTo: bookingDate)
        .where("queue", isEqualTo: bookingQueue)
        .where("status", isEqualTo: "Approved")
        .get();

    for (final doc in query.docs) {
      if (doc.id != appointmentId) {
        return true;
      }
    }

    return false;
  }

  Future<bool> isQueueAlreadyUsedInFirestoreQueue({
    required String date,
    required String queue,
  }) async {
    if (date.isEmpty || queue.isEmpty) {
      return false;
    }

    final doc = await queueItemsRef(date).doc(queue).get();

    if (!doc.exists) {
      return false;
    }

    final data = doc.data();

    if (data == null) {
      return false;
    }

    final status = data["status"]?.toString() ?? "";

    return status == "Waiting" ||
        status == "Now Serving" ||
        status == "Skipped";
  }

  void markQueueCodeAsIssuedForBooking(String date, String queueCode) {
    final updatedIssued = Map<String, List<String>>.from(
      issuedQueueCodesNotifier.value,
    );

    final issuedList = List<String>.from(updatedIssued[date] ?? []);

    if (!issuedList.contains(queueCode)) {
      issuedList.add(queueCode);
    }

    updatedIssued[date] = issuedList;
    issuedQueueCodesNotifier.value = updatedIssued;
  }

  void addApprovedAppointmentToLocalQueue(Map<String, dynamic> approved) {
    final String queue = approved["queue"]?.toString() ?? "";
    final String date = approved["date"]?.toString() ?? "";

    final alreadyInWaiting = waitingQueueNotifier.value.any((customer) {
      return customer["queue"] == queue && customer["date"] == date;
    });

    if (!alreadyInWaiting) {
      waitingQueueNotifier.value = [
        ...waitingQueueNotifier.value,
        {
          "queueId": approved["queue"],
          "queue": approved["queue"],
          "name": approved["fullName"] ?? approved["plate"],
          "type": approved["vehicle"],
          "date": approved["date"],
          "source": "Appointment",
          "municipality": approved["municipality"],
          "status": "Waiting",
          "appointmentId": approved["appointmentId"],
          "customerId": approved["customerId"],
          "customerEmail": approved["customerEmail"],
          "plate": approved["plate"],
        },
      ];
    }
  }

  Future<void> addApprovedAppointmentToFirestoreQueue(
    Map<String, dynamic> approved,
  ) async {
    final String queue = approved["queue"]?.toString() ?? "";
    final String date = approved["date"]?.toString() ?? "";

    if (queue.isEmpty || date.isEmpty) {
      throw Exception("Queue code or appointment date is missing.");
    }

    final Map<String, dynamic> queueData = {
      "queueId": queue,
      "queue": queue,
      "name": approved["fullName"] ?? approved["plate"] ?? "-",
      "type": approved["vehicle"] ?? "-",
      "date": date,
      "source": "Appointment",
      "status": "Waiting",
      "municipality": approved["municipality"] ?? "",
      "appointmentId": approved["appointmentId"] ?? "",
      "customerId": approved["customerId"] ?? "",
      "customerEmail": approved["customerEmail"] ?? "",
      "plate": approved["plate"] ?? "",
      ...firestoreQueryFields(
        date: date,
        plate: approved["plate"],
        name: approved["fullName"] ?? approved["name"],
      ),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    await queueItemsRef(
      date,
    ).doc(queue).set(queueData, SetOptions(merge: true));
  }

  // ================= APPROVE APPOINTMENT =================

  Future<bool> approveBooking(Map<String, dynamic> booking) async {
    final String appointmentId = booking["appointmentId"]?.toString() ?? "";
    final String queue = booking["queue"]?.toString() ?? "";
    final String date = booking["date"]?.toString() ?? "";

    if (appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment ID is missing.")),
      );
      return false;
    }

    if (queue.isEmpty || date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Queue code or appointment date is missing."),
        ),
      );
      return false;
    }

    if (isQueueAlreadyUsedLocally(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$queue is already taken on $date. Please reject this appointment or choose another slot.",
          ),
        ),
      );
      return false;
    }

    final bool usedInApprovedAppointments =
        await isQueueAlreadyUsedInApprovedAppointments(booking);

    if (usedInApprovedAppointments) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$queue is already approved online for $date.")),
      );
      return false;
    }

    final bool usedInQueue = await isQueueAlreadyUsedInFirestoreQueue(
      date: date,
      queue: queue,
    );

    if (usedInQueue) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$queue already exists in the live queue for $date."),
        ),
      );
      return false;
    }

    try {
      final approved = {
        ...booking,
        "status": "Approved",
        "updatedAt": FieldValue.serverTimestamp(),
        "approvedAt": FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();

      final appointmentRef = FirebaseFirestore.instance
          .collection("appointments")
          .doc(appointmentId);

      final queueRef = queueItemsRef(date).doc(queue);

      batch.update(appointmentRef, {
        "status": "Approved",
        ...firestoreQueryFields(
          date: date,
          plate: booking["plate"],
          name: booking["fullName"] ?? booking["name"],
        ),
        "updatedAt": FieldValue.serverTimestamp(),
        "approvedAt": FieldValue.serverTimestamp(),
      });

      batch.set(queueRef, {
        "queueId": queue,
        "queue": queue,
        "name": booking["fullName"] ?? booking["plate"] ?? "-",
        "type": booking["vehicle"] ?? "-",
        "date": date,
        "source": "Appointment",
        "status": "Waiting",
        "municipality": booking["municipality"] ?? "",
        "appointmentId": appointmentId,
        "customerId": booking["customerId"] ?? "",
        "customerEmail": booking["customerEmail"] ?? "",
        "plate": booking["plate"] ?? "",
        ...firestoreQueryFields(
          date: date,
          plate: booking["plate"],
          name: booking["fullName"] ?? booking["name"],
        ),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      pendingBookings.value = pendingBookings.value
          .where((b) => b != booking)
          .toList();

      approvedBookings.value = [
        ...approvedBookings.value,
        {...booking, "status": "Approved"},
      ];

      addApprovedAppointmentToLocalQueue(approved);
      markQueueCodeAsIssuedForBooking(date, queue);

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$queue approved and added to live queue for $date"),
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Approval failed: $e")));

      return false;
    }
  }

  // ================= REJECT APPOINTMENT =================

  Future<void> rejectBooking(Map<String, dynamic> booking) async {
    final String appointmentId = booking["appointmentId"]?.toString() ?? "";
    final String queue = booking["queue"]?.toString() ?? "";

    if (appointmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment ID is missing.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection("appointments")
          .doc(appointmentId)
          .update({
            "status": "Rejected",
            ...firestoreQueryFields(
              date: booking["date"],
              plate: booking["plate"],
              name: booking["fullName"] ?? booking["name"],
            ),
            "updatedAt": FieldValue.serverTimestamp(),
            "rejectedAt": FieldValue.serverTimestamp(),
          });
      pendingBookings.value = pendingBookings.value
          .where((b) => b != booking)
          .toList();

      rejectedBookings.value = [
        ...rejectedBookings.value,
        {...booking, "status": "Rejected"},
      ];

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("$queue rejected")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Rejection failed: $e")));
    }
  }

  // ================= SHOW DETAILS =================

  void showDetails(Map<String, dynamic> booking) {
    final bool canReviewBooking =
        booking["status"]?.toString().trim().toLowerCase() == "pending";

    showDialog(
      context: context,
      builder: (_) {
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.88,
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                      decoration: const BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Appointment Details - ${booking['queue']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isProcessing
                                ? null
                                : () {
                                    Navigator.pop(context);
                                  },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            tooltip: "Close",
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _softPrimaryColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                children: [
                                  detailRow("Queue Code", booking['queue']),
                                  detailRow("Full Name", booking['fullName']),
                                  detailRow(
                                    "Municipality",
                                    booking['municipality'],
                                  ),
                                  detailRow("Plate Number", booking['plate']),
                                  detailRow("Vehicle Type", booking['vehicle']),
                                  detailRow("Date", booking['date']),
                                  detailRow("Status", booking['status']),
                                  detailRow("Email", booking['customerEmail']),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            const Text(
                              "Submitted Documents",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                              ),
                            ),

                            const SizedBox(height: 15),

                            documentPreview(
                              title: "Valid ID",
                              fileName: booking["idFile"],
                              fileUrl: booking["idFileUrl"],
                              isUploaded: booking["idFileUploaded"],
                              appointmentId: booking["appointmentId"],
                              documentType: "ID",
                            ),
                            documentPreview(
                              title: "Official Receipt (OR)",
                              fileName: booking["orFile"],
                              fileUrl: booking["orFileUrl"],
                              isUploaded: booking["orFileUploaded"],
                              appointmentId: booking["appointmentId"],
                              documentType: "OR",
                            ),
                            documentPreview(
                              title: "Certificate of Registration (CR)",
                              fileName: booking["crFile"],
                              fileUrl: booking["crFileUrl"],
                              isUploaded: booking["crFileUploaded"],
                              appointmentId: booking["appointmentId"],
                              documentType: "CR",
                            ),

                            const SizedBox(height: 10),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _softPrimaryColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _borderColor),
                              ),
                              child: const Text(
                                "Select VIEW FILE to open the document uploaded by the customer.",
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (canReviewBooking)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: _cardColor,
                          border: Border(top: BorderSide(color: _borderColor)),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          setDialogState(() {
                                            isProcessing = true;
                                          });

                                          final success = await approveBooking(
                                            booking,
                                          );

                                          if (!context.mounted) return;

                                          setDialogState(() {
                                            isProcessing = false;
                                          });

                                          if (success) {
                                            Navigator.pop(context);
                                          }
                                        },
                                  child: isProcessing
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "APPROVE",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          setDialogState(() {
                                            isProcessing = true;
                                          });

                                          await rejectBooking(booking);

                                          if (!context.mounted) return;

                                          setDialogState(() {
                                            isProcessing = false;
                                          });

                                          Navigator.pop(context);
                                        },
                                  child: isProcessing
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "REJECT",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
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
            );
          },
        );
      },
    );
  }

  // ================= DETAIL ROW =================

  Widget detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.toString().isEmpty
                  ? "-"
                  : value.toString(),
              style: const TextStyle(
                color: _mutedTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DOCUMENT PREVIEW =================

  Future<({Uint8List bytes, String contentType, String fileName})>
  loadFirestoreDocument({
    required String appointmentId,
    required String documentType,
  }) async {
    final documentRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .collection('documents')
        .doc(documentType.toLowerCase());
    final metadataSnapshot = await documentRef.get();
    final metadata = metadataSnapshot.data();

    if (!metadataSnapshot.exists || metadata == null) {
      throw StateError('The uploaded file data was not found.');
    }

    final chunksSnapshot = await documentRef
        .collection('chunks')
        .orderBy('index')
        .get();
    final int expectedChunks = metadata['chunkCount'] as int? ?? 0;

    if (chunksSnapshot.docs.length != expectedChunks || expectedChunks == 0) {
      throw StateError('The uploaded file is incomplete.');
    }

    final BytesBuilder bytesBuilder = BytesBuilder(copy: false);

    for (final chunkSnapshot in chunksSnapshot.docs) {
      final Blob? chunk = chunkSnapshot.data()['data'] as Blob?;

      if (chunk == null) {
        throw StateError('The uploaded file is incomplete.');
      }

      bytesBuilder.add(chunk.bytes);
    }

    return (
      bytes: bytesBuilder.takeBytes(),
      contentType: metadata['contentType']?.toString() ?? 'image/jpeg',
      fileName: metadata['fileName']?.toString() ?? documentType,
    );
  }

  Future<void> showFirestoreDocument({
    required String appointmentId,
    required String documentType,
    required String title,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final documentFuture = loadFirestoreDocument(
          appointmentId: appointmentId,
          documentType: documentType,
        );

        return Dialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.92,
            height: MediaQuery.of(dialogContext).size.height * 0.88,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                  decoration: const BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        tooltip: "Close",
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      FutureBuilder<
                        ({Uint8List bytes, String contentType, String fileName})
                      >(
                        future: documentFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                              ),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  "Unable to load this document. Older appointments may need the files submitted again.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }

                          final document = snapshot.data!;
                          final bool isPdf =
                              document.contentType == 'application/pdf' ||
                              document.fileName.toLowerCase().endsWith('.pdf');

                          if (isPdf) {
                            return PdfPreview(
                              build: (_) async => document.bytes,
                              allowPrinting: false,
                              allowSharing: false,
                              canChangeOrientation: false,
                              canChangePageFormat: false,
                              pdfFileName: document.fileName,
                            );
                          }

                          return Container(
                            color: Colors.black.withValues(alpha: 0.04),
                            padding: const EdgeInsets.all(12),
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 5,
                              child: Center(
                                child: Image.memory(
                                  document.bytes,
                                  fit: BoxFit.contain,
                                  cacheWidth: 1600,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (_, _, _) {
                                    return const Text(
                                      "Unable to display this image.",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> openDocument({
    required dynamic fileUrl,
    required dynamic appointmentId,
    required String documentType,
    required String title,
  }) async {
    final String url = fileUrl?.toString().trim() ?? '';

    if (url.isEmpty) {
      final String id = appointmentId?.toString().trim() ?? '';

      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to locate this appointment.")),
        );
        return;
      }

      await showFirestoreDocument(
        appointmentId: id,
        documentType: documentType,
        title: title,
      );
      return;
    }

    final Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("The uploaded file link is invalid.")),
      );
      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('The device could not open this file.');
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to open the uploaded file. Please try again."),
        ),
      );
    }
  }

  Widget documentPreview({
    required String title,
    required dynamic fileName,
    required dynamic fileUrl,
    required dynamic isUploaded,
    required dynamic appointmentId,
    required String documentType,
  }) {
    final String displayedFile = fileName == null || fileName.toString().isEmpty
        ? "No file attached"
        : fileName.toString();

    final bool hasUploadedFile =
        (fileUrl?.toString().trim().isNotEmpty ?? false) || isUploaded == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: hasUploadedFile
                      ? _softPrimaryColor
                      : Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Icon(
                  hasUploadedFile
                      ? Icons.description_outlined
                      : Icons.warning_amber_rounded,
                  color: hasUploadedFile ? _primaryColor : Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayedFile,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUploadedFile ? _mutedTextColor : Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hasUploadedFile
                  ? () {
                      openDocument(
                        fileUrl: fileUrl,
                        appointmentId: appointmentId,
                        documentType: documentType,
                        title: title,
                      );
                    }
                  : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                hasUploadedFile ? "VIEW FILE" : "FILE NOT UPLOADED",
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: _borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= INFO CARD =================

  Widget infoCard(String title, int value) {
    IconData icon;
    Color accentColor;

    if (title == "Pending") {
      icon = Icons.pending_actions_rounded;
      accentColor = Colors.orange;
    } else if (title == "Approved") {
      icon = Icons.check_circle_outline_rounded;
      accentColor = Colors.green;
    } else {
      icon = Icons.cancel_outlined;
      accentColor = Colors.red;
    }

    final bool isExpanded = _expandedOverviewStatus == title;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _expandedOverviewStatus = isExpanded ? null : title;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isExpanded
                  ? accentColor.withValues(alpha: 0.06)
                  : _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isExpanded ? accentColor : _borderColor,
                width: isExpanded ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.06),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded ? "Hide customers" : "View customers",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: accentColor,
                          size: 17,
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

  DateTime appointmentRecordDate(Map<String, dynamic> appointment) {
    final parts = appointment["date"]?.toString().split("/") ?? const [];
    if (parts.length != 3) return DateTime(1900);

    final month = int.tryParse(parts[0]) ?? 1;
    final day = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? 1900;
    return DateTime(year, month, day);
  }

  List<Map<String, dynamic>> monthAppointmentsForStatus(String status) {
    final normalizedStatus = status.trim().toLowerCase();
    final records = _monthAppointments.where((appointment) {
      return appointment["status"]?.toString().trim().toLowerCase() ==
          normalizedStatus;
    }).toList();

    records.sort((a, b) {
      final dateComparison = appointmentRecordDate(
        a,
      ).compareTo(appointmentRecordDate(b));
      if (dateComparison != 0) return dateComparison;
      return (a["queue"]?.toString() ?? "").compareTo(
        b["queue"]?.toString() ?? "",
      );
    });
    return records;
  }

  Widget buildMonthStatusAppointments(String status) {
    final records = monthAppointmentsForStatus(status);
    final Color color;
    final IconData icon;

    switch (status) {
      case "Pending":
        color = Colors.orange;
        icon = Icons.pending_actions_rounded;
      case "Approved":
        color = Colors.green;
        icon = Icons.check_circle_outline_rounded;
      default:
        color = Colors.red;
        icon = Icons.cancel_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$status Appointments",
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      calendarMonthLabel(calendarMonth),
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${records.length}",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: "Hide $status appointments",
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _expandedOverviewStatus = null),
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
          const Divider(height: 20, color: _borderColor),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
              decoration: BoxDecoration(
                color: _softPrimaryColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                "No ${status.toLowerCase()} appointments for "
                "${calendarMonthLabel(calendarMonth)}.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...records.map(
              (appointment) => monthStatusAppointmentCard(
                appointment: appointment,
                status: status,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget monthStatusAppointmentCard({
    required Map<String, dynamic> appointment,
    required String status,
    required Color color,
  }) {
    final String queue = appointment["queue"]?.toString().trim() ?? "-";
    final String name =
        appointment["fullName"]?.toString().trim() ?? "Customer";
    final String plate = appointment["plate"]?.toString().trim() ?? "-";
    final String vehicle = appointment["vehicle"]?.toString().trim() ?? "-";
    final String municipality =
        appointment["municipality"]?.toString().trim() ?? "-";
    final String date = appointment["date"]?.toString().trim() ?? "-";
    final String queueLetter = queue.isEmpty ? "-" : queue.substring(0, 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _softPrimaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: _borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDetails(appointment),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    queueLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? "Customer" : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$queue • $plate • $date",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$vehicle • $municipality",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget emptyPendingAppointments() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _softPrimaryColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: _primaryColor, size: 42),
            SizedBox(height: 10),
            Text(
              "No pending appointments",
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget pendingAppointmentCard(Map<String, dynamic> booking) {
    final String queue = booking["queue"]?.toString() ?? "-";
    final String queueLetter = queue.isNotEmpty ? queue.substring(0, 1) : "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              queueLetter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$queue - ${booking['plate'] ?? '-'}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${booking['fullName'] ?? '-'} • ${booking['municipality'] ?? '-'}",
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${booking['vehicle'] ?? '-'} • ${booking['date'] ?? '-'}",
                  style: const TextStyle(color: _mutedTextColor, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Pending",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              showDetails(booking);
            },
            child: const Text(
              "CHECK",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ================= APPOINTMENT AVAILABILITY CALENDAR =================

  String calendarDateKey(DateTime date) {
    return "${date.month}/${date.day}/${date.year}";
  }

  String calendarMonthLabel(DateTime date) {
    const months = [
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

    return "${months[date.month - 1]} ${date.year}";
  }

  String calendarFullDateLabel(DateTime date) {
    const months = [
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

    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Map<String, int> activeBookingsByDate(
    List<Map<String, dynamic>> appointments,
  ) {
    final counts = <String, int>{};

    for (final appointment in appointments) {
      final status = appointment["status"]?.toString() ?? "";
      final date = appointment["date"]?.toString() ?? "";

      if (date.isEmpty || (status != "Pending" && status != "Approved")) {
        continue;
      }

      counts[date] = (counts[date] ?? 0) + 1;
    }

    return counts;
  }

  List<Map<String, dynamic>> approvedAppointmentsForDate(
    List<Map<String, dynamic>> appointments,
    DateTime date,
  ) {
    final String selectedDateKey = calendarDateKey(date);
    final approved = appointments.where((appointment) {
      final String status =
          appointment["status"]?.toString().trim().toLowerCase() ?? "";
      final String appointmentDate = appointment["date"]?.toString() ?? "";

      return status == "approved" && appointmentDate == selectedDateKey;
    }).toList();

    approved.sort((a, b) {
      final String aQueue = a["queue"]?.toString() ?? "";
      final String bQueue = b["queue"]?.toString() ?? "";
      return aQueue.compareTo(bQueue);
    });

    return approved;
  }

  Widget buildSelectedDateAppointments(
    List<Map<String, dynamic>> appointments,
    DateTime selectedDate,
  ) {
    final approved = approvedAppointmentsForDate(appointments, selectedDate);

    return Container(
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.green,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Approved Customers",
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      calendarFullDateLabel(selectedDate),
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${approved.length} approved",
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (approved.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _borderColor),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    color: _mutedTextColor,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "No approved customers for this date.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            ...approved.map(approvedCalendarAppointmentCard),
        ],
      ),
    );
  }

  Widget approvedCalendarAppointmentCard(Map<String, dynamic> appointment) {
    final String queue = appointment["queue"]?.toString() ?? "-";
    final String name = appointment["fullName"]?.toString().trim() ?? "";
    final String plate = appointment["plate"]?.toString().trim() ?? "";
    final String vehicle = appointment["vehicle"]?.toString().trim() ?? "";
    final String municipality =
        appointment["municipality"]?.toString().trim() ?? "";
    final String queueLetter = queue.isEmpty ? "-" : queue.substring(0, 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: _borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDetails(appointment),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    queueLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? "Customer" : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _primaryColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Approved",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$queue • ${plate.isEmpty ? 'No plate' : plate}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${vehicle.isEmpty ? 'Vehicle not specified' : vehicle} • ${municipality.isEmpty ? 'Municipality not specified' : municipality}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedTextColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAppointmentCalendar(List<Map<String, dynamic>> appointments) {
    final bookingCounts = activeBookingsByDate(appointments);
    final firstDay = DateTime(calendarMonth.year, calendarMonth.month);
    final daysInMonth = DateTime(
      calendarMonth.year,
      calendarMonth.month + 1,
      0,
    ).day;
    final leadingEmptyDays = firstDay.weekday % 7;
    final today = DateUtils.dateOnly(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.06),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: _primaryColor,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Appointment Availability",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Select a date to view approved customers. Availability updates automatically from Pending and Approved appointments.",
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _softPrimaryColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: "Previous month",
                  onPressed: () {
                    setState(() {
                      calendarMonth = DateTime(
                        calendarMonth.year,
                        calendarMonth.month - 1,
                      );
                      selectedCalendarDate = null;
                    });
                    _listenToAppointmentMonth();
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    calendarMonthLabel(calendarMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: "Next month",
                  onPressed: () {
                    setState(() {
                      calendarMonth = DateTime(
                        calendarMonth.year,
                        calendarMonth.month + 1,
                      );
                      selectedCalendarDate = null;
                    });
                    _listenToAppointmentMonth();
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _CalendarWeekday("SUN"),
              _CalendarWeekday("MON"),
              _CalendarWeekday("TUE"),
              _CalendarWeekday("WED"),
              _CalendarWeekday("THU"),
              _CalendarWeekday("FRI"),
              _CalendarWeekday("SAT"),
            ],
          ),
          const SizedBox(height: 7),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyDays + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              mainAxisExtent: 66,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays) {
                return const SizedBox.shrink();
              }

              final day = index - leadingEmptyDays + 1;
              final date = DateTime(
                calendarMonth.year,
                calendarMonth.month,
                day,
              );
              final booked = bookingCounts[calendarDateKey(date)] ?? 0;
              final isPast = date.isBefore(today);
              final isClosed = date.weekday == DateTime.sunday;
              final isFull = !isPast && !isClosed && booked >= maxQueueLimit;
              final isAvailable = !isPast && !isClosed && !isFull;
              final isSelected =
                  selectedCalendarDate != null &&
                  DateUtils.isSameDay(selectedCalendarDate, date);

              final Color statusColor = isFull
                  ? Colors.red
                  : isAvailable
                  ? Colors.green
                  : Colors.grey;
              final String statusText = isFull
                  ? "Full"
                  : isAvailable
                  ? "$booked/$maxQueueLimit"
                  : isClosed
                  ? "Closed"
                  : "Past";

              return Tooltip(
                message: isFull
                    ? "${calendarDateKey(date)} is fully booked. Tap to view approved customers."
                    : isAvailable
                    ? "${calendarDateKey(date)} has ${maxQueueLimit - booked} slot(s) available. Tap to view approved customers."
                    : "${calendarDateKey(date)} is unavailable for booking. Tap to view approved customers.",
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        selectedCalendarDate = date;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor.withValues(alpha: 0.12)
                            : statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _primaryColor
                              : statusColor.withValues(alpha: 0.42),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primaryColor.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.toString(),
                            style: TextStyle(
                              color: isSelected ? _primaryColor : statusColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: isSelected ? _primaryColor : statusColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _CalendarLegend(color: Colors.green, label: "Available"),
              _CalendarLegend(color: Colors.red, label: "Fully booked"),
              _CalendarLegend(color: Colors.grey, label: "Closed / Past"),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedCalendarDate == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _softPrimaryColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _borderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: _primaryColor, size: 21),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "Tap any date to view its approved customers.",
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            buildSelectedDateAppointments(appointments, selectedCalendarDate!),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
          title: const Text("Admin Appointment Dashboard"),
          actions: [
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 7, bottom: 7),
                child: OutlinedButton.icon(
                  onPressed: _isRefreshing
                      ? null
                      : refreshAppointmentsFromWebButton,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 19),
                  label: Text(_isRefreshing ? "Refreshing" : "Refresh"),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: AppResponsiveContent(
            child: Builder(
              builder: (context) {
                final appointments = _loadedAppointments;
                final bookings = _pendingAppointments;
                final monthPendingCount = _monthStatusCount("Pending");
                final monthApprovedCount = _monthStatusCount("Approved");
                final monthRejectedCount = _monthStatusCount("Rejected");

                return AppRefreshIndicator(
                  onRefresh: refreshAppointments,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: appPagePadding(context, top: 10, bottom: 20),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _softPrimaryColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.dashboard_customize_rounded,
                              color: _primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Appointment Overview",
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    calendarMonthLabel(calendarMonth),
                                    style: const TextStyle(
                                      color: _mutedTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          infoCard("Pending", monthPendingCount),
                          const SizedBox(width: 10),
                          infoCard("Approved", monthApprovedCount),
                          const SizedBox(width: 10),
                          infoCard("Rejected", monthRejectedCount),
                        ],
                      ),
                      if (_expandedOverviewStatus != null) ...[
                        const SizedBox(height: 14),
                        buildMonthStatusAppointments(_expandedOverviewStatus!),
                      ],
                      const SizedBox(height: 18),
                      if (_appointmentsLoading && appointments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: _primaryColor,
                            ),
                          ),
                        )
                      else if (_appointmentsError != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            "Unable to load appointments: $_appointmentsError",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else ...[
                        buildAppointmentCalendar(appointments),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.06),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.event_note_rounded,
                                    color: _primaryColor,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Pending Appointments",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (bookings.isEmpty)
                                emptyPendingAppointments()
                              else
                                ...bookings.map(pendingAppointmentCard),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _mutedTextColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _mutedTextColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
