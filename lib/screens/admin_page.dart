import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appointment_lifecycle.dart';
import '../services/admin_notification_event.dart';
import '../services/admin_notification_read_state.dart';
import '../services/browser_tab_opener.dart';
import '../services/daily_queue_capacity.dart';
import '../services/daily_queue_capacity_service.dart';
import '../services/notification_time.dart';
import '../services/queue_source.dart';
import '../services/queue_voice.dart';
import '../services/remembered_login.dart';
import '../services/vehicle_category.dart';
import '../theme/app_theme.dart';
import '../services/firestore_query_fields.dart';
import '../widgets/app_responsive_content.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_motion.dart';
import '../widgets/admin_notification_snackbar.dart';
import '../widgets/vehicle_category_field.dart';
import 'analytics_page.dart';
import 'daily_report.dart';
import 'display_page.dart';
import 'admin_dashboard.dart';
import 'home_page.dart';
import 'admin_settings.dart';

// ================= COLOR THEME =================

Color get _backgroundColor => AppColors.activeBackground;
Color get _primaryColor => AppColors.activePrimary;
Color get _cardColor => AppColors.activeSurface;
Color get _borderColor => AppColors.activeBorder;
Color get _mutedTextColor => AppColors.activeMutedText;
Color get _softPrimaryColor => AppColors.activeSoftPrimary;

bool _isWalkInCapacityRecord(Map<String, dynamic> record) {
  final source = record['quotaSource']?.toString().trim().toLowerCase();
  if (source == 'appointment') return false;
  if (source == 'walkin') return true;
  return normalizedQueueSource(record) == walkInQueueSource;
}

bool useMobileWebStatsRow({required bool isWeb, required double width}) {
  return isWeb && width < 600;
}

// ================= GLOBAL VARIABLES =================

ValueNotifier<Map<String, List<Map<String, dynamic>>>>
dailyServedReportNotifier = ValueNotifier({});

ValueNotifier<Map<String, List<Map<String, dynamic>>>>
dailyFailedReportNotifier = ValueNotifier({});

ValueNotifier<Map<String, List<String>>> dailyHistoryNotifier = ValueNotifier(
  {},
);

ValueNotifier<List<Map<String, dynamic>>> waitingQueueNotifier = ValueNotifier(
  [],
);

ValueNotifier<Map<String, dynamic>?> nowServingNotifier = ValueNotifier(null);

ValueNotifier<String> selectedQueueDateNotifier = ValueNotifier(
  formatDate(DateTime.now()),
);

ValueNotifier<Map<String, List<String>>> issuedQueueCodesNotifier =
    ValueNotifier({});

int totalQueue = 0;
int completedQueue = 0;

int gasCounter = 1;
int dieselCounter = 1;

const int maxQueueLimit = 80;

// ================= DATE FORMAT =================

String formatDate(DateTime date) {
  return "${date.month}/${date.day}/${date.year}";
}

String _normalizeWalkInPlateNumber(String value) {
  return value.trim().toUpperCase();
}

String? _validateWalkInPlateNumber(String value) {
  final String plateNumber = _normalizeWalkInPlateNumber(value);

  if (plateNumber.isEmpty) {
    return "Please enter the vehicle plate number";
  }

  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(plateNumber)) {
    return "Use letters and numbers only—no spaces or symbols";
  }

  if (plateNumber.length < 6 || plateNumber.length > 7) {
    return "Plate number must contain 6–7 characters";
  }

  if (!RegExp(r'[A-Z]').hasMatch(plateNumber) ||
      !RegExp(r'[0-9]').hasMatch(plateNumber)) {
    return "Plate number must include both letters and digits";
  }

  return null;
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ================= ADMIN PAGE =================

enum _DisplayDestination { newTabOpened, newTabBlocked, currentTab }

enum _AdminSessionStatus { authorized, unauthorized, unavailable }

enum _AdminSection { queue, appointments, reports, analytics, settings }

class _AdminSessionExpiredException implements Exception {
  const _AdminSessionExpiredException();
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FlutterTts flutterTts = FlutterTts();
  final GlobalKey _adminNotificationButtonKey = GlobalKey();
  final GlobalKey<ScaffoldState> _mobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  String _lastScheduledQueueSignature = "";
  bool _isGeneratingQueue = false;
  bool _isRefreshingQueue = false;
  bool _isAdminSessionReady = false;
  bool _isCheckingAdminSession = true;
  bool _isReturningToLogin = false;
  bool _isCallingCustomer = false;
  DailyQueueCapacityPolicy _capacityPolicy = const DailyQueueCapacityPolicy();
  StreamSubscription<DailyQueueCapacityPolicy>? _capacityPolicySubscription;
  bool _capacityPolicyReady = false;
  StreamSubscription<Map<String, dynamic>>? _completedCapacitySubscription;
  Map<String, dynamic> _completedCapacityClaims = {};
  bool _completedCapacityReady = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _capacityAppointmentsSubscription;
  List<Map<String, dynamic>> _capacityAppointments = [];
  bool _capacityAppointmentsReady = false;
  bool _desktopSidebarVisible = true;
  _AdminSection _activeAdminSection = _AdminSection.queue;
  String? _initialAppointmentId;
  int _appointmentPageRevision = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _pendingAppointmentSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _automaticDecisionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _notificationReadStateSubscription;
  List<Map<String, dynamic>> _pendingAppointments = [];
  List<Map<String, dynamic>> _automaticDecisionNotifications = [];
  final Set<String> _readPendingAppointmentNotifications = <String>{};
  late final String _notificationAccountId;
  late final String _adminNotificationPreferenceKey;
  final DateTime _notificationSessionStartedAt = DateTime.now();
  late final AdminNotificationPopupGate _pendingNotificationPopupGate;
  late final AdminNotificationPopupGate _automaticNotificationPopupGate;
  bool _notificationReadStateReady = false;
  Future<void> _localNotificationReadSave = Future<void>.value();
  final _notificationSnackBar = AdminNotificationSnackBarPresenter();

  @override
  void initState() {
    super.initState();
    _notificationAccountId = _currentNotificationAccountId();
    _adminNotificationPreferenceKey = _buildAdminNotificationPreferenceKey();
    _pendingNotificationPopupGate = AdminNotificationPopupGate(
      sessionStartedAt: _notificationSessionStartedAt,
    );
    _automaticNotificationPopupGate = AdminNotificationPopupGate(
      sessionStartedAt: _notificationSessionStartedAt,
    );
    unawaited(_initializeAdminSession());
    _initializeAppointmentNotifications();
    _capacityPolicySubscription = DailyQueueCapacityService.watchPolicy()
        .listen(
          (policy) {
            if (!mounted) return;
            setState(() {
              _capacityPolicy = policy;
              _capacityPolicyReady = true;
            });
          },
          onError: (_) {
            if (mounted) setState(() => _capacityPolicyReady = false);
          },
        );
    selectedQueueDateNotifier.addListener(_watchCompletedCapacity);
    _watchCompletedCapacity();
  }

