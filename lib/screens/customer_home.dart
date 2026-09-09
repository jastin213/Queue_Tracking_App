import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../services/notification_time.dart';
import '../services/customer_preferences.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_responsive_content.dart';
import 'track_page.dart';
import 'book_appointment.dart';
import 'booking_status_page.dart';
import 'customer_login.dart';
import 'customer_register.dart';
import 'customer_settings.dart';

Color get _backgroundColor => AppColors.activeBackground;
Color get _primaryColor => AppColors.activePrimary;
Color get _cardColor => AppColors.activeSurface;
Color get _borderColor => AppColors.activeBorder;
Color get _mutedTextColor => AppColors.activeMutedText;

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final GlobalKey _notificationButtonKey = GlobalKey();
  bool isLoggingOut = false;
  List<Map<String, dynamic>> _customerAppointments = [];
  final Map<String, String> _knownAppointmentStatuses = {};
  final Set<String> _readAppointmentNotifications = {};
  late final String _notificationPreferenceKey;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _appointmentSubscription;
  bool _receivedInitialAppointmentSnapshot = false;

  @override
  void initState() {
    super.initState();
    _notificationPreferenceKey = _buildNotificationPreferenceKey();
    _initializeAppointmentNotifications();
  }

  String _buildNotificationPreferenceKey() {
    String accountId = loggedInCustomerIdNotifier.value.trim();
    try {
      accountId = FirebaseAuth.instance.currentUser?.uid ?? accountId;
    } catch (_) {
      // Firebase is unavailable only in isolated widget tests.
    }
    return "read_appointment_notifications_${accountId.isEmpty ? 'customer' : accountId}";
  }

  String _appointmentNotificationKey(Map<String, dynamic> appointment) {
    final id = appointment["appointmentId"]?.toString().trim() ?? "";
    final fallback = [
      appointment["queue"],
      appointment["date"],
      appointment["plate"],
    ].map((value) => value?.toString() ?? "").join("|");
    final status = appointment["status"]?.toString().trim() ?? "Pending";
    return "${id.isEmpty ? fallback : id}|$status";
  }

  Future<void> _initializeAppointmentNotifications() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _readAppointmentNotifications.addAll(
        preferences.getStringList(_notificationPreferenceKey) ?? const [],
      );
    } catch (_) {
      // Notifications still work for this session if local storage is blocked.
    }

    if (mounted) _listenToAppointmentNotifications();
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
        });

        if (changedAppointment != null &&
            customerAppointmentRemindersEnabledNotifier.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) showAppointmentStatusChanged(changedAppointment!);
          });
        }
      },
      onError: (Object error) {
        debugPrint("Appointment notification stream error: $error");
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

  String appointmentStatusTitle(String status) {
    if (status == "Approved") return "Appointment Approved";
    if (status == "Rejected") return "Appointment Rejected";
    return "Appointment Pending";
  }

  int get unreadAppointmentCount {
    return _customerAppointments.where((appointment) {
      return isFinalAppointmentStatus(appointment["status"]) &&
          !_readAppointmentNotifications.contains(
            _appointmentNotificationKey(appointment),
          );
    }).length;
  }

  Future<void> openAppointmentStatus() async {
    final readKeys = _customerAppointments
        .where((appointment) => isFinalAppointmentStatus(appointment["status"]))
        .map(_appointmentNotificationKey);

    setState(() {
      _readAppointmentNotifications.addAll(readKeys);
    });
    await _saveReadAppointmentNotifications();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookingStatusPage()),
    );
  }

  Future<void> showAppointmentNotificationPopover() async {
    final buttonContext = _notificationButtonKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final button = buttonContext?.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final allNotifications = _customerAppointments
        .where((appointment) => isFinalAppointmentStatus(appointment["status"]))
        .toList();
    final notifications = allNotifications.take(8).toList();
    final unreadKeysBeforeOpen = allNotifications
        .map(_appointmentNotificationKey)
        .where((key) => !_readAppointmentNotifications.contains(key))
        .toSet();
    if (unreadKeysBeforeOpen.isNotEmpty) {
      setState(
        () => _readAppointmentNotifications.addAll(unreadKeysBeforeOpen),
      );
      await _saveReadAppointmentNotifications();
      if (!mounted) return;
    }

    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final availableWidth = overlay.size.width - 24;
    final menuWidth = availableWidth < 360 ? availableWidth : 360.0;
    final desiredLeft = buttonTopLeft.dx + button.size.width - menuWidth;
    final maxLeft = overlay.size.width - menuWidth - 12;
    final left = desiredLeft.clamp(12.0, maxLeft).toDouble();
    final top = buttonTopLeft.dy + button.size.height + 6;

    final selectedId = await showMenu<String>(
      context: context,
      color: _cardColor,
      elevation: 14,
      constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _borderColor),
      ),
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left - menuWidth,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 54,
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: _primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Appointment Notifications",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (notifications.isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            height: 76,
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded, color: _mutedTextColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No current notifications",
                    style: TextStyle(color: _mutedTextColor),
                  ),
                ),
              ],
            ),
          )
        else
          ...notifications.map((appointment) {
            final status = appointment["status"]?.toString() ?? "Pending";
            final queue = appointment["queue"]?.toString() ?? "-";
            final date = appointment["date"]?.toString() ?? "-";
            final notificationKey = _appointmentNotificationKey(appointment);
            final isViewed = !unreadKeysBeforeOpen.contains(notificationKey);
            final contentColor = isViewed ? _mutedTextColor : _primaryColor;
            final time = formatNotificationTime(
              appointmentDecisionTime(appointment),
            );
            return PopupMenuItem<String>(
              value: notificationKey,
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isViewed
                          ? _mutedTextColor.withValues(alpha: 0.10)
                          : appointmentStatusColor(
                              status,
                            ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      status == "Approved"
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      color: isViewed
                          ? _mutedTextColor
                          : appointmentStatusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appointmentStatusTitle(status),
                          style: TextStyle(
                            color: contentColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Queue $queue • $date",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: contentColor, fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          time,
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isViewed ? "VIEWED" : "NEW",
                        style: TextStyle(
                          color: isViewed
                              ? _mutedTextColor
                              : appointmentStatusColor(status),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: _mutedTextColor),
                    ],
                  ),
                ],
              ),
            );
          }),
        if (notifications.isNotEmpty)
          const PopupMenuItem<String>(
            value: "__view_all__",
            height: 48,
            child: Center(
              child: Text(
                "VIEW ALL APPOINTMENTS",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );

    if (selectedId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingStatusPage()),
      );
    }
  }

  Future<void> _saveReadAppointmentNotifications() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _notificationPreferenceKey,
        _readAppointmentNotifications.toList(),
      );
    } catch (_) {
      // The badge is still cleared for the current session.
    }
  }

  void showAppointmentStatusChanged(Map<String, dynamic> appointment) {
    final status = appointment["status"]?.toString() ?? "Pending";
    final queue = appointment["queue"]?.toString() ?? "-";
    final color = appointmentStatusColor(status);
    final eventTime = formatNotificationTime(
      appointmentDecisionTime(appointment),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 6),
          content: Text(
            "Queue $queue: ${appointmentStatusTitle(status)} • $eventTime",
          ),
          action: SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: openAppointmentStatus,
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
      await _saveReadAppointmentNotifications();
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: customerAppLanguageNotifier,
          builder: (context, language, _) {
            final filipino = language == 'Filipino';
            return Scaffold(
              backgroundColor: _backgroundColor,
              appBar: AppBar(
                backgroundColor: _backgroundColor,
                elevation: 0,
                foregroundColor: _primaryColor,
                title: Text(
                  filipino ? "Tahanan ng Customer" : "Customer Home",
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                actions: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: appThemeModeNotifier,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return IconButton(
                        key: const Key('customer-theme-mode-toggle'),
                        tooltip: isDark
                            ? "Switch to light mode"
                            : "Switch to dark mode",
                        onPressed: () => setAppDarkMode(!isDark),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    key: _notificationButtonKey,
                    tooltip: "Appointment notifications",
                    onPressed: showAppointmentNotificationPopover,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined),
                        if (unreadAppointmentCount > 0)
                          Positioned(
                            top: -5,
                            right: -7,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              height: 17,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _backgroundColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                unreadAppointmentCount > 9
                                    ? "9+"
                                    : "$unreadAppointmentCount",
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
                                          : (filipino
                                                ? "Maligayang pagdating, $name"
                                                : "Welcome, $name"),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: _primaryColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      filipino
                                          ? "Mag-book ng emission test, tingnan ang kumpirmasyon, at subaybayan ang iyong queue number."
                                          : "Book your emission test appointment, check your appointment confirmation, and track your queue number.",
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

                          const SizedBox(height: 24),

                          Text(
                            filipino
                                ? "Ano ang nais mong gawin?"
                                : "What would you like to do?",
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
                                  (constraints.maxWidth -
                                      (spacing * (columns - 1))) /
                                  columns;

                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ActionCard(
                                      icon: Icons.calendar_month_rounded,
                                      title: filipino
                                          ? "Mag-book ng Appointment"
                                          : "Book Appointment",
                                      subtitle: filipino
                                          ? "Itakda ang emission test bago pumunta sa center."
                                          : "Schedule your emission test before visiting the center.",
                                      isFilled: true,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BookAppointment(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ActionCard(
                                      icon: Icons.notifications_active_rounded,
                                      title: filipino
                                          ? "Status ng Appointment"
                                          : "My Appointment Status",
                                      subtitle: filipino
                                          ? "Tingnan kung pending, approved, o rejected ang appointment."
                                          : "Check if your appointment is pending, approved, or rejected.",
                                      isFilled: false,
                                      onTap: openAppointmentStatus,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ActionCard(
                                      icon: Icons.search_rounded,
                                      title: filipino
                                          ? "Subaybayan ang Queue"
                                          : "Track My Queue",
                                      subtitle: filipino
                                          ? "Tingnan ang posisyon at tinatayang oras ng paghihintay."
                                          : "Check your queue position and estimated waiting time.",
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filipino
                                      ? "Mga Serbisyo"
                                      : "Services Offered",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: _primaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _InfoRow(
                                  icon: Icons.directions_car_rounded,
                                  text: filipino
                                      ? "Emission Test para sa Gasoline Vehicle"
                                      : "Gasoline Vehicle Emission Test",
                                ),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  icon: Icons.local_shipping_rounded,
                                  text: filipino
                                      ? "Emission Test para sa Diesel Vehicle"
                                      : "Diesel Vehicle Emission Test",
                                ),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  icon: Icons.confirmation_number_rounded,
                                  text: filipino
                                      ? "Tulong sa Queue at Appointment"
                                      : "Queue and Appointment Assistance",
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filipino
                                      ? "Impormasyon ng Center"
                                      : "Center Information",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: _primaryColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const _InfoRow(
                                  icon: Icons.location_on_rounded,
                                  text: "Ligao City, Albay",
                                ),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  icon: Icons.access_time_rounded,
                                  text: filipino
                                      ? "Lunes hanggang Sabado"
                                      : "Monday to Saturday",
                                ),
                                const SizedBox(height: 10),
                                _InfoRow(
                                  icon: Icons.groups_rounded,
                                  text: filipino
                                      ? "Arawang queue limit: 80 customer"
                                      : "Daily queue limit: 80 customers",
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
          },
        );
      },
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
            style: TextStyle(
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
