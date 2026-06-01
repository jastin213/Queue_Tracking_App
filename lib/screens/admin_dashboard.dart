import 'dart:typed_data';

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
  // ================= CHECK IF QUEUE IS ALREADY USED =================

  bool isQueueAlreadyUsed(Map<String, dynamic> booking) {
    final String bookingQueue = booking["queue"] ?? "";
    final String bookingDate = booking["date"] ?? "";

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

  // ================= APPROVE BOOKING =================

  bool approveBooking(Map<String, dynamic> booking) {
    if (isQueueAlreadyUsed(booking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${booking['queue']} is already taken on ${booking['date']}. Please reject this booking or choose another slot.",
          ),
        ),
      );

      return false;
    }

    pendingBookings.value =
        pendingBookings.value.where((b) => b != booking).toList();

    final approved = {...booking, "status": "Approved"};

    approvedBookings.value = [...approvedBookings.value, approved];

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

    markQueueCodeAsIssuedForBooking(approved["date"], approved["queue"]);

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${approved['queue']} approved for ${approved['date']}"),
      ),
    );

    return true;
  }

  // ================= REJECT BOOKING =================

  void rejectBooking(Map<String, dynamic> booking) {
    pendingBookings.value =
        pendingBookings.value.where((b) => b != booking).toList();

    rejectedBookings.value = [
      ...rejectedBookings.value,
      {...booking, "status": "Rejected"},
    ];

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${booking['queue']} rejected")),
    );
  }

  // ================= SHOW DETAILS =================

  void showDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (_) {
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
                        onPressed: () {
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
                          bytes: booking["idBytes"],
                          path: booking["idPath"],
                        ),
                        documentPreview(
                          title: "OR",
                          fileName: booking["orFile"],
                          bytes: booking["orBytes"],
                          path: booking["orPath"],
                        ),
                        documentPreview(
                          title: "CR",
                          fileName: booking["crFile"],
                          bytes: booking["crBytes"],
                          path: booking["crPath"],
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
                            onPressed: () {
                              final success = approveBooking(booking);

                              if (success) {
                                Navigator.pop(context);
                              }
                            },
                            child: const Text(
                              "APPROVE",
                              style: TextStyle(fontWeight: FontWeight.w800),
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
                            onPressed: () {
                              rejectBooking(booking);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "REJECT",
                              style: TextStyle(fontWeight: FontWeight.w800),
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
              value == null ? "-" : value.toString(),
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

  bool isImageFile(String? fileName) {
    if (fileName == null) return false;

    final lower = fileName.toLowerCase();

    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png");
  }

  Widget documentPreview({
    required String title,
    required String? fileName,
    required dynamic bytes,
    required String? path,
  }) {
    final Uint8List? imageBytes = bytes is Uint8List ? bytes : null;
    final bool hasFile =
        (fileName != null && fileName.isNotEmpty) || imageBytes != null;
    final bool canPreviewImage = imageBytes != null && isImageFile(fileName);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: _primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            fileName ?? "No file attached",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _mutedTextColor, fontSize: 13),
          ),

          const SizedBox(height: 10),

          if (!hasFile)
            const Text(
              "No document uploaded.",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            )
          else if (canPreviewImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _softPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Unable to preview image",
                      style: TextStyle(color: _mutedTextColor),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 80,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _softPrimaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: const Text(
                "File attached. Preview is available only for JPG, JPEG, and PNG images.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
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
                // SUMMARY SECTION
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

                Row(
                  children: [
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: pendingBookings,
                      builder: (_, list, __) {
                        return infoCard("Pending", list.length.toString());
                      },
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: approvedBookings,
                      builder: (_, list, __) {
                        return infoCard("Approved", list.length.toString());
                      },
                    ),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: rejectedBookings,
                      builder: (_, list, __) {
                        return infoCard("Rejected", list.length.toString());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // PENDING APPOINTMENTS SECTION
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
                          child:
                              ValueListenableBuilder<List<Map<String, dynamic>>>(
                            valueListenable: pendingBookings,
                            builder: (context, bookings, _) {
                              if (bookings.isEmpty) {
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
                                          "No pending Appointments",
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

                              return ListView.builder(
                                itemCount: bookings.length,
                                itemBuilder: (context, index) {
                                  final booking = bookings[index];

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
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            booking['queue']
                                                    ?.toString()
                                                    .substring(0, 1) ??
                                                "-",
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${booking['queue']} - ${booking['plate']}",
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w900,
                                                  color: _primaryColor,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                "${booking['fullName']} • ${booking['municipality']}",
                                                style: const TextStyle(
                                                  color: _mutedTextColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                "${booking['vehicle']} • ${booking['date']}",
                                                style: const TextStyle(
                                                  color: _mutedTextColor,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  "Pending",
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w800,
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
                                              borderRadius:
                                                  BorderRadius.circular(14),
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
                                            style: TextStyle(
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