  void _watchCompletedCapacity() {
    _completedCapacitySubscription?.cancel();
    _capacityAppointmentsSubscription?.cancel();
    final date = selectedQueueDateNotifier.value;
    _completedCapacityClaims = {};
    _completedCapacityReady = false;
    _capacityAppointments = [];
    _capacityAppointmentsReady = false;
    _capacityAppointmentsSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: date)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || date != selectedQueueDateNotifier.value) return;
            setState(() {
              _capacityAppointments = snapshot.docs
                  .map((doc) => {...doc.data(), 'appointmentId': doc.id})
                  .toList();
              _capacityAppointmentsReady = true;
            });
          },
          onError: (_) {
            if (mounted && date == selectedQueueDateNotifier.value) {
              setState(() => _capacityAppointmentsReady = false);
            }
          },
        );
    _completedCapacitySubscription =
        DailyQueueCapacityService.watchCompletedClaims(date).listen(
          (claims) {
            if (!mounted || date != selectedQueueDateNotifier.value) return;
            setState(() {
              _completedCapacityClaims = claims;
              _completedCapacityReady = true;
            });
          },
          onError: (_) {
            if (mounted && date == selectedQueueDateNotifier.value) {
              setState(() => _completedCapacityReady = false);
            }
          },
        );
  }

  Future<_AdminSessionStatus> _verifyAdminSession({
    bool forceTokenRefresh = false,
  }) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return _AdminSessionStatus.unauthorized;

      if (forceTokenRefresh) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
        if (user == null) return _AdminSessionStatus.unauthorized;
      }

      await user.getIdToken(forceTokenRefresh);
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final role = (profile.data()?['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      return role == 'admin'
          ? _AdminSessionStatus.authorized
          : _AdminSessionStatus.unauthorized;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = <String>{
        'invalid-user-token',
        'user-token-expired',
        'user-disabled',
        'user-not-found',
      };
      return invalidSessionCodes.contains(error.code)
          ? _AdminSessionStatus.unauthorized
          : _AdminSessionStatus.unavailable;
    } on FirebaseException catch (error) {
      return error.code == 'permission-denied' ||
              error.code == 'unauthenticated'
          ? _AdminSessionStatus.unauthorized
          : _AdminSessionStatus.unavailable;
    } catch (_) {
      return _AdminSessionStatus.unavailable;
    }
  }

  Future<void> _initializeAdminSession() async {
    var status = await _verifyAdminSession();
    if (status != _AdminSessionStatus.authorized) {
      // A restored browser tab can briefly hold an outdated token. Refresh it
      // once before deciding that the administrator must sign in again.
      status = await _verifyAdminSession(forceTokenRefresh: true);
    }
    if (!mounted) return;

    setState(() {
      _isCheckingAdminSession = false;
      _isAdminSessionReady = status == _AdminSessionStatus.authorized;
    });

    if (status == _AdminSessionStatus.unauthorized) {
      await _returnToLoginForExpiredAdminSession();
      return;
    }

    if (status == _AdminSessionStatus.unavailable) {
      _showAdminSessionUnavailableMessage();
    }
  }

  void _showAdminSessionUnavailableMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text(
            'Unable to verify the admin session. Check your connection and press Refresh.',
          ),
        ),
      );
  }

  Future<bool> _recoverAdminSession() async {
    if (!mounted) return false;
    setState(() {
      _isCheckingAdminSession = true;
      _isAdminSessionReady = false;
    });

    final status = await _verifyAdminSession(forceTokenRefresh: true);
    if (!mounted) return false;

    setState(() {
      _isCheckingAdminSession = false;
      _isAdminSessionReady = status == _AdminSessionStatus.authorized;
    });

    if (status == _AdminSessionStatus.authorized) return true;
    return false;
  }

  Future<void> _returnToLoginForExpiredAdminSession() async {
    if (_isReturningToLogin) return;
    _isReturningToLogin = true;

    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    await signOutAndClearRememberedLogin();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text('Admin session expired. Please sign in again.'),
        ),
      );
  }

  Future<String> _saveQueueWithSessionRecovery(
    Future<String> Function() save,
  ) async {
    try {
      return await save();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' &&
          error.code != 'unauthenticated') {
        rethrow;
      }
    }

    final recovered = await _recoverAdminSession();
    if (!recovered) throw const _AdminSessionExpiredException();

    try {
      // The same request ID makes a recovered save return its original ticket.
      return await save();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        throw const _AdminSessionExpiredException();
      }
      rethrow;
    }
  }

  String _currentNotificationAccountId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  bool get _notificationOwnerIsCurrent =>
      _notificationAccountId.isNotEmpty &&
      _currentNotificationAccountId() == _notificationAccountId;

  String _buildAdminNotificationPreferenceKey() {
    return 'read_v3_admin_appointment_notifications_${_notificationAccountId.isEmpty ? 'admin' : _notificationAccountId}';
  }

  String _adminAppointmentNotificationKey(Map<String, dynamic> appointment) {
    return adminNotificationEvent(appointment)?.key ??
        'unavailable:${appointment['appointmentId']}';
  }

  bool _isAdminAppointmentNotificationRead(Map<String, dynamic> appointment) {
    return adminNotificationEvent(appointment)?.isRead(
          _readPendingAppointmentNotifications,
          legacyReadBefore: _notificationSessionStartedAt,
        ) ??
        false;
  }

  void _markAdminAppointmentNotificationRead(Map<String, dynamic> appointment) {
    _readPendingAppointmentNotifications.add(
      _adminAppointmentNotificationKey(appointment),
    );
  }

  Future<void> _initializeAppointmentNotifications() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _readPendingAppointmentNotifications.addAll(
        mergeAdminNotificationReadKeys(
          _readPendingAppointmentNotifications,
          preferences.getStringList(_adminNotificationPreferenceKey),
        ),
      );
    } catch (_) {
      // Notifications retain their in-memory read state if local storage fails.
    }

    if (!mounted || !_notificationOwnerIsCurrent) return;
    _listenToNotificationReadState();
    _listenToPendingAppointments();
    _listenToAutomaticDecisionNotifications();
  }

  void _listenToNotificationReadState() {
    final accountId = _notificationAccountId;
    _notificationReadStateSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(accountId)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted || !_notificationOwnerIsCurrent) return;
            final storedKeys = snapshot.data()?['adminReadNotificationKeysV3'];
            final mergedKeys = mergeAdminNotificationReadKeys(
              _readPendingAppointmentNotifications,
              storedKeys,
            );
            final changed =
                mergedKeys.length !=
                _readPendingAppointmentNotifications.length;
            setState(() {
              _readPendingAppointmentNotifications.addAll(mergedKeys);
              if (snapshot.metadata.isFromCache) {
                _notificationReadStateReady = false;
              } else if (!snapshot.metadata.hasPendingWrites) {
                _notificationReadStateReady = true;
              }
            });
            if (changed) {
              unawaited(_saveLocalReadAdminAppointmentNotifications());
            }

            final activeKey = _notificationSnackBar.activeEventKey;
            if (activeKey != null &&
                _readPendingAppointmentNotifications.contains(activeKey)) {
              _closeActiveAdminNotification();
            }

            // Merge receipts instead of overwriting another device's reads.
            // Sync offline/local receipts once the server connection returns.
            if (_notificationReadStateReady &&
                adminNotificationReadKeysToSync(
                  local: _readPendingAppointmentNotifications,
                  cloud: storedKeys,
                ).isNotEmpty) {
              unawaited(_saveReadAdminAppointmentNotifications());
            }
          },
          onError: (Object error) {
            if (!mounted || !_notificationOwnerIsCurrent) return;
            setState(() => _notificationReadStateReady = false);
            debugPrint('Admin notification read-state sync is unavailable.');
          },
        );
  }

  Future<void> _saveLocalReadAdminAppointmentNotifications() {
    _localNotificationReadSave = _localNotificationReadSave.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final keys = _readPendingAppointmentNotifications.toList()..sort();
        await preferences.setStringList(_adminNotificationPreferenceKey, keys);
      } catch (_) {
        // Firebase remains the cross-device copy when local storage is blocked.
      }
    });
    return _localNotificationReadSave;
  }

  Future<void> _saveReadAdminAppointmentNotifications() async {
    final accountId = _notificationAccountId;
    final readKeys = _readPendingAppointmentNotifications.toList()..sort();
    await _saveLocalReadAdminAppointmentNotifications();
    if (!mounted ||
        !_notificationOwnerIsCurrent ||
        !_notificationReadStateReady ||
        readKeys.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(accountId)
          .set({
            'adminReadNotificationKeysV3': FieldValue.arrayUnion(readKeys),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Reads remain local and are merged back when the server is reachable.
      debugPrint('Admin notification receipts are waiting to sync.');
    }
  }

  @override
  void dispose() {
    selectedQueueDateNotifier.removeListener(_watchCompletedCapacity);
    _completedCapacitySubscription?.cancel();
    _capacityAppointmentsSubscription?.cancel();
    _capacityPolicySubscription?.cancel();
    _pendingAppointmentSubscription?.cancel();
    _automaticDecisionSubscription?.cancel();
    _notificationReadStateSubscription?.cancel();
    _closeActiveAdminNotification();
    flutterTts.stop();
    super.dispose();
  }

  void _listenToPendingAppointments() {
    _pendingAppointmentSubscription = FirebaseFirestore.instance
        .collection("appointments")
        .where("status", isEqualTo: "Pending")
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted || !_notificationOwnerIsCurrent) return;
            unawaited(
              expirePastPendingAppointmentDocuments(
                snapshot.docs,
              ).catchError((_) => 0),
            );

            final appointments = snapshot.docs
                .where((doc) => !isPastPendingAppointment(doc.data()))
                .map((doc) => {...doc.data(), 'appointmentId': doc.id})
                .toList();
            appointments.sort((a, b) {
              final aTime = notificationDateTime(a['createdAt']);
              final bTime = notificationDateTime(b['createdAt']);
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            final newest = _pendingNotificationPopupGate.consider(
              events: appointments
                  .map(adminNotificationEvent)
                  .whereType<AdminNotificationEvent>(),
              fromCache:
                  snapshot.metadata.isFromCache ||
                  snapshot.metadata.hasPendingWrites,
              readStateReady: _notificationReadStateReady,
              readKeys: _readPendingAppointmentNotifications,
              now: DateTime.now(),
            );
            setState(() => _pendingAppointments = appointments);
            if (newest != null) {
              _scheduleAdminNotificationPopup(
                newest,
                _pendingNotificationPopupGate,
              );
            }
          },
          onError: (Object error) {
            debugPrint('Admin appointment notifications are unavailable.');
          },
        );
  }

  void _listenToAutomaticDecisionNotifications() {
    _automaticDecisionSubscription = FirebaseFirestore.instance
        .collection('appointments')
        .where(
          'decisionSource',
          whereIn: const [
            'conditional_auto_approval',
            'conditional_auto_rejection',
          ],
        )
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (!mounted || !_notificationOwnerIsCurrent) return;
            final events = snapshot.docs
                .map((doc) {
                  final event = adminNotificationEvent({
                    ...doc.data(),
                    'appointmentId': doc.id,
                  });
                  // Do not expose a provisional, untimestamped decision in
                  // history before its write has been acknowledged.
                  if (doc.metadata.hasPendingWrites &&
                      event?.occurredAt == null) {
                    return null;
                  }
                  return event;
                })
                .whereType<AdminNotificationEvent>()
                .where(
                  (event) => event.kind != AdminNotificationEventKind.pending,
                )
                .toList();
            events.sort((a, b) {
              final aTime = a.occurredAt;
              final bTime = b.occurredAt;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            final newest = _automaticNotificationPopupGate.consider(
              events: events,
              fromCache:
                  snapshot.metadata.isFromCache ||
                  snapshot.metadata.hasPendingWrites,
              readStateReady: _notificationReadStateReady,
              readKeys: _readPendingAppointmentNotifications,
              now: DateTime.now(),
            );
            setState(() {
              _automaticDecisionNotifications = events
                  .take(30)
                  .map((event) => event.appointment)
                  .toList();
            });
            if (newest != null) {
              _scheduleAdminNotificationPopup(
                newest,
                _automaticNotificationPopupGate,
              );
            }
          },
          onError: (Object error) {
            debugPrint(
              'Admin automatic decision notifications are unavailable.',
            );
          },
        );
  }

  void _scheduleAdminNotificationPopup(
    AdminNotificationEvent event,
    AdminNotificationPopupGate gate,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _notificationOwnerIsCurrent) {
        _showNewAppointmentNotification(event, gate);
      }
    });
  }

  DateTime? _adminNotificationTime(Map<String, dynamic> appointment) =>
      adminNotificationEvent(appointment)?.occurredAt;

  List<Map<String, dynamic>> get _adminAppointmentNotifications {
    final notifications = <Map<String, dynamic>>[
      ..._pendingAppointments,
      ..._automaticDecisionNotifications,
    ];
    notifications.sort((a, b) {
      final aTime = notificationDateTime(_adminNotificationTime(a));
      final bTime = notificationDateTime(_adminNotificationTime(b));
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return notifications;
  }

  void _selectAdminSection(_AdminSection section, {String? appointmentId}) {
    final requestedAppointmentId = appointmentId?.trim() ?? '';
    setState(() {
      _activeAdminSection = section;
      _initialAppointmentId = requestedAppointmentId.isEmpty
          ? null
          : requestedAppointmentId;
      if (requestedAppointmentId.isNotEmpty) {
        _appointmentPageRevision++;
      }
    });

    if (requestedAppointmentId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialAppointmentId != requestedAppointmentId) return;
        setState(() => _initialAppointmentId = null);
      });
    }
  }

  void _openAppointmentDashboard() {
    _selectAdminSection(_AdminSection.appointments);
  }

  void _openAppointmentDetails(Map<String, dynamic> appointment) {
    final appointmentId = appointment['appointmentId']?.toString().trim() ?? '';

    if (appointmentId.isEmpty) {
      _openAppointmentDashboard();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text(
              'This older notification is not linked to an appointment.',
            ),
          ),
        );
      return;
    }

    if (openAppointmentDetailsInActiveAdminDashboard(appointmentId)) {
      return;
    }

    _selectAdminSection(
      _AdminSection.appointments,
      appointmentId: appointmentId,
    );
  }

  Future<void> _openAdminAppointmentNotification(
    Map<String, dynamic> appointment,
  ) async {
    if (!mounted || !_notificationOwnerIsCurrent) return;
    if (!_isAdminAppointmentNotificationRead(appointment)) {
      setState(() => _markAdminAppointmentNotificationRead(appointment));
      unawaited(_saveReadAdminAppointmentNotifications());
    }
    if (_notificationSnackBar.activeEventKey ==
        _adminAppointmentNotificationKey(appointment)) {
      _closeActiveAdminNotification();
    }
    _openAppointmentDetails(appointment);
  }

  void _closeActiveAdminNotification() {
    _notificationSnackBar.dismiss();
  }

  void _showNewAppointmentNotification(
    AdminNotificationEvent event,
    AdminNotificationPopupGate gate,
  ) {
    if (!mounted ||
        !_notificationOwnerIsCurrent ||
        !_isAdminSessionReady ||
        _isReturningToLogin ||
        !gate.canPresent(
          event,
          readKeys: _readPendingAppointmentNotifications,
          now: DateTime.now(),
          readStateReady: _notificationReadStateReady,
        ) ||
        !_adminAppointmentNotifications.any(
          (item) => _adminAppointmentNotificationKey(item) == event.key,
        )) {
      return;
    }
    final appointment = event.appointment;
    final name =
        (appointment["fullName"] ?? appointment["customerName"] ?? "Customer")
            .toString();
    final queue = appointment["queue"]?.toString() ?? "-";
    final eventTime = formatNotificationTime(
      _adminNotificationTime(appointment),
    );
    final score = appointment['autoApprovalReview'] is Map
        ? (appointment['autoApprovalReview'] as Map)['score']?.toString()
        : null;
    final message = switch (event.kind) {
      AdminNotificationEventKind.autoApproved =>
        'Automatically approved $name • Queue $queue • Score ${score ?? '-'} / 100 • $eventTime',
      AdminNotificationEventKind.autoRejected =>
        'Automatically rejected $name • Queue $queue • Score ${score ?? '0'} / 100 • $eventTime',
      AdminNotificationEventKind.pending =>
        'New appointment from $name • Queue $queue • $eventTime',
    };

    _notificationSnackBar.show(
      messenger: ScaffoldMessenger.of(context),
      eventKey: event.key,
      content: Text(message),
      onCheck: () {
        unawaited(_openAdminAppointmentNotification(appointment));
      },
    );
  }

  Widget _buildAppointmentNotificationButton() {
    final count = _adminAppointmentNotifications.where((appointment) {
      return !_isAdminAppointmentNotificationRead(appointment);
    }).length;
    return SizedBox(
      key: _adminNotificationButtonKey,
      child: IconButton(
        key: const Key("admin-appointment-notifications"),
        tooltip: count == 0
            ? "No new appointment notifications"
            : "$count new appointment notification${count == 1 ? '' : 's'}",
        onPressed: _showAppointmentNotifications,
        icon: AppNotificationBell(count: count, badgeBorderColor: _cardColor),
      ),
    );
  }

  Future<void> _showAppointmentNotifications() async {
    final buttonContext = _adminNotificationButtonKey.currentContext;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final button = buttonContext?.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final notifications = _adminAppointmentNotifications.take(8).toList();

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
            final name =
                (appointment['fullName'] ??
                        appointment['customerName'] ??
                        'Customer')
                    .toString();
            final queue = appointment['queue']?.toString() ?? '-';
            final plate = appointment['plate']?.toString() ?? '-';
            final date = appointment['date']?.toString() ?? '-';
            final eventKind = adminNotificationEvent(appointment)?.kind;
            final isAutoApproved =
                eventKind == AdminNotificationEventKind.autoApproved;
            final isAutoRejected =
                eventKind == AdminNotificationEventKind.autoRejected;
            final accentColor = isAutoApproved
                ? AppColors.success
                : isAutoRejected
                ? AppColors.danger
                : AppColors.warning;
            final notificationIcon = isAutoApproved
                ? Icons.verified_rounded
                : isAutoRejected
                ? Icons.gpp_bad_rounded
                : Icons.event_note_rounded;
            final score = appointment['autoApprovalReview'] is Map
                ? (appointment['autoApprovalReview'] as Map)['score']
                      ?.toString()
                : null;
            final notificationTitle = isAutoApproved
                ? 'Automatically approved $name'
                : isAutoRejected
                ? 'Automatically rejected $name'
                : 'New appointment from $name';
            final notificationSubtitle = isAutoApproved || isAutoRejected
                ? 'Queue $queue • Score ${score ?? (isAutoRejected ? '0' : '-')} / 100'
                : 'Queue $queue • Plate $plate';
            final notificationKey = _adminAppointmentNotificationKey(
              appointment,
            );
            final isViewed = _isAdminAppointmentNotificationRead(appointment);
            final contentColor = isViewed ? _mutedTextColor : _primaryColor;
            final time = formatNotificationTime(
              _adminNotificationTime(appointment),
            );

            return PopupMenuItem<String>(
              value: notificationKey,
              height: 108,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isViewed
                      ? Colors.transparent
                      : accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isViewed
                            ? _mutedTextColor.withValues(alpha: 0.10)
                            : accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        notificationIcon,
                        color: isViewed ? _mutedTextColor : accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notificationTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: contentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notificationSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: contentColor, fontSize: 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "$date • $time",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        if (!isViewed)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!isViewed) const SizedBox(height: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _mutedTextColor,
                        ),
                      ],
                    ),
                  ],
                ),
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

    if (selectedId == null || !mounted) return;
    if (selectedId == "__view_all__") {
      _openAppointmentDashboard();
      return;
    }

    final selectedAppointment = notifications.firstWhere(
      (appointment) =>
          _adminAppointmentNotificationKey(appointment) == selectedId,
      orElse: () => <String, dynamic>{},
    );
    if (selectedAppointment.isNotEmpty) {
      await _openAdminAppointmentNotification(selectedAppointment);
    }
  }

  Widget _buildThemeModeButton() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          key: const Key('admin-theme-mode-toggle'),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => setAppDarkMode(!isDark),
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        );
      },
    );
  }

  bool get isFilipino => appLanguageNotifier.value == "Filipino";

  String text(String english, String filipino) {
    return isFilipino ? filipino : english;
  }

  void _openDisplayInCurrentTab() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DisplayPage()),
    );
  }

  Future<void> _openDisplayPage() async {
    if (!kIsWeb) {
      _openDisplayInCurrentTab();
      return;
    }

    final destination = await showDialog<_DisplayDestination>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.tv_rounded, color: _primaryColor),
              const SizedBox(width: 10),
              const Expanded(child: Text('Open Display Page')),
            ],
          ),
          content: Text(
            'Open the customer-facing queue display in a separate tab so the '
            'Admin Control Panel stays private and available for multitasking.',
            style: TextStyle(
              color: _mutedTextColor,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DisplayDestination.currentTab),
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('OPEN HERE'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final opened = openBrowserTab(displayPageUri(Uri.base));
                Navigator.pop(
                  dialogContext,
                  opened
                      ? _DisplayDestination.newTabOpened
                      : _DisplayDestination.newTabBlocked,
                );
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('OPEN NEW TAB'),
            ),
          ],
        );
      },
    );

    if (!mounted || destination == null) return;
    if (destination == _DisplayDestination.currentTab) {
      _openDisplayInCurrentTab();
      return;
    }

    if (destination == _DisplayDestination.newTabBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The browser blocked the display tab. Please allow pop-ups for this '
            'website and try again.',
          ),
        ),
      );
    }
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

  Stream<List<Map<String, dynamic>>> queueItemsStream(String date) {
    return queueItemsRef(date).orderBy("createdAt").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {...data, "queueId": data["queueId"] ?? doc.id};
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getQueueItemsOnline(
    String date, {
    bool forceServer = false,
  }) async {
    final snapshot = await queueItemsRef(date)
        .orderBy("createdAt")
        .get(forceServer ? const GetOptions(source: Source.server) : null);

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {...data, "queueId": data["queueId"] ?? doc.id};
    }).toList();
  }

  Future<void> refreshQueue() async {
    final String selectedDate = selectedQueueDateNotifier.value;
    final onlineItems = await getQueueItemsOnline(
      selectedDate,
      forceServer: true,
    );

    if (!mounted) return;

    syncLocalQueueFromFirestore(onlineItems);
    setState(() {});
  }

  Future<void> refreshQueueFromControl() async {
    if (_isRefreshingQueue) return;

    setState(() {
      _isRefreshingQueue = true;
    });

    try {
      if (!_isAdminSessionReady) {
        final status = await _verifyAdminSession(forceTokenRefresh: true);
        if (!mounted) return;

        setState(() {
          _isCheckingAdminSession = false;
          _isAdminSessionReady = status == _AdminSessionStatus.authorized;
        });

        if (status == _AdminSessionStatus.unauthorized) {
          await _returnToLoginForExpiredAdminSession();
          return;
        }
        if (status == _AdminSessionStatus.unavailable) {
          _showAdminSessionUnavailableMessage();
          return;
        }
      }

      await refreshQueue();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 190,
            duration: Duration(milliseconds: 900),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: StadiumBorder(),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 7),
                Text(
                  "Refreshed just now",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            width: 270,
            backgroundColor: Colors.red,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: StadiumBorder(),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 7),
                Text(
                  "Unable to refresh. Please try again.",
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingQueue = false;
        });
      }
    }
  }

  bool isActiveQueueStatus(String status) {
    return status == "Waiting" ||
        status == "Now Serving" ||
        status == "Skipped";
  }

  void syncLocalQueueFromFirestore(List<Map<String, dynamic>> onlineItems) {
    final String selectedDate = selectedQueueDateNotifier.value;

    final waiting = onlineItems.where((item) {
      final status = item["status"]?.toString() ?? "Waiting";
      return item["date"] == selectedDate &&
          (status == "Waiting" || status == "Skipped");
    }).toList();

    final nowServingList = onlineItems.where((item) {
      return item["date"] == selectedDate &&
          item["status"]?.toString() == "Now Serving";
    }).toList();

    final passedList = onlineItems.where((item) {
      return item["date"] == selectedDate &&
          item["status"]?.toString() == "Passed";
    }).toList();

    final failedList = onlineItems.where((item) {
      return item["date"] == selectedDate &&
          item["status"]?.toString() == "Failed";
    }).toList();

    final issuedList = onlineItems
        .where((item) {
          final status = item["status"]?.toString() ?? "";
          return item["date"] == selectedDate &&
              status != "Cancelled" &&
              status != "Reset";
        })
        .map((item) {
          return item["queue"].toString();
        })
        .toList();

    waitingQueueNotifier.value = waiting;

    nowServingNotifier.value = nowServingList.isEmpty
        ? null
        : nowServingList.last;

    issuedQueueCodesNotifier.value = {
      ...issuedQueueCodesNotifier.value,
      selectedDate: issuedList,
    };

    dailyServedReportNotifier.value = {
      ...dailyServedReportNotifier.value,
      selectedDate: passedList,
    };

    dailyFailedReportNotifier.value = {
      ...dailyFailedReportNotifier.value,
      selectedDate: failedList,
    };
  }

  void scheduleQueueSyncAfterBuild(
    String selectedDate,
    List<Map<String, dynamic>> onlineItems,
  ) {
    final signature = <String>[
      selectedDate,
      for (final item in onlineItems)
        "${item["queueId"] ?? item["queue"]}|${item["status"]}|${item["skipSequence"]}|${item["updatedAt"]}",
    ].join("~");

    if (signature == _lastScheduledQueueSignature) return;
    _lastScheduledQueueSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || selectedQueueDateNotifier.value != selectedDate) return;
      syncLocalQueueFromFirestore(onlineItems);
    });
  }

  Future<bool> queueCodeExistsOnline({
    required String date,
    required String queueCode,
  }) async {
    final snapshot = await queueItemsRef(date).doc(queueCode).get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    if (data == null) {
      return false;
    }

    final status = data["status"]?.toString() ?? "";

    return status != "Cancelled" && status != "Reset";
  }

  Future<String> generateNextAvailableQueueCodeOnline(String type) async {
    final String selectedDate = selectedQueueDateNotifier.value;
    final String prefix = type == "Gas" ? "G" : "D";

    for (int number = 1; number <= maxQueueLimit; number++) {
      final String queueCode = "$prefix${number.toString().padLeft(3, '0')}";

      final bool existsLocally = queueCodeExistsOnSelectedDate(queueCode);
      final bool existsOnline = await queueCodeExistsOnline(
        date: selectedDate,
        queueCode: queueCode,
      );

      if (!existsLocally && !existsOnline) {
        return queueCode;
      }
    }

    return "";
  }

  Future<void> updateQueueItemStatus({
    required Map<String, dynamic> customer,
    required String status,
    Map<String, dynamic>? extraData,
  }) async {
    final String date =
        customer["date"]?.toString() ?? selectedQueueDateNotifier.value;
    final String queue = customer["queue"]?.toString() ?? "";

    if (date.isEmpty || queue.isEmpty) return;

    final reference = queueItemsRef(date).doc(queue);
    await DailyQueueCapacityService.runDayTransaction<void>(date, (
      transaction,
      day,
    ) async {
      final snapshot = await transaction.get(reference);
      final current = snapshot.data();
      if (current == null) {
        throw StateError(
          'This queue record changed. Refresh before trying again.',
        );
      }
      final updates =
          <String, dynamic>{
            ...customer,
            "queueId": queue,
            "queue": queue,
            "date": date,
            "status": status,
            ...firestoreQueryFields(
              date: date,
              plate: customer["plate"],
              name: customer["name"] ?? customer["fullName"],
            ),
            "updatedAt": FieldValue.serverTimestamp(),
            ...?extraData,
          }..removeWhere(
            (key, _) => const {
              'queueId',
              'queue',
              'date',
              'appointmentId',
              'capacityRequestId',
              'quotaSource',
              '_appointmentDocumentPath',
            }.contains(key),
          );
      if (status == 'Passed' || status == 'Failed') {
        day.completeQueue({...current, ...updates});
      } else if ((status == 'Cancelled' || status == 'Reset') &&
          _isWalkInCapacityRecord(current)) {
        day.releaseWalkIn(queue);
      }
      transaction.set(reference, updates, SetOptions(merge: true));
    });
  }

  // ================= SPEAK =================

  Future<void> speak(String queueNumber) async {
    final filipino = voiceLanguageNotifier.value == "Filipino";
    await QueueVoice.configure(
      flutterTts,
      filipino: filipino,
      speechRate: 0.45,
    );
    await flutterTts.speak(
      QueueVoice.nowServingMessage(queueNumber, filipino: filipino),
    );
  }

  // ================= FILTER QUEUE BY SELECTED DATE =================

  List<Map<String, dynamic>> getQueueForSelectedDate() {
    final uniqueQueue = <String, Map<String, dynamic>>{};

    for (final customer in waitingQueueNotifier.value.where((customer) {
      final status = customer["status"]?.toString() ?? "Waiting";

      return customer["date"] == selectedQueueDateNotifier.value &&
          (status == "Waiting" || status == "Skipped");
    })) {
      final queueCode = customer["queue"]?.toString() ?? "";
      final date = customer["date"]?.toString() ?? "";
      uniqueQueue["$date|$queueCode"] = customer;
    }

    return uniqueQueue.values.toList(growable: false);
  }

  bool isNowServingForSelectedDate() {
    if (nowServingNotifier.value == null) return false;

    return nowServingNotifier.value!["date"] == selectedQueueDateNotifier.value;
  }

  Map<String, dynamic>? getDisplayedNowServing() {
    if (isNowServingForSelectedDate()) {
      return nowServingNotifier.value;
    }

    return null;
  }

  // ================= COMPLETED COUNT BY SELECTED DATE =================

  int completedCountForSelectedDate() {
    final String selectedDate = selectedQueueDateNotifier.value;

    final passedCount =
        dailyServedReportNotifier.value[selectedDate]?.length ?? 0;

    final failedCount =
        dailyFailedReportNotifier.value[selectedDate]?.length ?? 0;

    return passedCount + failedCount;
  }

  // ================= QUEUE CODE HELPERS =================

  bool queueCodeExistsOnSelectedDate(String queueCode) {
    final String selectedDate = selectedQueueDateNotifier.value;

    bool alreadyIssued =
        issuedQueueCodesNotifier.value[selectedDate]?.contains(queueCode) ??
        false;

    bool inWaiting = waitingQueueNotifier.value.any((customer) {
      final status = customer["status"]?.toString() ?? "Waiting";
      return customer["date"] == selectedDate &&
          customer["queue"] == queueCode &&
          status != "Cancelled" &&
          status != "Reset";
    });

    bool inNowServing =
        nowServingNotifier.value != null &&
        nowServingNotifier.value!["date"] == selectedDate &&
        nowServingNotifier.value!["queue"] == queueCode;

    return alreadyIssued || inWaiting || inNowServing;
  }

  String generateNextAvailableQueueCode(String type) {
    String prefix = type == "Gas" ? "G" : "D";
    int number = 1;

    while (number <= maxQueueLimit) {
      String queueCode = "$prefix${number.toString().padLeft(3, '0')}";

      if (!queueCodeExistsOnSelectedDate(queueCode)) {
        return queueCode;
      }

      number++;
    }

    return "";
  }

  int issuedCountForSelectedDate() {
    final String selectedDate = selectedQueueDateNotifier.value;
    return issuedQueueCodesNotifier.value[selectedDate]?.length ?? 0;
  }

  void markQueueCodeAsIssued(String date, String queueCode) {
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

  // ================= GENERATE DIALOG =================

  Future<void> showGenerateDialog(String type) async {
    final requestId = FirebaseFirestore.instance
        .collection('capacity_requests')
        .doc()
        .id;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController plateController = TextEditingController();
    final otherCategoryController = TextEditingController();
    final categoryFormKey = GlobalKey<FormState>();
    String? category;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            text("Generate $type Queue", "Gumawa ng $type Queue"),
            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    enabled: !isSaving,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: text("Customer Name", "Pangalan ng Customer"),
                      labelStyle: TextStyle(color: _mutedTextColor),
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: _primaryColor,
                      ),
                      filled: true,
                      fillColor: _backgroundColor,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _primaryColor,
                          width: 1.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: plateController,
                    enabled: !isSaving,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      const _UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      labelText: text("Plate Number", "Plate Number"),
                      hintText: "ABC1234",
                      helperText: text(
                        "Enter exactly 6–7 letters and numbers",
                        "Maglagay ng eksaktong 6–7 letra at numero",
                      ),
                      counterText: "",
                      labelStyle: TextStyle(color: _mutedTextColor),
                      prefixIcon: Icon(Icons.pin_rounded, color: _primaryColor),
                      filled: true,
                      fillColor: _backgroundColor,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _primaryColor,
                          width: 1.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  VehicleCategoryField(
                    formKey: categoryFormKey,
                    category: category,
                    otherController: otherCategoryController,
                    enabled: !isSaving,
                    onChanged: (value) {
                      setDialogState(() {
                        category = value;
                        if (value != 'Other') otherCategoryController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(text("Cancel", "Kanselahin")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (categoryFormKey.currentState?.validate() != true) {
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      final success = await generateQueue(
                        type,
                        nameController.text.trim(),
                        plateController.text,
                        requestId: requestId,
                        vehicleCategory: category!,
                        vehicleCategoryOther: otherCategoryController.text,
                      );

                      if (!dialogContext.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: Text(text("Generate Queue", "Gumawa ng Queue")),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    plateController.dispose();
    otherCategoryController.dispose();
  }

  // ================= GENERATE QUEUE =================

  Future<bool> generateQueue(
    String type,
    String name,
    String plate, {
    required String requestId,
    required String vehicleCategory,
    String? vehicleCategoryOther,
  }) async {
    if (_isGeneratingQueue) return false;
    if (!_isAdminSessionReady ||
        _isCheckingAdminSession ||
        !_capacityPolicyReady) {
      _showAdminSessionUnavailableMessage();
      return false;
    }
    _isGeneratingQueue = true;

    try {
      return await _generateQueueOnce(
        type,
        name,
        plate,
        requestId: requestId,
        vehicleCategory: vehicleCategory,
        vehicleCategoryOther: vehicleCategoryOther,
      );
    } finally {
      _isGeneratingQueue = false;
    }
  }

  Future<bool> _generateQueueOnce(
    String type,
    String name,
    String plate, {
    required String requestId,
    required String vehicleCategory,
    String? vehicleCategoryOther,
  }) async {
    final categoryError = validateVehicleCategory(
      vehicleCategory,
      other: vehicleCategoryOther,
    );
    if (categoryError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(categoryError)));
      return false;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "Please enter customer name",
              "Pakilagay ang pangalan ng customer",
            ),
          ),
        ),
      );
      return false;
    }

    final String? plateError = _validateWalkInPlateNumber(plate);

    if (plateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(plateError)));
      return false;
    }

    final String plateNumber = _normalizeWalkInPlateNumber(plate);

    final String selectedDate = selectedQueueDateNotifier.value;

    try {
      final queueNumber = await _saveQueueWithSessionRecovery(
        () => DailyQueueCapacityService.generateWalkIn(
          requestId: requestId,
          date: selectedDate,
          type: type,
          name: name,
          plate: plateNumber,
          vehicleCategory: vehicleCategory,
          vehicleCategoryOther: vehicleCategoryOther,
        ),
      );

      if (!mounted) return true;

      markQueueCodeAsIssued(selectedDate, queueNumber);

      setState(() {
        totalQueue++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "$queueNumber added to queue",
              "Naidagdag ang $queueNumber sa queue",
            ),
          ),
        ),
      );

      return true;
    } on _AdminSessionExpiredException {
      await _returnToLoginForExpiredAdminSession();
      return false;
    } on DailyQueueSubmissionUnconfirmed {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Queue creation could not be confirmed. Check the queue list or retry '
            'this same form before creating another ticket.',
          ),
        ),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FirebaseException && e.message != null
                ? e.message!
                : "Failed to save queue online: $e",
          ),
        ),
      );

      return false;
    }
  }

  // ================= UPDATE WALK-IN QUEUE =================

  bool isWalkInQueueEntry(Map<String, dynamic> customer) {
    final String appointmentId =
        customer["appointmentId"]?.toString().trim() ?? "";
    return appointmentId.isEmpty;
  }

  Future<void> showEditWalkInQueueDialog(Map<String, dynamic> customer) async {
    final TextEditingController nameController = TextEditingController(
      text: customer["name"]?.toString() ?? "",
    );
    final TextEditingController plateController = TextEditingController(
      text: customer["plate"]?.toString() ?? "",
    );
    final String queue = customer["queue"]?.toString() ?? "-";

    await showDialog<void>(
      context: context,
      builder: (_) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                text("Edit Queue - $queue", "I-edit ang Queue - $queue"),
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: text(
                          "Customer Name",
                          "Pangalan ng Customer",
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: _primaryColor,
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: plateController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 7,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]'),
                        ),
                        const _UpperCaseTextFormatter(),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        labelText: text("Plate Number", "Numero ng Plaka"),
                        hintText: "ABC1234",
                        helperText: text(
                          "Enter exactly 6–7 letters and numbers",
                          "Maglagay ng eksaktong 6–7 letra at numero",
                        ),
                        counterText: "",
                        prefixIcon: Icon(
                          Icons.pin_rounded,
                          color: _primaryColor,
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _softPrimaryColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Text(
                        text(
                          "Queue number, date, and vehicle type stay unchanged.",
                          "Hindi mababago ang queue number, petsa, at uri ng sasakyan.",
                        ),
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
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              actions: [
                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(text("Cancel", "Kanselahin")),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });

                          final bool success = await updateWalkInQueue(
                            customer: customer,
                            name: nameController.text.trim(),
                            plate: plateController.text,
                          );

                          if (!dialogContext.mounted) return;

                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() {
                              isSaving = false;
                            });
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
                  label: Text(text("UPDATE", "I-UPDATE")),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    plateController.dispose();
  }

  Future<bool> updateWalkInQueue({
    required Map<String, dynamic> customer,
    required String name,
    required String plate,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "Please enter customer name",
              "Pakilagay ang pangalan ng customer",
            ),
          ),
        ),
      );
      return false;
    }

    final String? plateError = _validateWalkInPlateNumber(plate);

    if (plateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(plateError)));
      return false;
    }

    final String date =
        customer["date"]?.toString() ?? selectedQueueDateNotifier.value;
    final String queue = customer["queue"]?.toString() ?? "";
    final String plateNumber = _normalizeWalkInPlateNumber(plate);

    if (date.isEmpty || queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Queue record is incomplete.")),
      );
      return false;
    }

    try {
      await queueItemsRef(date).doc(queue).update({
        "name": name,
        "plate": plateNumber,
        ...firestoreQueryFields(date: date, plate: plateNumber, name: name),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      waitingQueueNotifier.value = waitingQueueNotifier.value.map((item) {
        final bool matches = item["queue"] == queue && item["date"] == date;
        return matches ? {...item, "name": name, "plate": plateNumber} : item;
      }).toList();

      if (!mounted) return true;

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "$queue updated successfully",
              "Matagumpay na na-update ang $queue",
            ),
          ),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to update queue: $e")));
      return false;
    }
  }

  // ================= DELETE WALK-IN QUEUE =================

  Future<void> showDeleteWalkInQueueDialog(
    Map<String, dynamic> customer,
  ) async {
    final String queue = customer["queue"]?.toString() ?? "-";
    final String name = customer["name"]?.toString() ?? "-";
    final String plate = customer["plate"]?.toString() ?? "-";

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          text("Delete Walk-In Queue?", "Burahin ang Walk-In Queue?"),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w800),
        ),
        content: Text(
          text(
            "Permanently delete $queue for $name ($plate)? This cannot be undone.",
            "Permanenteng burahin ang $queue para kay $name ($plate)? Hindi na ito maibabalik.",
          ),
          style: TextStyle(color: _mutedTextColor, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text("Cancel", "Kanselahin")),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(text("DELETE", "BURAHIN")),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteWalkInQueue(customer);
    }
  }

  Future<void> deleteWalkInQueue(Map<String, dynamic> customer) async {
    final String date =
        customer["date"]?.toString() ?? selectedQueueDateNotifier.value;
    final String queue = customer["queue"]?.toString() ?? "";

    if (date.isEmpty || queue.isEmpty) return;

    try {
      final reference = queueItemsRef(date).doc(queue);
      await DailyQueueCapacityService.runDayTransaction<void>(date, (
        transaction,
        day,
      ) async {
        final snapshot = await transaction.get(reference);
        final current = snapshot.data();
        if (current == null) return;
        if (!_isWalkInCapacityRecord(current)) {
          throw StateError('Only a walk-in queue can be deleted here.');
        }
        if (current['status'] == 'Passed' || current['status'] == 'Failed') {
          day.completeQueue({...current, 'queue': queue, 'date': date});
        } else {
          day.releaseWalkIn(queue);
        }
        transaction.delete(reference);
      });

      waitingQueueNotifier.value = waitingQueueNotifier.value.where((item) {
        return item["queue"] != queue || item["date"] != date;
      }).toList();

      final updatedIssued = Map<String, List<String>>.from(
        issuedQueueCodesNotifier.value,
      );
      updatedIssued[date] = List<String>.from(updatedIssued[date] ?? [])
        ..remove(queue);
      issuedQueueCodesNotifier.value = updatedIssued;

      if (nowServingNotifier.value?["queue"] == queue &&
          nowServingNotifier.value?["date"] == date) {
        nowServingNotifier.value = null;
      }

      if (!mounted) return;

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "$queue permanently deleted",
              "Permanenteng nabura ang $queue",
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete queue: $e")));
    }
  }

  // ================= CALL CUSTOMER =================

  Future<void> callCustomer(Map<String, dynamic> customer) async {
    if (_isCallingCustomer) return;

    if (getDisplayedNowServing() != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "Finish the current customer before calling the next queue.",
              "Tapusin muna ang kasalukuyang customer bago tumawag ng susunod.",
            ),
          ),
        ),
      );
      return;
    }

    final String date =
        customer["date"]?.toString() ?? selectedQueueDateNotifier.value;
    setState(() => _isCallingCustomer = true);

    try {
      final onlineItems = await getQueueItemsOnline(date, forceServer: true);
      final activeQueue = onlineItems.where((item) {
        return item["status"]?.toString() == "Now Serving";
      });
      if (activeQueue.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              text(
                "A customer is already being served. Finish or skip that customer first.",
                "May customer na kasalukuyang sini-serve. Tapusin o i-skip muna siya.",
              ),
            ),
          ),
        );
        return;
      }

      final waitingItems = onlineItems
          .where((item) {
            final status = item["status"]?.toString() ?? "Waiting";
            return status == "Waiting" || status == "Skipped";
          })
          .toList(growable: false);
      final requestedQueue = customer["queue"]?.toString() ?? "";

      if (waitingItems.isEmpty ||
          waitingItems.first["queue"]?.toString() != requestedQueue) {
        if (!mounted) return;
        final firstQueue = waitingItems.isEmpty
            ? null
            : waitingItems.first["queue"]?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              firstQueue == null
                  ? text(
                      "This queue is no longer waiting. Refresh and try again.",
                      "Hindi na naghihintay ang queue na ito. I-refresh at subukan muli.",
                    )
                  : text(
                      "First come, first served: call $firstQueue first. To move past it, call it and use Skip / No Show.",
                      "First come, first served: tawagin muna ang $firstQueue. Para lumampas dito, tawagin ito at gamitin ang Skip / No Show.",
                    ),
            ),
          ),
        );
        await refreshQueue();
        return;
      }

      await updateQueueItemStatus(
        customer: customer,
        status: "Now Serving",
        extraData: {
          "calledAt": FieldValue.serverTimestamp(),
          "source": customer["source"] ?? "Walk-in",
        },
      );

      final updatedQueue = List<Map<String, dynamic>>.from(
        waitingQueueNotifier.value,
      );

      updatedQueue.removeWhere((item) {
        return item["queue"] == customer["queue"] &&
            item["date"] == customer["date"];
      });

      waitingQueueNotifier.value = updatedQueue;

      nowServingNotifier.value = {...customer, "status": "Now Serving"};

      await speak(customer['queue']);

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to call customer: $e")));
    } finally {
      if (mounted) setState(() => _isCallingCustomer = false);
    }
  }

  // ================= CALL AGAIN =================

  void callAgain() async {
    final customer = getDisplayedNowServing();

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "No customer is being served for this date",
              "Walang kasalukuyang sini-serve sa petsang ito",
            ),
          ),
        ),
      );
      return;
    }

    await speak(customer['queue']);
  }

  // ================= SKIP CUSTOMER =================

  Future<void> skipCustomer() async {
    final customer = getDisplayedNowServing();

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text("No customer to skip", "Walang customer na i-skip"),
          ),
        ),
      );
      return;
    }

    final originalSource = normalizedQueueSource(customer);
    final skippedCustomer = {
      ...customer,
      "source": originalSource,
      "originalSource": originalSource,
      "wasSkipped": true,
      "status": "Skipped",
    };

    try {
      await updateQueueItemStatus(
        customer: skippedCustomer,
        status: "Skipped",
        extraData: {
          "source": originalSource,
          "originalSource": originalSource,
          "wasSkipped": true,
          "skipCount": FieldValue.increment(1),
          "originalCreatedAt":
              customer["originalCreatedAt"] ?? customer["createdAt"],
          "createdAt": FieldValue.serverTimestamp(),
          "skippedAt": FieldValue.serverTimestamp(),
        },
      );

      waitingQueueNotifier.value = [
        ...waitingQueueNotifier.value,
        skippedCustomer,
      ];

      nowServingNotifier.value = null;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "${skippedCustomer['queue']} skipped and moved to bottom queue",
              "Na-skip ang ${skippedCustomer['queue']} at nailipat sa dulo ng queue",
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to skip customer: $e")));
    }
  }

  // ================= PASSED =================

  Future<void> markPassed() async {
    final customer = getDisplayedNowServing();

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "No customer to mark as passed",
              "Walang customer na mamarkahan bilang passed",
            ),
          ),
        ),
      );
      return;
    }

    final String date = customer["date"] ?? selectedQueueDateNotifier.value;
    final String time = TimeOfDay.now().format(context);

    try {
      await updateQueueItemStatus(
        customer: customer,
        status: "Passed",
        extraData: {
          "result": "Passed",
          "time": time,
          "completedAt": FieldValue.serverTimestamp(),
        },
      );

      final updatedServed = Map<String, List<Map<String, dynamic>>>.from(
        dailyServedReportNotifier.value,
      );

      final servedList = List<Map<String, dynamic>>.from(
        updatedServed[date] ?? [],
      );

      servedList.add({
        ...customer,
        "result": "Passed",
        "status": "Passed",
        "time": time,
      });

      updatedServed[date] = servedList;
      dailyServedReportNotifier.value = updatedServed;

      final updatedOldHistory = Map<String, List<String>>.from(
        dailyHistoryNotifier.value,
      );

      final oldList = List<String>.from(updatedOldHistory[date] ?? []);

      oldList.add(customer["queue"]);

      updatedOldHistory[date] = oldList;
      dailyHistoryNotifier.value = updatedOldHistory;

      nowServingNotifier.value = null;

      setState(() {
        completedQueue++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "${customer['queue']} marked as passed",
              "Naipasa ang ${customer['queue']}",
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to mark as passed: $e")));
    }
  }

  // ================= FAILED =================

  Future<void> markFailed() async {
    final customer = getDisplayedNowServing();

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "No customer to mark as failed",
              "Walang customer na mamarkahan bilang failed",
            ),
          ),
        ),
      );
      return;
    }

    final String date = customer["date"] ?? selectedQueueDateNotifier.value;
    final String time = TimeOfDay.now().format(context);

    try {
      await updateQueueItemStatus(
        customer: customer,
        status: "Failed",
        extraData: {
          "result": "Failed",
          "time": time,
          "completedAt": FieldValue.serverTimestamp(),
        },
      );

      final updatedFailed = Map<String, List<Map<String, dynamic>>>.from(
        dailyFailedReportNotifier.value,
      );

      final failedList = List<Map<String, dynamic>>.from(
        updatedFailed[date] ?? [],
      );

      failedList.add({
        ...customer,
        "result": "Failed",
        "status": "Failed",
        "time": time,
      });

      updatedFailed[date] = failedList;
      dailyFailedReportNotifier.value = updatedFailed;

      nowServingNotifier.value = null;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "${customer['queue']} marked as failed",
              "Na-failed ang ${customer['queue']}",
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to mark as failed: $e")));
    }
  }

  // ================= CANCEL QUEUE =================

  Future<void> cancelQueue(Map<String, dynamic> customer) async {
    try {
      await updateQueueItemStatus(
        customer: customer,
        status: "Cancelled",
        extraData: {"cancelledAt": FieldValue.serverTimestamp()},
      );

      final updatedQueue = List<Map<String, dynamic>>.from(
        waitingQueueNotifier.value,
      );

      updatedQueue.removeWhere((item) {
        return item["queue"] == customer["queue"] &&
            item["date"] == customer["date"];
      });

      waitingQueueNotifier.value = updatedQueue;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "${customer['queue']} removed from queue",
              "Naalis ang ${customer['queue']} sa queue",
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to cancel queue: $e")));
    }
  }

  // ================= DAILY RESET =================

  void resetDay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          text("Reset System", "I-reset ang System"),
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w800),
        ),
        content: Text(
          text(
            "This will clear the active queues for the selected date.",
            "Mabubura ang active queues para sa napiling petsa.",
          ),
          style: TextStyle(color: _mutedTextColor, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: BorderSide(color: _primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(text("Cancel", "Kanselahin")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              final String selectedDate = selectedQueueDateNotifier.value;

              try {
                final onlineItems = await getQueueItemsOnline(selectedDate);

                for (final item in onlineItems) {
                  final status = item["status"]?.toString() ?? "";

                  if (status == "Waiting" ||
                      status == "Now Serving" ||
                      status == "Skipped") {
                    final queue = item["queue"]?.toString() ?? "";

                    if (queue.isNotEmpty) {
                      final reference = queueItemsRef(selectedDate).doc(queue);
                      await DailyQueueCapacityService.runDayTransaction<void>(
                        selectedDate,
                        (transaction, day) async {
                          final snapshot = await transaction.get(reference);
                          final current = snapshot.data();
                          if (current == null ||
                              !isActiveQueueStatus(
                                current['status']?.toString() ?? '',
                              )) {
                            return;
                          }
                          if (_isWalkInCapacityRecord(current)) {
                            day.releaseWalkIn(queue);
                          }
                          transaction.update(reference, {
                            "status": "Reset",
                            "resetAt": FieldValue.serverTimestamp(),
                            "updatedAt": FieldValue.serverTimestamp(),
                          });
                        },
                      );
                    }
                  }
                }

                waitingQueueNotifier.value = [];
                nowServingNotifier.value = null;
                issuedQueueCodesNotifier.value = {
                  ...issuedQueueCodesNotifier.value,
                  selectedDate: [],
                };

                gasCounter = 1;
                dieselCounter = 1;

                totalQueue = 0;
                completedQueue = 0;

                setState(() {});

                if (context.mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        text(
                          "Queue reset for selected date",
                          "Na-reset ang queue para sa napiling petsa",
                        ),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Reset failed: $e")));
                }
              }
            },
            child: Text(text("Confirm", "Kumpirmahin")),
          ),
        ],
      ),
    );
  }

  // ================= RESPONSIVE UI HELPERS =================

  bool isWideScreen(double width) => width >= 900;

  bool isTabletScreen(double width) => width >= 650 && width < 900;

  Widget buildRefreshControl(BuildContext context) {
    final bool showLabel = MediaQuery.sizeOf(context).width >= 700;
    final bool isBusy = _isRefreshingQueue || _isCheckingAdminSession;
    final Widget icon = isBusy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryColor,
            ),
          )
        : const Icon(Icons.refresh_rounded);

    if (!showLabel) {
      return IconButton(
        key: const Key("admin-refresh-button"),
        tooltip: text("Refresh queue", "I-refresh ang queue"),
        onPressed: isBusy ? null : refreshQueueFromControl,
        icon: icon,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        key: const Key("admin-refresh-button"),
        onPressed: isBusy ? null : refreshQueueFromControl,
        icon: icon,
        label: Text(text("Refresh", "I-refresh")),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: BorderSide(color: _borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _toggleDesktopSidebar() {
    setState(() {
      _desktopSidebarVisible = !_desktopSidebarVisible;
    });
  }

  VoidCallback _adminNavigationAction({required bool desktopShell}) {
    if (desktopShell) return _toggleDesktopSidebar;
    return () => _mobileScaffoldKey.currentState?.openDrawer();
  }

  IconData _adminNavigationIcon({required bool desktopShell}) {
    if (!desktopShell) return Icons.menu_rounded;
    return _desktopSidebarVisible
        ? Icons.menu_open_rounded
        : Icons.menu_rounded;
  }

  Widget _buildSelectedAdminPage({required bool desktopShell}) {
    final onNavigationPressed = _adminNavigationAction(
      desktopShell: desktopShell,
    );
    final navigationIcon = _adminNavigationIcon(desktopShell: desktopShell);

    return switch (_activeAdminSection) {
      _AdminSection.appointments => AdminDashboard(
        key: ValueKey('appointments-$_appointmentPageRevision'),
        initialAppointmentId: _initialAppointmentId,
        onNavigationPressed: onNavigationPressed,
        navigationIcon: navigationIcon,
      ),
      _AdminSection.reports => DailyReport(
        onNavigationPressed: onNavigationPressed,
        navigationIcon: navigationIcon,
      ),
      _AdminSection.analytics => AnalyticsPage(
        onNavigationPressed: onNavigationPressed,
        navigationIcon: navigationIcon,
      ),
      _AdminSection.settings => AdminSettings(
        onNavigationPressed: onNavigationPressed,
        navigationIcon: navigationIcon,
      ),
      _AdminSection.queue => const SizedBox.shrink(),
    };
  }

  void _closeDrawerAndSelect(_AdminSection section) {
    Navigator.pop(context);
    _selectAdminSection(section);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: selectedQueueDateNotifier,
      builder: (context, selectedDate, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: queueItemsStream(selectedDate),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              scheduleQueueSyncAfterBuild(selectedDate, snapshot.data!);
            }

            final onlineItems = snapshot.data;
            final List<Map<String, dynamic>> selectedDateQueue =
                onlineItems == null
                ? getQueueForSelectedDate()
                : onlineItems.where((item) {
                    final status = item["status"]?.toString() ?? "Waiting";
                    return status == "Waiting" || status == "Skipped";
                  }).toList();
            final onlineNowServing = onlineItems
                ?.where((item) => item["status"]?.toString() == "Now Serving")
                .toList();
            final Map<String, dynamic>? displayedNowServing =
                onlineNowServing == null
                ? getDisplayedNowServing()
                : (onlineNowServing.isEmpty ? null : onlineNowServing.last);

            final bool desktopShell =
                kIsWeb && MediaQuery.sizeOf(context).width >= 1000;
            final queuePanelBody = buildQueuePanelBody(
              selectedDateQueue: selectedDateQueue,
              displayedNowServing: displayedNowServing,
              capacityUsage:
                  onlineItems == null ||
                      !_completedCapacityReady ||
                      !_capacityAppointmentsReady
                  ? null
                  : DailyQueueUsage.fromRecords(
                      appointments: _capacityAppointments,
                      queueItems: onlineItems,
                      completedClaims: _completedCapacityClaims,
                    ),
            );
            final selectedAdminPage = _activeAdminSection == _AdminSection.queue
                ? queuePanelBody
                : _buildSelectedAdminPage(desktopShell: desktopShell);

            return Theme(
              data: Theme.of(context).copyWith(
                scaffoldBackgroundColor: _backgroundColor,
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primaryColor,
                  onPrimary: Colors.white,
                  surface: _cardColor,
                  onSurface: _primaryColor,
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: _cardColor,
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
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: _primaryColor.withOpacity(0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              child: desktopShell
                  ? Scaffold(
                      backgroundColor: _backgroundColor,
                      body: Row(
                        children: [
                          if (_desktopSidebarVisible) buildDesktopSidebar(),
                          Expanded(
                            child: _activeAdminSection == _AdminSection.queue
                                ? Column(
                                    children: [
                                      buildDesktopHeader(),
                                      Expanded(child: queuePanelBody),
                                    ],
                                  )
                                : selectedAdminPage,
                          ),
                        ],
                      ),
                    )
                  : Scaffold(
                      key: _mobileScaffoldKey,
                      backgroundColor: _backgroundColor,
                      drawer: buildDrawer(),
                      appBar: _activeAdminSection == _AdminSection.queue
                          ? AppBar(
                              leading: IconButton(
                                key: const Key('mobile-navigation-toggle'),
                                tooltip: 'Open navigation menu',
                                onPressed: () {
                                  _mobileScaffoldKey.currentState?.openDrawer();
                                },
                                icon: const Icon(Icons.menu_rounded),
                              ),
                              title: Text(
                                text(
                                  "Admin Control Panel",
                                  "Admin Control Panel",
                                ),
                              ),
                              actions: [
                                _buildThemeModeButton(),
                                _buildAppointmentNotificationButton(),
                                buildRefreshControl(context),
                                const SizedBox(width: 12),
                              ],
                            )
                          : null,
                      body: selectedAdminPage,
                    ),
            );
          },
        );
      },
    );
  }

  Widget buildQueuePanelBody({
    required List<Map<String, dynamic>> selectedDateQueue,
    required Map<String, dynamic>? displayedNowServing,
    required DailyQueueUsage? capacityUsage,
  }) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = isWideScreen(constraints.maxWidth);
          final bool tablet = isTabletScreen(constraints.maxWidth);
          final double pagePadding = wide ? 20 : 12;
          final double waitingListHeight = wide || tablet
              ? (constraints.maxHeight - 420).clamp(360.0, 720.0)
              : 430.0;

          return AppResponsiveContent(
            maxWidth: 1400,
            child: AppRefreshIndicator(
              onRefresh: refreshQueue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (pagePadding * 2),
                  ),
                  child: Column(
                    children: [
                      buildStatsSection(
                        selectedDateQueue: selectedDateQueue,
                        compact: !wide,
                      ),
                      const SizedBox(height: 18),
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 4,
                                child: buildLeftPanel(capacityUsage),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 8,
                                child: buildNowServingCard(displayedNowServing),
                              ),
                            ],
                          ),
                        )
                      else if (tablet)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 230,
                                child: buildLeftPanel(capacityUsage),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: buildNowServingCard(displayedNowServing),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            buildNowServingCard(displayedNowServing),
                            const SizedBox(height: 16),
                            buildLeftPanel(capacityUsage),
                          ],
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: waitingListHeight,
                        child: buildWaitingQueueCard(
                          selectedDateQueue,
                          canCallCustomer:
                              displayedNowServing == null &&
                              !_isCallingCustomer,
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
    );
  }

  Widget buildDesktopHeader() {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final showLiveBadge = viewportWidth >= 1250;

    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 0),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: _desktopSidebarVisible
                ? 'Hide navigation menu'
                : 'Show navigation menu',
            child: IconButton(
              key: const Key('desktop-sidebar-toggle'),
              onPressed: _toggleDesktopSidebar,
              style: IconButton.styleFrom(
                foregroundColor: _primaryColor,
                backgroundColor: _softPrimaryColor,
                side: BorderSide(color: _borderColor),
                minimumSize: const Size(40, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _desktopSidebarVisible
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                  key: ValueKey(_desktopSidebarVisible),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text('Admin Control Panel', 'Admin Control Panel'),
            style: TextStyle(
              color: _primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          if (showLiveBadge) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.22),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'LIVE OPERATIONAL DAY',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          _buildThemeModeButton(),
          _buildAppointmentNotificationButton(),
          buildRefreshControl(context),
        ],
      ),
    );
  }

  Widget buildDesktopSidebar() {
    return Container(
      width: 220,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Suite',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Emission Testing',
                          style: TextStyle(
                            color: Color(0xFFB9C8D8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF29445F), height: 1),
            const SizedBox(height: 18),
            desktopSidebarItem(
              icon: Icons.format_list_numbered_rounded,
              title: text('Queue Panel', 'Queue Panel'),
              selected: _activeAdminSection == _AdminSection.queue,
              onTap: () => _selectAdminSection(_AdminSection.queue),
            ),
            desktopSidebarItem(
              icon: Icons.calendar_month_rounded,
              title: text('Appointment', 'Appointment'),
              selected: _activeAdminSection == _AdminSection.appointments,
              onTap: _openAppointmentDashboard,
            ),
            desktopSidebarItem(
              icon: Icons.description_rounded,
              title: text('Reports', 'Reports'),
              selected: _activeAdminSection == _AdminSection.reports,
              onTap: () => _selectAdminSection(_AdminSection.reports),
            ),
            desktopSidebarItem(
              icon: Icons.bar_chart_rounded,
              title: text('Analytics', 'Analytics'),
              selected: _activeAdminSection == _AdminSection.analytics,
              onTap: () => _selectAdminSection(_AdminSection.analytics),
            ),
            desktopSidebarItem(
              icon: Icons.settings_rounded,
              title: text('Settings', 'Settings'),
              selected: _activeAdminSection == _AdminSection.settings,
              onTap: () => _selectAdminSection(_AdminSection.settings),
            ),
            const Spacer(),
            const Divider(color: Color(0xFF29445F), height: 1),
            const SizedBox(height: 10),
            desktopSidebarItem(
              icon: Icons.logout_rounded,
              title: text('Logout', 'Logout'),
              isLogout: true,
              onTap: _logoutAdmin,
            ),
          ],
        ),
      ),
    );
  }

  Widget desktopSidebarItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool isLogout = false,
  }) {
    final foreground = isLogout
        ? const Color(0xFFFF7B83)
        : selected
        ? AppColors.primary
        : const Color(0xFFD7E2ED);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

  Future<void> _logoutAdmin() async {
    await _saveReadAdminAppointmentNotifications();
    await signOutAndClearRememberedLogin();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  // ================= DRAWER =================

  Widget buildDrawer() {
    return Drawer(
      backgroundColor: _backgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: _primaryColor),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('mobile-navigation-close'),
                    tooltip: 'Close navigation menu',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        text("Admin Panel", "Admin Panel"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          drawerTile(
            icon: Icons.queue_rounded,
            title: text("Queue Panel", "Queue Panel"),
            selected: _activeAdminSection == _AdminSection.queue,
            onTap: () => _closeDrawerAndSelect(_AdminSection.queue),
          ),
          drawerTile(
            icon: Icons.dashboard_rounded,
            title: text("Appointment Dashboard", "Appointment Dashboard"),
            selected: _activeAdminSection == _AdminSection.appointments,
            onTap: () => _closeDrawerAndSelect(_AdminSection.appointments),
          ),
          drawerTile(
            icon: Icons.assessment_rounded,
            title: text("Reports", "Reports"),
            selected: _activeAdminSection == _AdminSection.reports,
            onTap: () => _closeDrawerAndSelect(_AdminSection.reports),
          ),
          drawerTile(
            icon: Icons.insights_rounded,
            title: text("Analytics", "Analytics"),
            selected: _activeAdminSection == _AdminSection.analytics,
            onTap: () => _closeDrawerAndSelect(_AdminSection.analytics),
          ),
          drawerTile(
            icon: Icons.settings_rounded,
            title: text("Settings", "Settings"),
            selected: _activeAdminSection == _AdminSection.settings,
            onTap: () => _closeDrawerAndSelect(_AdminSection.settings),
          ),
          Divider(color: _borderColor, height: 24),
          drawerTile(
            icon: Icons.logout_rounded,
            title: text("Logout", "Logout"),
            isLogout: true,
            onTap: _logoutAdmin,
          ),
        ],
      ),
    );
  }

  Widget drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: selected ? _softPrimaryColor : _cardColor,
        leading: Icon(icon, color: isLogout ? Colors.red : _primaryColor),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : _primaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ================= STATS =================

  Widget buildStatsSection({
    required List<Map<String, dynamic>> selectedDateQueue,
    required bool compact,
  }) {
    final String completedForDate = completedCountForSelectedDate().toString();

    if (!compact) {
      return Row(
        children: [
          statCard(
            text("Total Queue", "Kabuuang Queue"),
            issuedCountForSelectedDate().toString(),
          ),
          const SizedBox(width: 10),
          statCard(
            text("Waiting Queue", "Naghihintay"),
            selectedDateQueue.length.toString(),
          ),
          const SizedBox(width: 10),
          statCard(text("Completed", "Tapos Na"), completedForDate),
        ],
      );
    }

    if (useMobileWebStatsRow(
      isWeb: kIsWeb,
      width: MediaQuery.sizeOf(context).width,
    )) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mobileWebStatCard(
            text("Total Queue", "Kabuuang Queue"),
            issuedCountForSelectedDate().toString(),
          ),
          const SizedBox(width: 7),
          mobileWebStatCard(
            text("Waiting Queue", "Naghihintay"),
            selectedDateQueue.length.toString(),
          ),
          const SizedBox(width: 7),
          mobileWebStatCard(text("Completed", "Tapos Na"), completedForDate),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        statBox(
          text("Total Queue", "Kabuuang Queue"),
          issuedCountForSelectedDate().toString(),
        ),
        statBox(
          text("Waiting Queue", "Naghihintay"),
          selectedDateQueue.length.toString(),
        ),
        statBox(text("Completed", "Tapos Na"), completedForDate),
      ],
    );
  }

  // ================= LEFT PANEL =================

  Widget buildLeftPanel(DailyQueueUsage? capacityUsage) {
    final remaining = capacityUsage?.walkInRemaining(_capacityPolicy);
    final canGenerate =
        _isAdminSessionReady &&
        !_isCheckingAdminSession &&
        _capacityPolicyReady &&
        remaining != null &&
        remaining > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardContainer(
          child: Column(
            children: [
              sectionHeader(
                icon: Icons.confirmation_number_rounded,
                title: text("GENERATE QUEUE TICKET", "GUMAWA NG QUEUE TICKET"),
              ),
              const SizedBox(height: 15),
              Text(
                !_capacityPolicyReady || remaining == null
                    ? text(
                        'Loading walk-in allocation…',
                        'Kinukuha ang walk-in allocation…',
                      )
                    : text(
                        'Walk-in slots remaining: $remaining of ${_capacityPolicy.sourceLimit}',
                        'Natitirang walk-in slot: $remaining sa ${_capacityPolicy.sourceLimit}',
                      ),
                style: TextStyle(color: _mutedTextColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                text(
                  'Gas and Diesel combined • Appointment slots stay reserved.',
                  'Pinagsamang Gas at Diesel • Nakareserba ang appointment slots.',
                ),
                style: TextStyle(color: _mutedTextColor, fontSize: 11.5),
                textAlign: TextAlign.center,
              ),
              if (remaining == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    text(
                      'Walk-in allocation is full for this date.',
                      'Puno na ang walk-in allocation para sa petsang ito.',
                    ),
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: canGenerate
                      ? () => showGenerateDialog("Gas")
                      : null,
                  icon: const Icon(Icons.directions_car_rounded),
                  label: const Text("GAS"),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: canGenerate
                      ? () => showGenerateDialog("Diesel")
                      : null,
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: const Text("DIESEL"),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        cardContainer(
          child: Column(
            children: [
              sectionHeader(
                icon: Icons.tune_rounded,
                title: text("Quick Actions", "Quick Actions"),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.tv_rounded),
                  label: Text(text("DISPLAY PAGE", "DISPLAY PAGE")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _softPrimaryColor,
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _borderColor),
                    elevation: 0,
                  ),
                  onPressed: _openDisplayPage,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(text("DAILY RESET", "DAILY RESET")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: resetDay,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= NOW SERVING CARD =================

  Widget buildNowServingCard(Map<String, dynamic>? displayedNowServing) {
    final bool desktop = kIsWeb && MediaQuery.sizeOf(context).width >= 1000;
    return cardContainer(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 314 : 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            sectionHeader(
              icon: Icons.campaign_rounded,
              title: text("NOW SERVING", "KASALUKUYANG TINATAWAG"),
              centered: true,
            ),
            const SizedBox(height: 16),
            AppStatusPulse(
              active: displayedNowServing != null,
              color: AppColors.danger,
              borderRadius: 20,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: _softPrimaryColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        displayedNowServing == null
                            ? "-"
                            : displayedNowServing['queue'],
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayedNowServing == null
                          ? text(
                              "No customer currently called",
                              "Walang tinatawag",
                            )
                          : displayedNowServing['name'],
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                miniButton(Icons.volume_up_rounded, Colors.blue, callAgain),
                miniButton(
                  Icons.skip_next_rounded,
                  Colors.orange,
                  skipCustomer,
                ),
                miniButton(Icons.check_rounded, Colors.green, markPassed),
                miniButton(Icons.close_rounded, Colors.red, markFailed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= WAITING QUEUE CARD =================

  Widget buildWaitingQueueCard(
    List<Map<String, dynamic>> selectedDateQueue, {
    required bool canCallCustomer,
  }) {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded, color: _primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text('WAITING QUEUE DETAILS', 'WAITING QUEUE DETAILS'),
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
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
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 7, color: AppColors.success),
                    const SizedBox(width: 5),
                    Text(
                      'Live Sync Active',
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: selectedDateQueue.isEmpty
                ? Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _softPrimaryColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            color: _primaryColor,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            text(
                              "No queue for this date",
                              "Walang queue sa petsang ito",
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            text(
                              'Generate a ticket above to start serving',
                              'Gumawa ng ticket sa itaas upang magsimula',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedDateQueue.length,
                    itemBuilder: (context, index) {
                      final customer = selectedDateQueue[index];
                      final bool canManageWalkIn = isWalkInQueueEntry(customer);
                      final bool canCallThisCustomer =
                          canCallCustomer && index == 0;
                      final String callTooltip = canCallThisCustomer
                          ? text(
                              "Call the first waiting customer",
                              "Tawagin ang unang naghihintay na customer",
                            )
                          : text(
                              "First come, first served. Finish or skip the customer ahead first.",
                              "First come, first served. Tapusin o i-skip muna ang customer na nauna.",
                            );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _softPrimaryColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _borderColor),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool narrow = constraints.maxWidth < 360;

                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildQueueInfo(customer),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      miniButton(
                                        Icons.volume_up_rounded,
                                        canCallThisCustomer
                                            ? Colors.blue
                                            : Colors.grey,
                                        canCallThisCustomer
                                            ? () => callCustomer(customer)
                                            : null,
                                        tooltip: callTooltip,
                                      ),
                                      if (canManageWalkIn) ...[
                                        const SizedBox(width: 8),
                                        miniButton(
                                          Icons.edit_rounded,
                                          Colors.orange,
                                          () {
                                            showEditWalkInQueueDialog(customer);
                                          },
                                          tooltip: text(
                                            "Edit walk-in",
                                            "I-edit ang walk-in",
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        miniButton(
                                          Icons.delete_outline_rounded,
                                          Colors.red,
                                          () {
                                            showDeleteWalkInQueueDialog(
                                              customer,
                                            );
                                          },
                                          tooltip: text(
                                            "Delete walk-in",
                                            "Burahin ang walk-in",
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 8),
                                        miniButton(
                                          Icons.close_rounded,
                                          Colors.red,
                                          () {
                                            cancelQueue(customer);
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: buildQueueInfo(customer)),
                                miniButton(
                                  Icons.volume_up_rounded,
                                  canCallThisCustomer
                                      ? Colors.blue
                                      : Colors.grey,
                                  canCallThisCustomer
                                      ? () => callCustomer(customer)
                                      : null,
                                  tooltip: callTooltip,
                                ),
                                if (canManageWalkIn) ...[
                                  const SizedBox(width: 8),
                                  miniButton(
                                    Icons.edit_rounded,
                                    Colors.orange,
                                    () {
                                      showEditWalkInQueueDialog(customer);
                                    },
                                    tooltip: text(
                                      "Edit walk-in",
                                      "I-edit ang walk-in",
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  miniButton(
                                    Icons.delete_outline_rounded,
                                    Colors.red,
                                    () {
                                      showDeleteWalkInQueueDialog(customer);
                                    },
                                    tooltip: text(
                                      "Delete walk-in",
                                      "Burahin ang walk-in",
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(width: 8),
                                  miniButton(
                                    Icons.close_rounded,
                                    Colors.red,
                                    () {
                                      cancelQueue(customer);
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildQueueInfo(Map<String, dynamic> customer) {
    return Row(
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
            customer['queue']?.toString().substring(0, 1) ?? "-",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer['queue'] ?? "-",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                customer['name'] ?? "-",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mutedTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "${customer['plate'] ?? '-'} • ${customer['type'] ?? '-'}",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mutedTextColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  customer['source'] ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _mutedTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= CARD =================

  Widget cardContainer({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double borderRadius = AppRadii.card,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _borderColor),
        boxShadow: AppEffects.cardShadow,
      ),
      child: child,
    );
  }

  Widget iconBox(IconData icon) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Icon(
        icon,
        color: isAppDarkMode ? AppColors.darkBackground : Colors.white,
        size: 22,
      ),
    );
  }

  Widget sectionHeader({
    required IconData icon,
    required String title,
    bool centered = false,
  }) {
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Icon(icon, color: _primaryColor, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // ================= STAT CARD =================

  Widget statCard(String title, String value) {
    return Expanded(child: statContent(title, value, wideDesktop: true));
  }

  Widget statBox(String title, String value) {
    return SizedBox(width: 160, child: statContent(title, value));
  }

  Widget mobileWebStatCard(String title, String value) {
    return Expanded(
      child: SizedBox(
        height: 134,
        child: statContent(title, value, compactMobileWeb: true),
      ),
    );
  }

  Widget statContent(
    String title,
    String value, {
    bool compactMobileWeb = false,
    bool wideDesktop = false,
  }) {
    IconData icon = Icons.confirmation_number_rounded;
    Color accentColor = _primaryColor;

    if (title.contains("Waiting") || title.contains("Naghihintay")) {
      icon = Icons.groups_rounded;
      accentColor = Colors.orange;
    } else if (title.contains("Completed") || title.contains("Tapos")) {
      icon = Icons.check_circle_outline_rounded;
      accentColor = Colors.green;
    }

    if (wideDesktop) {
      return AppHoverLift(
        enabled: kIsWeb,
        borderRadius: 20,
        lift: 2,
        child: cardContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          borderRadius: 20,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 25),
              ),
            ],
          ),
        ),
      );
    }

    return cardContainer(
      padding: compactMobileWeb
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 10)
          : const EdgeInsets.all(16),
      borderRadius: compactMobileWeb ? 16 : 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: compactMobileWeb ? 34 : 42,
            width: compactMobileWeb ? 34 : 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(compactMobileWeb ? 11 : 14),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: compactMobileWeb ? 20 : 24,
            ),
          ),
          SizedBox(height: compactMobileWeb ? 7 : 10),
          SizedBox(
            height: compactMobileWeb ? 18 : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  fontSize: compactMobileWeb ? 11 : 13,
                ),
              ),
            ),
          ),
          SizedBox(height: compactMobileWeb ? 5 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: compactMobileWeb ? 23 : 28,
                fontWeight: FontWeight.w900,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= MINI BUTTON =================

  Widget miniButton(
    IconData icon,
    Color color,
    VoidCallback? onPressed, {
    String? tooltip,
  }) {
    return Tooltip(
      message:
          tooltip ??
          (icon == Icons.volume_up_rounded
              ? text("Call", "Tawagin")
              : icon == Icons.skip_next_rounded
              ? text("Skip", "I-skip")
              : icon == Icons.check_rounded
              ? text("Passed", "Passed")
              : text("Cancel / Failed", "Cancel / Failed")),
      child: SizedBox(
        width: 42,
        height: 42,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white70,
            padding: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 19),
        ),
      ),
    );
  }
}
