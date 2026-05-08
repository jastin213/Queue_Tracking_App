import 'dart:io';
import 'package:flutter/material.dart';

import 'book_appointment.dart';
import 'admin_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // ================= APPROVE BOOKING =================

  void approveBooking(Map<String, dynamic> booking) {
    // Remove from pending
    pendingBookings.value =
        pendingBookings.value.where((b) => b != booking).toList();

    // Add to approved
    final approved = {
      ...booking,
      "status": "Approved",
    };

    approvedBookings.value = [
      ...approvedBookings.value,
      approved,
    ];

    // IMPORTANT:
    // This adds the approved booking to the waiting queue,
    // but it keeps the appointment date.
    // So it will only appear in Admin Queue Panel when that date is selected.
    waitingQueueNotifier.value = [
      ...waitingQueueNotifier.value,
      {
        "queue": approved["queue"],
        "name": approved["plate"],
        "type": approved["vehicle"],
        "date": approved["date"],
        "source": "Appointment",
      }
    ];

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${approved['queue']} approved for ${approved['date']}",
        ),
      ),
    );
  }

  // ================= REJECT BOOKING =================

  void rejectBooking(Map<String, dynamic> booking) {
    // Remove from pending
    pendingBookings.value =
        pendingBookings.value.where((b) => b != booking).toList();

    // Add to rejected
    rejectedBookings.value = [
      ...rejectedBookings.value,
      {
        ...booking,
        "status": "Rejected",
      }
    ];

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${booking['queue']} rejected",
        ),
      ),
    );
  }

  // ================= SHOW BOOKING DETAILS =================

  void showDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // ================= HEADER =================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Booking Details - ${booking['queue']}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ================= CONTENT =================

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detailRow("Queue Code", booking['queue']),
                        detailRow("Plate Number", booking['plate']),
                        detailRow("Vehicle Type", booking['vehicle']),
                        detailRow("Date", booking['date']),
                        detailRow("Status", booking['status']),

                        const SizedBox(height: 20),

                        const Text(
                          "Submitted Documents",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        documentPreview(
                          title: "Valid ID",
                          path: booking["idPath"],
                          fileName: booking["idFile"],
                        ),

                        documentPreview(
                          title: "OR",
                          path: booking["orPath"],
                          fileName: booking["orFile"],
                        ),

                        documentPreview(
                          title: "CR",
                          path: booking["crPath"],
                          fileName: booking["crFile"],
                        ),
                      ],
                    ),
                  ),
                ),

                // ================= ACTION BUTTONS =================

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("CLOSE"),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            approveBooking(booking);
                            Navigator.pop(context);
                          },
                          child: const Text("APPROVE"),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            rejectBooking(booking);
                            Navigator.pop(context);
                          },
                          child: const Text("REJECT"),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null ? "-" : value.toString(),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DOCUMENT PREVIEW =================

  Widget documentPreview({
    required String title,
    required String? path,
    required String? fileName,
  }) {
    bool hasFile = path != null && path.isNotEmpty;

    bool isImage = hasFile &&
        (path.toLowerCase().endsWith(".jpg") ||
            path.toLowerCase().endsWith(".jpeg") ||
            path.toLowerCase().endsWith(".png"));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            fileName ?? "No file attached",
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          if (!hasFile)
            const Text(
              "No document uploaded.",
              style: TextStyle(color: Colors.red),
            )
          else if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(path),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    width: double.infinity,
                    alignment: Alignment.center,
                    color: Colors.grey.shade300,
                    child: const Text(
                      "Unable to preview image",
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "File attached. Preview is available only for images.",
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ================= INFO CARD =================

  Widget infoCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),

      appBar: AppBar(
        title: const Text("Admin Booking Dashboard"),
        backgroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= TOP CARDS =================

            Row(
              children: [
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: pendingBookings,
                  builder: (_, list, __) {
                    return infoCard(
                      "Pending",
                      list.length.toString(),
                    );
                  },
                ),

                const SizedBox(width: 10),

                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: approvedBookings,
                  builder: (_, list, __) {
                    return infoCard(
                      "Approved",
                      list.length.toString(),
                    );
                  },
                ),

                const SizedBox(width: 10),

                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: rejectedBookings,
                  builder: (_, list, __) {
                    return infoCard(
                      "Rejected",
                      list.length.toString(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= PENDING LIST =================

            Expanded(
              child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pending Appointments",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Expanded(
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: pendingBookings,
                        builder: (context, bookings, _) {
                          if (bookings.isEmpty) {
                            return const Center(
                              child: Text("No pending bookings"),
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
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${booking['queue']} - ${booking['plate']}",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 5),

                                          Text(
                                            "${booking['vehicle']} • ${booking['date']}",
                                          ),

                                          const SizedBox(height: 3),

                                          const Text(
                                            "Status: Pending",
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    ElevatedButton(
                                      onPressed: () {
                                        showDetails(booking);
                                      },
                                      child: const Text("CHECK"),
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
    );
  }
}