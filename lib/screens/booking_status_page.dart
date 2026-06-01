import 'package:flutter/material.dart';
import 'book_appointment.dart';
import 'customer_register.dart';

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

class BookingStatusPage extends StatelessWidget {
  const BookingStatusPage({super.key});

  String get loggedInName => loggedInCustomerNameNotifier.value.trim();

  List<Map<String, dynamic>> getMyBookings() {
    final String name = loggedInName.toLowerCase();

    final allBookings = [
      ...pendingBookings.value,
      ...approvedBookings.value,
      ...rejectedBookings.value,
    ];

    return allBookings.where((booking) {
      final bookingName = (booking["fullName"] ?? "").toString().toLowerCase();
      return bookingName.trim() == name;
    }).toList();
  }

  Color statusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    return Colors.orange;
  }

  IconData statusIcon(String status) {
    if (status == "Approved") return Icons.check_circle_outline_rounded;
    if (status == "Rejected") return Icons.cancel_outlined;
    return Icons.pending_actions_rounded;
  }

  String statusMessage(String status) {
    if (status == "Approved") {
      return "Your appointment has been approved. Please prepare your documents and arrive before your queue number is called.";
    }

    if (status == "Rejected") {
      return "Your appointment was rejected. Please book another schedule or coordinate with the testing center.";
    }

    return "Your appointment request is waiting for admin approval.";
  }

  @override
  Widget build(BuildContext context) {
    final bookings = getMyBookings();

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
          title: const Text("My Appointment Status"),
        ),
        body: SafeArea(
          child: ValueListenableBuilder<String>(
            valueListenable: loggedInCustomerNameNotifier,
            builder: (context, name, _) {
              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: pendingBookings,
                builder: (context, pending, _) {
                  return ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: approvedBookings,
                    builder: (context, approved, _) {
                      return ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: rejectedBookings,
                        builder: (context, rejected, _) {
                          final myBookings = getMyBookings();

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            children: [
                              buildHeaderCard(),

                              const SizedBox(height: 18),

                              if (myBookings.isEmpty)
                                buildEmptyCard()
                              else
                                ...myBookings.map((booking) {
                                  return buildBookingCard(booking);
                                }).toList(),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Booking Confirmation",
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  loggedInName.isEmpty
                      ? "Check your appointment status."
                      : "Showing bookings for $loggedInName",
                  style: const TextStyle(
                    color: _mutedTextColor,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            color: _primaryColor,
            size: 50,
          ),
          SizedBox(height: 12),
          Text(
            "No Appointment found",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "After you book an appointment, your appointment status will appear here as Pending, Approved, or Rejected.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBookingCard(Map<String, dynamic> booking) {
    final status = booking["status"]?.toString() ?? "Pending";
    final color = statusColor(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  statusIcon(status),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking["queue"]?.toString() ?? "-",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            statusMessage(status),
            style: const TextStyle(
              color: _mutedTextColor,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),

          const SizedBox(height: 16),

          infoRow("Queue Code", booking["queue"]),
          infoRow("Date", booking["date"]),
          infoRow("Vehicle Type", booking["vehicle"]),
          infoRow("Plate Number", booking["plate"]),
          infoRow("Municipality", booking["municipality"]),

          if (status == "Approved") ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green.withOpacity(0.25),
                ),
              ),
              child: const Text(
                "Your Appointment is approved. Use your queue code when tracking your queue.",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              "$label:",
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w800,
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
}