import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String get loggedInEmail => loggedInCustomerEmailNotifier.value.trim();

  String get loggedInCustomerId => loggedInCustomerIdNotifier.value.trim();

  String get currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    return loggedInCustomerId.isNotEmpty ? loggedInCustomerId : user?.uid ?? "";
  }

  String get currentUserEmail {
    final user = FirebaseAuth.instance.currentUser;
    return loggedInEmail.isNotEmpty ? loggedInEmail : user?.email ?? "";
  }

  Stream<List<Map<String, dynamic>>> myAppointmentsStream() {
    final String uid = currentUserId;
    final String email = currentUserEmail;

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection("appointments");

    if (uid.isNotEmpty) {
      query = query.where("customerId", isEqualTo: uid);
    } else if (email.isNotEmpty) {
      query = query.where("customerEmail", isEqualTo: email);
    } else {
      query = query.where("customerId", isEqualTo: "__no_logged_in_user__");
    }

    return query.snapshots().map((snapshot) {
      final appointments = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          ...data,
          "appointmentId": data["appointmentId"] ?? doc.id,
        };
      }).toList();

      appointments.sort((a, b) {
        final aCreated = a["createdAt"];
        final bCreated = b["createdAt"];

        if (aCreated is Timestamp && bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }

        return 0;
      });

      return appointments;
    });
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
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: myAppointmentsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        buildHeaderCard(),
                        const SizedBox(height: 18),
                        buildLoadingCard(),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        buildHeaderCard(),
                        const SizedBox(height: 18),
                        buildErrorCard(snapshot.error.toString()),
                      ],
                    );
                  }

                  final appointments = snapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      buildHeaderCard(),
                      const SizedBox(height: 18),
                      if (appointments.isEmpty)
                        buildEmptyCard()
                      else
                        ...appointments.map((appointment) {
                          return buildBookingCard(appointment);
                        }).toList(),
                    ],
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
                  "Appointment Confirmation",
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
                      : "Showing appointments for $loggedInName",
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

  Widget buildLoadingCard() {
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
          CircularProgressIndicator(color: _primaryColor),
          SizedBox(height: 14),
          Text(
            "Loading your appointment status...",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildErrorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            "Unable to load appointment status",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _mutedTextColor,
              height: 1.4,
              fontSize: 13,
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
            "No appointment found",
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
                "Your appointment is approved. Use your queue code when tracking your queue.",
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
}