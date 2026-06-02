import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'book_appointment.dart';
import 'admin_page.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ================= FIRESTORE STREAMS =================

  Stream<List<Map<String, dynamic>>> appointmentStreamByStatus(String status) {
    return FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          "appointmentId": data["appointmentId"] ?? doc.id,
        };
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
    });
  }

  Future<Map<String, int>> getAppointmentCounts() async {
    final pending = await FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: "Pending")
        .get();

    final approved = await FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: "Approved")
        .get();

    final rejected = await FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: "Rejected")
        .get();

    return {
      "Pending": pending.docs.length,
      "Approved": approved.docs.length,
      "Rejected": rejected.docs.length,
    };
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

    bool inNowServing = nowServingNotifier.value != null &&
        nowServingNotifier.value!["queue"] == bookingQueue &&
        nowServingNotifier.value!["date"] == bookingDate;

    return inIssued || inWaitingQueue || inNowServing;
  }

  Future<bool> isQueueAlreadyUsedInFirestore(
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
          "queue": approved["queue"],
          "name": approved["fullName"] ?? approved["plate"],
          "type": approved["vehicle"],
          "date": approved["date"],
          "source": "Appointment",
          "municipality": approved["municipality"],
        },
      ];
    }
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

    final bool usedOnline = await isQueueAlreadyUsedInFirestore(booking);

    if (usedOnline) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "$queue is already approved online for $date.",
          ),
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

      await FirebaseFirestore.instance
          .collection("appointments")
          .doc(appointmentId)
          .update({
        "status": "Approved",
        "updatedAt": FieldValue.serverTimestamp(),
        "approvedAt": FieldValue.serverTimestamp(),
      });

      pendingBookings.value =
          pendingBookings.value.where((b) => b != booking).toList();

      approvedBookings.value = [
        ...approvedBookings.value,
        {
          ...booking,
          "status": "Approved",
        },
      ];

      addApprovedAppointmentToLocalQueue(approved);
      markQueueCodeAsIssuedForBooking(date, queue);

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$queue approved for $date")),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Approval failed: $e")),
      );

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
        "updatedAt": FieldValue.serverTimestamp(),
        "rejectedAt": FieldValue.serverTimestamp(),
      });

      pendingBookings.value =
          pendingBookings.value.where((b) => b != booking).toList();

      rejectedBookings.value = [
        ...rejectedBookings.value,
        {
          ...booking,
          "status": "Rejected",
        },
      ];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$queue rejected")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rejection failed: $e")),
      );
    }
  }

  // ================= SHOW DETAILS =================

  void showDetails(Map<String, dynamic> booking) {
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
                                  detailRow(
                                    "Email",
                                    booking['customerEmail'],
                                  ),
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
                            ),
                            documentPreview(
                              title: "Official Receipt (OR)",
                              fileName: booking["orFile"],
                            ),
                            documentPreview(
                              title: "Certificate of Registration (CR)",
                              fileName: booking["crFile"],
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
                                "Document file preview is temporarily limited to file names because Firebase Storage is not enabled yet.",
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

                                        final success =
                                            await approveBooking(booking);

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

  Widget documentPreview({
    required String title,
    required dynamic fileName,
  }) {
    final String displayedFile =
        fileName == null || fileName.toString().isEmpty
            ? "No file attached"
            : fileName.toString();

    final bool hasFile = displayedFile != "No file attached";

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
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: hasFile ? _softPrimaryColor : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(
              hasFile
                  ? Icons.description_outlined
                  : Icons.warning_amber_rounded,
              color: hasFile ? _primaryColor : Colors.red,
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
                    color: hasFile ? _mutedTextColor : Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= INFO CARD =================

  Widget infoCard(String title, String value) {
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

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(color: _primaryColor.withOpacity(0.06), blurRadius: 14),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
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
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _primaryColor,
              ),
            ),
          ],
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
            Icon(
              Icons.inbox_rounded,
              color: _primaryColor,
              size: 42,
            ),
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
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13,
                  ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
        appBar: AppBar(title: const Text("Admin Appointment Dashboard")),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _softPrimaryColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _borderColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.dashboard_customize_rounded,
                        color: _primaryColor,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Appointment Overview",
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                FutureBuilder<Map<String, int>>(
                  future: getAppointmentCounts(),
                  builder: (context, snapshot) {
                    final counts = snapshot.data ??
                        {
                          "Pending": 0,
                          "Approved": 0,
                          "Rejected": 0,
                        };

                    return Row(
                      children: [
                        infoCard("Pending", counts["Pending"].toString()),
                        const SizedBox(width: 10),
                        infoCard("Approved", counts["Approved"].toString()),
                        const SizedBox(width: 10),
                        infoCard("Rejected", counts["Rejected"].toString()),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.06),
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

                        Expanded(
                          child: StreamBuilder<List<Map<String, dynamic>>>(
                            stream: appointmentStreamByStatus("Pending"),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryColor,
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    "Unable to load appointments: ${snapshot.error}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }

                              final bookings = snapshot.data ?? [];

                              pendingBookings.value = bookings;

                              if (bookings.isEmpty) {
                                return emptyPendingAppointments();
                              }

                              return ListView.builder(
                                itemCount: bookings.length,
                                itemBuilder: (context, index) {
                                  final booking = bookings[index];
                                  return pendingAppointmentCard(booking);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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