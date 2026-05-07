import 'package:flutter/material.dart';
import 'book_appointment.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState
    extends State<AdminDashboard> {
  // ================= APPROVE =================

  void approveBooking(
    Map<String, dynamic> booking,
  ) {
    // REMOVE FROM PENDING
    pendingBookings.value =
        pendingBookings.value
            .where((b) => b != booking)
            .toList();

    // ADD TO APPROVED
    approvedBookings.value = [
      ...approvedBookings.value,
      {
        ...booking,
        "status": "Approved",
      }
    ];

    setState(() {});
  }

  // ================= REJECT =================

  void rejectBooking(
    Map<String, dynamic> booking,
  ) {
    // REMOVE FROM PENDING
    pendingBookings.value =
        pendingBookings.value
            .where((b) => b != booking)
            .toList();

    // ADD TO REJECTED
    rejectedBookings.value = [
      ...rejectedBookings.value,
      {
        ...booking,
        "status": "Rejected",
      }
    ];

    setState(() {});
  }

  // ================= CARD =================

  Widget infoCard(
    String title,
    String value,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(20),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(0.08),
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
      backgroundColor:
          const Color.fromARGB(255, 227, 242, 248),

      appBar: AppBar(
        title: const Text(
          "Admin Booking Dashboard",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // ================= TOP STATS =================

            Row(
              children: [
                infoCard(
                  "Pending",
                  pendingBookings.value.length
                      .toString(),
                ),

                const SizedBox(width: 10),

                infoCard(
                  "Approved",
                  approvedBookings.value.length
                      .toString(),
                ),

                const SizedBox(width: 10),

                infoCard(
                  "Rejected",
                  rejectedBookings.value.length
                      .toString(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= PENDING BOOKINGS =================

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Pending Appointments",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Expanded(
                      child:
                          ValueListenableBuilder<
                              List<
                                  Map<String,
                                      dynamic>>>(
                        valueListenable:
                            pendingBookings,

                        builder:
                            (
                              context,
                              bookings,
                              _,
                            ) {
                          if (bookings.isEmpty) {
                            return const Center(
                              child: Text(
                                "No pending bookings",
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount:
                                bookings.length,

                            itemBuilder:
                                (
                                  context,
                                  index,
                                ) {
                              final booking =
                                  bookings[index];

                              return Container(
                                margin:
                                    const EdgeInsets
                                        .only(
                                  bottom: 12,
                                ),

                                padding:
                                    const EdgeInsets
                                        .all(15),

                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .grey
                                      .shade100,

                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
                                  ),
                                ),

                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [
                                    Text(
                                      booking[
                                          'plate'],
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,

                                        fontSize:
                                            18,
                                      ),
                                    ),

                                    const SizedBox(
                                        height:
                                            5),

                                    Text(
                                      "Vehicle: ${booking['vehicle']}",
                                    ),

                                    Text(
                                      "Date: ${booking['date']}",
                                    ),

                                    Text(
                                      "Slot: ${booking['slot']}",
                                    ),

                                    const SizedBox(
                                        height:
                                            15),

                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              ElevatedButton(
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green,
                                            ),

                                            onPressed:
                                                () {
                                              approveBooking(
                                                booking,
                                              );
                                            },

                                            child:
                                                const Text(
                                              "APPROVE",
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                            width:
                                                10),

                                        Expanded(
                                          child:
                                              ElevatedButton(
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red,
                                            ),

                                            onPressed:
                                                () {
                                              rejectBooking(
                                                booking,
                                              );
                                            },

                                            child:
                                                const Text(
                                              "REJECT",
                                            ),
                                          ),
                                        ),
                                      ],
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