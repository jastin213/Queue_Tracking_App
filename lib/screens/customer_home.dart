import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_responsive_content.dart';
import 'track_page.dart';
import 'book_appointment.dart';
import 'booking_status_page.dart';
import 'customer_login.dart';
import 'customer_register.dart';
import 'customer_settings.dart';

const Color _backgroundColor = AppColors.background;
const Color _primaryColor = AppColors.primary;
const Color _cardColor = AppColors.surface;
const Color _borderColor = AppColors.border;
const Color _mutedTextColor = AppColors.mutedText;

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  bool isLoggingOut = false;
  bool _appointmentNotificationsLoading = true;
  Object? _appointmentNotificationsError;
  List<Map<String, dynamic>> _customerAppointments = [];
  final Map<String, String> _knownAppointmentStatuses = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _appointmentSubscription;
  bool _receivedInitialAppointmentSnapshot = false;

  @override
  void initState() {
    super.initState();
    _listenToAppointmentNotifications();
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    super.dispose();
  }

  Query<Map<String, dynamic>>? customerAppointmentsQuery() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final String uid = user?.uid ?? loggedInCustomerIdNotifier.value.trim();
      final String email =
          user?.email?.trim() ?? loggedInCustomerEmailNotifier.value.trim();
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        "appointments",
      );

      if (uid.isNotEmpty) {
        return query.where("customerId", isEqualTo: uid);
      }
      if (email.isNotEmpty) {
        return query.where("customerEmail", isEqualTo: email);
      }
    } catch (_) {
      // Firebase is unavailable only in isolated widget tests.
    }

    return null;
  }

  void _listenToAppointmentNotifications() {
    final query = customerAppointmentsQuery();
    if (query == null) {
      _appointmentNotificationsLoading = false;
      return;
    }

    _appointmentSubscription = query.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final appointments = snapshot.docs.map((doc) {
          final data = doc.data();
          return {...data, "appointmentId": data["appointmentId"] ?? doc.id};
        }).toList();
        appointments.sort((a, b) {
          final aUpdated = a["updatedAt"] ?? a["createdAt"];
          final bUpdated = b["updatedAt"] ?? b["createdAt"];
          if (aUpdated is Timestamp && bUpdated is Timestamp) {
            return bUpdated.compareTo(aUpdated);
          }
          return 0;
        });

        Map<String, dynamic>? changedAppointment;
        if (_receivedInitialAppointmentSnapshot) {
          for (final appointment in appointments) {
            final id = appointment["appointmentId"]?.toString() ?? "";
            final status = appointment["status"]?.toString() ?? "Pending";
            final previousStatus = _knownAppointmentStatuses[id];
            final isDecision = status == "Approved" || status == "Rejected";
            if (id.isNotEmpty &&
                isDecision &&
                previousStatus != null &&
                previousStatus != status) {
              changedAppointment = appointment;
              break;
            }
          }
        }

        _knownAppointmentStatuses
          ..clear()
          ..addEntries(
            appointments.map(
              (appointment) => MapEntry(
                appointment["appointmentId"]?.toString() ?? "",
                appointment["status"]?.toString() ?? "Pending",
              ),
            ),
          );
        _receivedInitialAppointmentSnapshot = true;

        setState(() {
          _customerAppointments = appointments;
          _appointmentNotificationsLoading = false;
          _appointmentNotificationsError = null;
        });

        if (changedAppointment != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showAppointmentStatusChanged(changedAppointment!);
          });
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _appointmentNotificationsLoading = false;
          _appointmentNotificationsError = error;
        });
      },
    );
  }

  Future<void> refreshCustomerHome() async {
    final query = customerAppointmentsQuery();
    await Future.wait([
      refreshCustomerProfile(),
      if (query != null) query.get(const GetOptions(source: Source.server)),
    ]);
  }

  Future<void> refreshCustomerProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    final data = userDoc.data();

    if (data == null) return;

    loggedInCustomerNameNotifier.value =
        (data["fullName"] ?? user.displayName ?? "").toString();
    loggedInCustomerEmailNotifier.value = (data["email"] ?? user.email ?? "")
        .toString();
    loggedInCustomerIdNotifier.value = user.uid;
  }

  bool isFinalAppointmentStatus(dynamic value) {
    final status = value?.toString().trim() ?? "";
    return status == "Approved" || status == "Rejected";
  }

  Color appointmentStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Rejected") return Colors.red;
    return Colors.orange;
  }

  IconData appointmentStatusIcon(String status) {
    if (status == "Approved") return Icons.check_circle_outline_rounded;
    if (status == "Rejected") return Icons.cancel_outlined;
    return Icons.pending_actions_rounded;
  }

  String appointmentStatusTitle(String status) {
    if (status == "Approved") return "Appointment Approved";
    if (status == "Rejected") return "Appointment Rejected";
    return "Appointment Pending";
  }

  String appointmentStatusMessage(String status) {
    if (status == "Approved") {
      return "Your appointment was approved. Check your schedule and queue code before going to the center.";
    }
    if (status == "Rejected") {
      return "Your appointment was rejected. Check its status and book another schedule if needed.";
    }
    return "Your booking is waiting for admin review. This notification updates automatically.";
  }

  Map<String, dynamic>? get latestAppointmentNotification {
    if (_customerAppointments.isEmpty) return null;
    for (final appointment in _customerAppointments) {
      if (isFinalAppointmentStatus(appointment["status"])) return appointment;
    }
    return _customerAppointments.first;
  }

  int get finalizedAppointmentCount {
    return _customerAppointments.where((appointment) {
      return isFinalAppointmentStatus(appointment["status"]);
    }).length;
  }

  void openAppointmentStatus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookingStatusPage()),
    );
  }

  void showAppointmentStatusChanged(Map<String, dynamic> appointment) {
    final status = appointment["status"]?.toString() ?? "Pending";
    final queue = appointment["queue"]?.toString() ?? "-";
    final color = appointmentStatusColor(status);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 6),
          content: Text("Queue $queue: ${appointmentStatusTitle(status)}"),
          action: SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: openAppointmentStatus,
          ),
        ),
      );
  }

  Widget buildAppointmentNotificationCard() {
    if (_appointmentNotificationsLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Checking appointment notifications...",
                style: TextStyle(
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_appointmentNotificationsError != null) {
      return Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: openAppointmentStatus,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    "Appointment notifications are temporarily unavailable. Tap to check your status.",
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
              ],
            ),
          ),
        ),
      );
    }

    final appointment = latestAppointmentNotification;
    if (appointment == null) return const SizedBox.shrink();

    final String status = appointment["status"]?.toString() ?? "Pending";
    final String queue = appointment["queue"]?.toString() ?? "-";
    final String date = appointment["date"]?.toString() ?? "-";
    final Color color = appointmentStatusColor(status);

    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: openAppointmentStatus,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.48)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 14),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(appointmentStatusIcon(status), color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointmentStatusTitle(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Queue $queue • $date",
                      style: const TextStyle(
                        color: _primaryColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appointmentStatusMessage(status),
                      style: const TextStyle(
                        color: _mutedTextColor,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      finalizedAppointmentCount > 1
                          ? "VIEW ALL $finalizedAppointmentCount UPDATES"
                          : "CHECK APPOINTMENT STATUS",
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
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
    );
  }

  Future<void> logout() async {
    if (isLoggingOut) return;

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text("Log out?"),
              content: const Text(
                "You will return to the login page and can sign in again anytime.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("CANCEL"),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text("LOG OUT"),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    setState(() {
      isLoggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      loggedInCustomerNameNotifier.value = "";
      loggedInCustomerEmailNotifier.value = "";
      loggedInCustomerIdNotifier.value = "";

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerLogin()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to log out. Please try again.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        foregroundColor: _primaryColor,
        title: const Text(
          "Customer Home",
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Appointment notifications",
            onPressed: openAppointmentStatus,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (finalizedAppointmentCount > 0)
                  Positioned(
                    top: -5,
                    right: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _backgroundColor, width: 1.5),
                      ),
                      child: Text(
                        finalizedAppointmentCount > 9
                            ? "9+"
                            : "$finalizedAppointmentCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Customer settings",
            onPressed: isLoggingOut
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerSettings(),
                      ),
                    );
                  },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: "Log out",
            onPressed: isLoggingOut ? null : logout,
            icon: isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: refreshCustomerHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: appPagePadding(context),
            child: AppResponsiveContent(
              maxWidth: 1120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: loggedInCustomerNameNotifier,
                    builder: (context, name, _) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: _borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.08),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 58,
                              width: 58,
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.directions_car_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name.isEmpty
                                  ? "NPJN Emission Testing Center"
                                  : "Welcome, $name",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Book your emission test appointment, check your appointment confirmation, and track your queue number.",
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.5,
                                color: _mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (_appointmentNotificationsLoading ||
                      _appointmentNotificationsError != null ||
                      latestAppointmentNotification != null) ...[
                    const SizedBox(height: 16),
                    buildAppointmentNotificationCard(),
                  ],

                  const SizedBox(height: 24),

                  const Text(
                    "What would you like to do?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(height: 14),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 16.0;
                      final columns = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 620
                          ? 2
                          : 1;
                      final cardWidth =
                          (constraints.maxWidth - (spacing * (columns - 1))) /
                          columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.calendar_month_rounded,
                              title: "Book Appointment",
                              subtitle:
                                  "Schedule your emission test before visiting the center.",
                              isFilled: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BookAppointment(),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.notifications_active_rounded,
                              title: "My Appointment Status",
                              subtitle:
                                  "Check if your appointment is pending, approved, or rejected.",
                              isFilled: false,
                              onTap: openAppointmentStatus,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.search_rounded,
                              title: "Track My Queue",
                              subtitle:
                                  "Check your queue position and estimated waiting time.",
                              isFilled: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TrackPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.05),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Services Offered",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.directions_car_rounded,
                          text: "Gasoline Vehicle Emission Test",
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.local_shipping_rounded,
                          text: "Diesel Vehicle Emission Test",
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.confirmation_number_rounded,
                          text: "Queue and Appointment Assistance",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.12),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Center Information",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          text: "Ligao City, Albay",
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          text: "Monday to Saturday",
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.groups_rounded,
                          text: "Daily queue limit: 80 customers",
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
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFilled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isFilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isFilled ? _primaryColor : _cardColor;
    final Color titleColor = isFilled ? Colors.white : _primaryColor;
    final Color subtitleColor = isFilled ? Colors.white70 : _mutedTextColor;
    final Color iconBackgroundColor = isFilled
        ? Colors.white.withOpacity(0.14)
        : _primaryColor.withOpacity(0.08);
    final Color iconColor = isFilled ? Colors.white : _primaryColor;
    final Color arrowColor = isFilled
        ? Colors.white70
        : _primaryColor.withOpacity(0.45);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      elevation: isFilled ? 4 : 2,
      shadowColor: _primaryColor.withOpacity(0.12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFilled ? _primaryColor : _primaryColor,
              width: isFilled ? 0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: _primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              color: _mutedTextColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
