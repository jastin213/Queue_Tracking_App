import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/localized_text.dart';
import '../services/app_language.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/appointment_lifecycle.dart';
import '../theme/app_theme.dart';
import '../widgets/app_motion.dart';
import '../services/customer_preferences.dart';
import '../services/queue_voice.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_responsive_content.dart';
import 'ors_service.dart';
import 'location_data.dart';

String formatQueueDuration(int minutes) {
  final int safeMinutes = minutes < 0 ? 0 : minutes;

  if (safeMinutes < 60) {
    return "$safeMinutes ${safeMinutes == 1 ? "min" : "mins"}";
  }

  final int hours = safeMinutes ~/ 60;
  final int remainingMinutes = safeMinutes % 60;
  final String hourText = "$hours ${hours == 1 ? "hour" : "hours"}";

  if (remainingMinutes == 0) return hourText;

  return "$hourText $remainingMinutes "
      "${remainingMinutes == 1 ? "min" : "mins"}";
}

int? calculateLiveQueuePosition({
  required String queueNumber,
  required Iterable<Map<String, dynamic>> items,
}) {
  final normalizedQueue = queueNumber.trim().toUpperCase();
  if (normalizedQueue.isEmpty) return null;

  final waitingItems = items.where((item) {
    final status = item["status"]?.toString() ?? "Waiting";
    return status == "Waiting" || status == "Skipped";
  }).toList();
  final index = waitingItems.indexWhere(
    (item) => item["queue"]?.toString().trim().toUpperCase() == normalizedQueue,
  );

  return index < 0 ? null : index + 1;
}

int? calculateLiveEstimatedQueueTime({
  required String queueNumber,
  required Iterable<Map<String, dynamic>> items,
  int averageServiceMinutes = 9,
}) {
  final position = calculateLiveQueuePosition(
    queueNumber: queueNumber,
    items: items,
  );
  return position == null ? null : position * averageServiceMinutes;
}

String? validateAppointmentQueueOwnership({
  required String input,
  required Iterable<Map<String, dynamic>> appointments,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final ownedCodes = appointments
      .where((appointment) {
        final date = parseAppointmentDate(
          appointment["dateTimestamp"] ?? appointment["date"],
        );
        return date != null &&
            date.year == current.year &&
            date.month == current.month &&
            date.day == current.day;
      })
      .map((appointment) {
        return appointment["queue"]?.toString().trim().toUpperCase() ?? "";
      })
      .where((code) => code.isNotEmpty)
      .toSet();

  if (ownedCodes.contains(input.trim().toUpperCase())) return null;
  if (ownedCodes.isEmpty) {
    return "No appointment queue number is assigned to your account for today.";
  }
  return "Please use your assigned queue number: ${ownedCodes.join(', ')}.";
}

class TrackPage extends StatefulWidget {
  const TrackPage({super.key, this.isWalkInTracking = false});

  /// Walk-in queue codes are issued at the center and intentionally remain
  /// trackable without matching them to a Firebase appointment account.
  final bool isWalkInTracking;

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController queueController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  StreamSubscription<List<Map<String, dynamic>>>? _queueSubscription;

  List<Map<String, dynamic>> _liveQueueItems = const [];
  ConnectionState _queueConnectionState = ConnectionState.waiting;
  Object? _queueStreamError;

  String trackedQueueNumber = "";

  String statusText = "";
  String queueNumberText = "";
  String positionText = "";

  int? queuePosition;
  int? estimatedQueueTime;
  int? travelMinutes;
  int bufferMinutes = 5;
  int? leaveInMinutes;

  String municipalityText = "";
  String orsStatusText = "";
  String leaveAdviceText = "";
  String calculationText = "";

  bool isLoadingEta = false;
  bool isCheckingQueue = false;
  bool isNearTurnDialogOpen = false;
  bool isNowServingDialogOpen = false;

  String? _nearTurnAlertedQueue;
  String? _nowServingAlertedQueue;

  final int averageServiceTime = 9;

  @override
  void initState() {
    super.initState();
    _queueSubscription = todayQueueStream().listen(
      _handleLiveQueueItems,
      onError: _handleLiveQueueError,
    );
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    queueController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  void _handleLiveQueueItems(List<Map<String, dynamic>> items) {
    if (!mounted) return;

    setState(() {
      _liveQueueItems = items;
      _queueConnectionState = ConnectionState.active;
      _queueStreamError = null;
    });

    final queueNumber = trackedQueueNumber;
    if (queueNumber.isEmpty) return;

    unawaited(
      updateTrackedQueueStateFromItems(
        input: queueNumber,
        items: items,
        showNearAlert: true,
        refreshTravelTime: false,
      ),
    );
  }

  void _handleLiveQueueError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    setState(() {
      _queueConnectionState = ConnectionState.active;
      _queueStreamError = error;
    });
  }

  // ================= DATE HELPERS =================

  String todayDate() {
    final now = DateTime.now();
    return "${now.month}/${now.day}/${now.year}";
  }

  String queueDateId(String date) {
    return date.replaceAll("/", "-");
  }

  // ================= FIRESTORE HELPERS =================

  Stream<List<Map<String, dynamic>>> todayQueueStream() {
    final String today = todayDate();

    return FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(today))
        .collection("items")
        .orderBy("createdAt")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            return {...data, "queueId": data["queueId"] ?? doc.id};
          }).toList();
        });
  }

  Future<List<Map<String, dynamic>>> getTodayQueueOnce({
    bool forceServer = false,
  }) async {
    final String today = todayDate();

    final snapshot = await FirebaseFirestore.instance
        .collection("queues")
        .doc(queueDateId(today))
        .collection("items")
        .orderBy("createdAt")
        .get(forceServer ? const GetOptions(source: Source.server) : null);

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {...data, "queueId": data["queueId"] ?? doc.id};
    }).toList();
  }

  Future<void> refreshQueue() async {
    final items = await getTodayQueueOnce(forceServer: true);

    if (!mounted) return;
    setState(() {
      _liveQueueItems = items;
      _queueConnectionState = ConnectionState.active;
      _queueStreamError = null;
    });

    if (trackedQueueNumber.isNotEmpty) {
      await updateTrackedQueueStateFromItems(
        input: trackedQueueNumber,
        items: items,
        showNearAlert: false,
      );
    }
  }

  Map<String, dynamic>? getNowServing(List<Map<String, dynamic>> items) {
    final list = items.where((item) {
      return item["status"]?.toString() == "Now Serving";
    }).toList();

    if (list.isEmpty) return null;

    return list.last;
  }

  List<Map<String, dynamic>> getWaitingQueue(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final status = item["status"]?.toString() ?? "Waiting";
      return status == "Waiting" || status == "Skipped";
    }).toList();
  }

  Map<String, dynamic>? findQueueItem({
    required List<Map<String, dynamic>> items,
    required String queueNumber,
  }) {
    try {
      return items.firstWhere(
        (item) => item["queue"]?.toString().toUpperCase() == queueNumber,
      );
    } catch (_) {
      return null;
    }
  }

  bool isMissedQueue({
    required String input,
    required Map<String, dynamic>? nowServing,
  }) {
    if (nowServing == null) return false;

    final String currentQueue =
        nowServing["queue"]?.toString().toUpperCase() ?? "";

    if (currentQueue.isEmpty || input.isEmpty) return false;

    final String currentPrefix = currentQueue.substring(0, 1);
    final String userPrefix = input.substring(0, 1);

    if (currentPrefix != userPrefix) return false;

    final int currentNumber = int.tryParse(currentQueue.substring(1)) ?? 0;
    final int userNumber = int.tryParse(input.substring(1)) ?? 0;

    return userNumber < currentNumber;
  }

  // ================= CHECK QUEUE =================

  Future<String?> _appointmentQueueOwnershipError(String input) async {
    // The public walk-in entry point must remain independent of any Firebase
    // login that the browser may have cached from an earlier customer session.
    if (widget.isWalkInTracking) return null;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase is unavailable only in isolated widget tests. Treat this as
      // walk-in tracking, which intentionally remains public.
      return null;
    }

    // Walk-in customers can track the queue code printed at the center without
    // signing in. Signed-in appointment customers must use their own code.
    if (user == null) return null;

    try {
      final appointments = FirebaseFirestore.instance.collection(
        "appointments",
      );
      var snapshot = await appointments
          .where("customerId", isEqualTo: user.uid)
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty && (user.email?.trim().isNotEmpty ?? false)) {
        snapshot = await appointments
            .where("customerEmail", isEqualTo: user.email!.trim())
            .get(const GetOptions(source: Source.server));
      }

      return validateAppointmentQueueOwnership(
        input: input,
        appointments: snapshot.docs.map((document) => document.data()),
      );
    } catch (_) {
      return "We could not verify your assigned queue number. Check your internet connection and try again.";
    }
  }

  Future<void> checkQueue() async {
    final String input = queueController.text.trim().toUpperCase();
    final regex = RegExp(r'^[GD]\d+$');

    if (!regex.hasMatch(input)) {
      setState(() {
        trackedQueueNumber = "";
        statusText = "Invalid Queue Format";
        queueNumberText = input;
        positionText = "Use format like G001 or D001";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    setState(() => isCheckingQueue = true);

    final ownershipError = await _appointmentQueueOwnershipError(input);
    if (!mounted) return;
    if (ownershipError != null) {
      setState(() {
        isCheckingQueue = false;
        trackedQueueNumber = "";
        statusText = "This is not your queue number";
        queueNumberText = input;
        positionText = ownershipError;
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });
      return;
    }

    final isNewTrackedQueue = trackedQueueNumber != input;
    setState(() {
      isCheckingQueue = false;
      trackedQueueNumber = input;
      statusText = "";
      queueNumberText = input;
      positionText = "";
      queuePosition = null;
      estimatedQueueTime = null;
      travelMinutes = null;
      leaveInMinutes = null;
      municipalityText = "";
      orsStatusText = "";
      leaveAdviceText = "";
      calculationText = "";
      if (isNewTrackedQueue) {
        _nearTurnAlertedQueue = null;
        _nowServingAlertedQueue = null;
      }
    });

    try {
      final items = await getTodayQueueOnce();
      await updateTrackedQueueStateFromItems(
        input: input,
        items: items,
        showNearAlert: true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isCheckingQueue = false;
        statusText = "Unable to check queue";
        queueNumberText = input;
        positionText = e.toString();
        queuePosition = null;
        estimatedQueueTime = null;
      });
    }
  }

  Future<void> updateTrackedQueueStateFromItems({
    required String input,
    required List<Map<String, dynamic>> items,
    required bool showNearAlert,
    bool refreshTravelTime = true,
  }) async {
    final nowServing = getNowServing(items);
    final queueItem = findQueueItem(items: items, queueNumber: input);

    if (queueItem == null) {
      if (isMissedQueue(input: input, nowServing: nowServing)) {
        if (!mounted) return;

        setState(() {
          statusText = "Sorry, you missed your queue.";
          queueNumberText = input;
          positionText = "Please coordinate with staff.";
          queuePosition = null;
          estimatedQueueTime = null;
          travelMinutes = null;
          leaveInMinutes = null;
          municipalityText = "";
          orsStatusText = "";
          leaveAdviceText = "";
          calculationText = "";
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        statusText = "Queue not found";
        queueNumberText = input;
        positionText = "Please check your queue number.";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    final String status = queueItem["status"]?.toString() ?? "Waiting";

    if (status == "Waiting" || status == "Skipped") {
      final int position =
          calculateLiveQueuePosition(queueNumber: input, items: items) ?? 1;
      final int estimatedTime =
          calculateLiveEstimatedQueueTime(
            queueNumber: input,
            items: items,
            averageServiceMinutes: averageServiceTime,
          ) ??
          averageServiceTime;
      final isAppointment = queueItem["source"] == "Appointment";
      final existingTravelMinutes = travelMinutes;
      final existingMunicipalityText = municipalityText;
      final existingOrsStatusText = orsStatusText;

      if (!mounted) return;

      setState(() {
        statusText = status == "Skipped" ? "Waiting again" : "Waiting";
        queueNumberText = input;
        positionText = "Position $position in line";
        queuePosition = position;
        estimatedQueueTime = estimatedTime;
        if (!isAppointment || refreshTravelTime) {
          travelMinutes = null;
          leaveInMinutes = null;
          municipalityText = queueItem["municipality"] ?? "";
          orsStatusText = "";
          leaveAdviceText = "";
          calculationText = "";
        } else {
          travelMinutes = existingTravelMinutes;
          municipalityText = existingMunicipalityText;
          orsStatusText = existingOrsStatusText;
        }
      });

      if (isAppointment &&
          queueItem["municipality"] != null &&
          queueItem["municipality"].toString().trim().isNotEmpty) {
        if (refreshTravelTime || (travelMinutes == null && !isLoadingEta)) {
          await calculateSmartEta(
            municipality: queueItem["municipality"],
            barangay: queueItem["barangay"]?.toString() ?? "",
            estimatedQueueTime: estimatedTime,
          );
        } else if (travelMinutes != null) {
          _updateSmartEtaForQueueTime(estimatedTime);
        }
      }

      if (showNearAlert && position <= 5) {
        showNearTurnDialog();
      }

      return;
    }

    if (status == "Now Serving") {
      if (!mounted) return;

      setState(() {
        statusText = "NOW SERVING";
        queueNumberText = input;
        positionText = "Please proceed to the testing area";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      unawaited(showNowServingDialog(input));

      return;
    }

    if (status == "Passed") {
      if (!mounted) return;

      setState(() {
        statusText = "Completed - Passed";
        queueNumberText = input;
        positionText = "Your emission test has been marked as passed.";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    if (status == "Failed") {
      if (!mounted) return;

      setState(() {
        statusText = "Completed - Failed";
        queueNumberText = input;
        positionText = "Your emission test has been marked as failed.";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    if (status == "Cancelled" || status == "Reset") {
      if (!mounted) return;

      setState(() {
        statusText = status;
        queueNumberText = input;
        positionText = "This queue number is no longer active.";
        queuePosition = null;
        estimatedQueueTime = null;
        travelMinutes = null;
        leaveInMinutes = null;
        municipalityText = "";
        orsStatusText = "";
        leaveAdviceText = "";
        calculationText = "";
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      statusText = status;
      queueNumberText = input;
      positionText = "Current queue status: $status";
      queuePosition = null;
      estimatedQueueTime = null;
      travelMinutes = null;
      leaveInMinutes = null;
      municipalityText = "";
      orsStatusText = "";
      leaveAdviceText = "";
      calculationText = "";
    });
  }

  Map<String, String> getLiveStatusFromItems(List<Map<String, dynamic>> items) {
    if (trackedQueueNumber.isEmpty) {
      return {
        "status": statusText,
        "position": positionText,
        "queue": queueNumberText,
      };
    }

    final waitingQueue = getWaitingQueue(items);
    final nowServing = getNowServing(items);
    final queueItem = findQueueItem(
      items: items,
      queueNumber: trackedQueueNumber,
    );

    if (queueItem == null) {
      if (isMissedQueue(input: trackedQueueNumber, nowServing: nowServing)) {
        return {
          "status": "Sorry, you missed your queue.",
          "position": "Please coordinate with staff.",
          "queue": trackedQueueNumber,
        };
      }

      return {
        "status": "Queue not found",
        "position": "Please check your queue number.",
        "queue": trackedQueueNumber,
      };
    }

    final String status = queueItem["status"]?.toString() ?? "Waiting";

    if (status == "Waiting" || status == "Skipped") {
      final int index = waitingQueue.indexWhere((item) {
        return item["queue"]?.toString().toUpperCase() == trackedQueueNumber;
      });

      final int position = index >= 0 ? index + 1 : 1;

      return {
        "status": status == "Skipped" ? "Waiting again" : "Waiting",
        "position": "Position $position in line",
        "queue": trackedQueueNumber,
      };
    }

    if (status == "Now Serving") {
      return {
        "status": "NOW SERVING",
        "position": "Please proceed to the testing area",
        "queue": trackedQueueNumber,
      };
    }

    if (status == "Passed") {
      return {
        "status": "Completed - Passed",
        "position": "Your emission test has been marked as passed.",
        "queue": trackedQueueNumber,
      };
    }

    if (status == "Failed") {
      return {
        "status": "Completed - Failed",
        "position": "Your emission test has been marked as failed.",
        "queue": trackedQueueNumber,
      };
    }

    if (status == "Cancelled" || status == "Reset") {
      return {
        "status": status,
        "position": "This queue number is no longer active.",
        "queue": trackedQueueNumber,
      };
    }

    return {
      "status": status,
      "position": "Current queue status: $status",
      "queue": trackedQueueNumber,
    };
  }

  // ================= SMART ETA =================

  Future<void> calculateSmartEta({
    required String municipality,
    String barangay = "",
    required int estimatedQueueTime,
  }) async {
    final normalizedBarangay = barangay.trim();
    final locationLabel = normalizedBarangay.isEmpty
        ? municipality
        : "$normalizedBarangay, $municipality";

    setState(() {
      isLoadingEta = true;
      travelMinutes = null;
      leaveInMinutes = null;
      municipalityText = locationLabel;
      orsStatusText = "";
      leaveAdviceText = "";
      calculationText = "";
    });

    final location = getMunicipalityLocation(municipality);
    final barangayLocation = await OrsService.getBarangayCoordinates(
      barangay: normalizedBarangay,
      municipality: municipality,
    );

    final result = await OrsService.getTravelTimeWithFallback(
      municipality: municipality,
      originLon: barangayLocation?.lon ?? location.lon,
      originLat: barangayLocation?.lat ?? location.lat,
    );

    if (!mounted) return;

    // The queue may move while ORS is calculating. Always use the newest live
    // queue estimate when the travel-time request completes.
    final queueTimeForAdvice = this.estimatedQueueTime ?? estimatedQueueTime;
    final computedLeaveIn =
        queueTimeForAdvice - (result.minutes + bufferMinutes);

    setState(() {
      isLoadingEta = false;

      travelMinutes = result.minutes;
      leaveInMinutes = computedLeaveIn;
      orsStatusText = result.fromLiveOrs && barangayLocation != null
          ? "Live ORS travel time used from the selected barangay."
          : result.message;

      if (computedLeaveIn <= 0) {
        leaveAdviceText =
            "Leave your house now. Your turn is estimated in "
            "${formatQueueDuration(queueTimeForAdvice)}.";
      } else {
        leaveAdviceText =
            "Leave your house in ${formatQueueDuration(computedLeaveIn)}. "
            "Your turn is estimated in "
            "${formatQueueDuration(queueTimeForAdvice)}.";
      }

      calculationText =
          "${formatQueueDuration(queueTimeForAdvice)} queue time - "
          "${formatQueueDuration(result.minutes)} travel time - "
          "${formatQueueDuration(bufferMinutes)} buffer = "
          "${formatQueueDuration(computedLeaveIn <= 0 ? 0 : computedLeaveIn)} "
          "before leaving";
    });
  }

  void _updateSmartEtaForQueueTime(int updatedQueueTime) {
    final currentTravelMinutes = travelMinutes;
    if (!mounted || currentTravelMinutes == null) return;

    final computedLeaveIn =
        updatedQueueTime - (currentTravelMinutes + bufferMinutes);
    setState(() {
      leaveInMinutes = computedLeaveIn;
      if (computedLeaveIn <= 0) {
        leaveAdviceText =
            "Leave your house now. Your turn is estimated in "
            "${formatQueueDuration(updatedQueueTime)}.";
      } else {
        leaveAdviceText =
            "Leave your house in ${formatQueueDuration(computedLeaveIn)}. "
            "Your turn is estimated in "
            "${formatQueueDuration(updatedQueueTime)}.";
      }
      calculationText =
          "${formatQueueDuration(updatedQueueTime)} queue time - "
          "${formatQueueDuration(currentTravelMinutes)} travel time - "
          "${formatQueueDuration(bufferMinutes)} buffer = "
          "${formatQueueDuration(computedLeaveIn <= 0 ? 0 : computedLeaveIn)} "
          "before leaving";
    });
  }

  // ================= ALERT =================

  Future<void> speakNearTurnAlert() async {
    try {
      final filipino = customerVoiceLanguageNotifier.value == "Filipino";
      await QueueVoice.configure(flutterTts, filipino: filipino);
      await flutterTts.speak(QueueVoice.nearTurnMessage(filipino: filipino));
    } catch (_) {
      // Keep the visual queue alert working if voice playback is unavailable.
    }
  }

  Future<void> speakNowServingAlert() async {
    try {
      final filipino = customerVoiceLanguageNotifier.value == "Filipino";
      await QueueVoice.configure(flutterTts, filipino: filipino);
      await flutterTts.speak(QueueVoice.proceedMessage(filipino: filipino));
    } catch (_) {
      // The in-app notification remains available if speech is unsupported.
    }
  }

  void showNearTurnDialog() {
    final queueNumber = trackedQueueNumber;
    if (!mounted ||
        queueNumber.isEmpty ||
        isNearTurnDialogOpen ||
        _nearTurnAlertedQueue == queueNumber) {
      return;
    }

    _nearTurnAlertedQueue = queueNumber;
    isNearTurnDialogOpen = true;

    if (customerVoiceAlertsEnabledNotifier.value) {
      unawaited(speakNearTurnAlert());
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Queue Alert"),
        content: const Text("Please prepare. Your turn is near."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    ).whenComplete(() {
      isNearTurnDialogOpen = false;
    });
  }

  Future<void> showNowServingDialog(String queueNumber) async {
    final normalizedQueue = queueNumber.trim().toUpperCase();
    if (!mounted ||
        normalizedQueue.isEmpty ||
        isNowServingDialogOpen ||
        _nowServingAlertedQueue == normalizedQueue) {
      return;
    }

    _nowServingAlertedQueue = normalizedQueue;

    if (isNearTurnDialogOpen) {
      await Navigator.of(context, rootNavigator: true).maybePop();
      isNearTurnDialogOpen = false;
      if (!mounted) return;
    }

    isNowServingDialogOpen = true;
    if (customerVoiceAlertsEnabledNotifier.value) {
      unawaited(speakNowServingAlert());
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.campaign_rounded, color: Colors.green, size: 44),
        title: Text("Now Serving: $normalizedQueue"),
        content: const Text(
          "Please proceed to the testing area.",
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    isNowServingDialogOpen = false;
  }

  // ================= COLOR HELPERS =================

  Color getAdviceColor() {
    if (leaveInMinutes == null) return Colors.teal;

    if (leaveInMinutes! <= 0) {
      return Colors.red;
    }

    if (leaveInMinutes! <= 10) {
      return Colors.orange;
    }

    return Colors.teal;
  }

  IconData getAdviceIcon() {
    if (leaveInMinutes == null) return Icons.notifications_active;

    if (leaveInMinutes! <= 0) {
      return Icons.warning_amber_rounded;
    }

    if (leaveInMinutes! <= 10) {
      return Icons.directions_walk;
    }

    return Icons.notifications_active;
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final queueSnapshot = _queueStreamError == null
        ? AsyncSnapshot<List<Map<String, dynamic>>>.withData(
            _queueConnectionState,
            _liveQueueItems,
          )
        : AsyncSnapshot<List<Map<String, dynamic>>>.withError(
            _queueConnectionState,
            _queueStreamError!,
          );
    final nowServing = getNowServing(_liveQueueItems);

    return Scaffold(
      backgroundColor: AppColors.activeBackground,
      appBar: AppBar(
        title: const Text("Track Queue"),
        backgroundColor: AppColors.activeSurface,
        foregroundColor: AppColors.activePrimary,
      ),
      body: SafeArea(
        child: AppResponsiveContent(
          maxWidth: 960,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 700;

              return AppRefreshIndicator(
                onRefresh: refreshQueue,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  children: [
                    buildQueueNumberReminder(),

                    const SizedBox(height: 14),

                    buildNowServingCard(nowServing),

                    const SizedBox(height: 18),

                    buildSearchCard(),

                    const SizedBox(height: 18),

                    if (trackedQueueNumber.isNotEmpty)
                      buildLiveQueueStatusCard(queueSnapshot)
                    else if (statusText.isNotEmpty)
                      buildQueueStatusCard(
                        queue: queueNumberText,
                        status: statusText,
                        position: positionText,
                      ),

                    if (estimatedQueueTime != null) ...[
                      const SizedBox(height: 14),
                      buildTimeSummaryCard(),
                    ],

                    if (isLoadingEta)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    if (orsStatusText.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      buildInfoNote(orsStatusText),
                    ],

                    if (leaveAdviceText.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      buildLeaveAdviceCard(),
                    ],

                    if (calculationText.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      buildCalculationCard(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildQueueNumberReminder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.activeSoftPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.activeBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.activePrimary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Please enter only the queue number assigned to you. Using the "
              "correct code prevents confusion and ensures that you track "
              "your own queue.",
              style: TextStyle(
                color: AppColors.activePrimary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= NOW SERVING =================

  Widget buildNowServingCard(Map<String, dynamic>? customer) {
    return AppStatusPulse(
      active: customer != null,
      color: AppColors.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Text(
              "NOW SERVING",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.activeMutedText,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                customer == null ? "-" : customer['queue'] ?? "-",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SEARCH CARD =================

  Widget buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Enter your queue number",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: queueController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: appText("Queue Number"),
              hintText: appText("Example: G001 or D001"),
              filled: true,
              fillColor: AppColors.activeSoftPrimary,
              prefixIcon: const Icon(Icons.confirmation_number),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoadingEta || isCheckingQueue ? null : checkQueue,
              icon: isCheckingQueue
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(isCheckingQueue ? "VERIFYING QUEUE" : "CHECK STATUS"),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LIVE STATUS CARD =================

  Widget buildLiveQueueStatusCard(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return buildQueueStatusCard(
        queue: trackedQueueNumber,
        status: "Loading",
        position: "Checking latest queue status...",
      );
    }

    if (snapshot.hasError) {
      return buildQueueStatusCard(
        queue: trackedQueueNumber,
        status: "Unable to load live status",
        position: snapshot.error.toString(),
      );
    }

    final live = getLiveStatusFromItems(snapshot.data ?? []);

    return buildQueueStatusCard(
      queue: live["queue"] ?? trackedQueueNumber,
      status: live["status"] ?? "-",
      position: live["position"] ?? "-",
    );
  }

  // ================= QUEUE STATUS CARD =================

  Widget buildQueueStatusCard({
    required String queue,
    required String status,
    required String position,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.format_list_numbered,
            title: "Queue Status",
          ),
          const SizedBox(height: 14),
          infoRow(label: "Queue Number", value: queue.isEmpty ? "-" : queue),
          infoRow(label: "Status", value: status),
          infoRow(label: "Position", value: position),
        ],
      ),
    );
  }

  // ================= TIME SUMMARY CARD =================

  Widget buildTimeSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(icon: Icons.timer, title: "Time Summary"),
          const SizedBox(height: 14),
          timeItem(
            icon: Icons.schedule,
            title: "Estimated Queue Time",
            value: formatQueueDuration(estimatedQueueTime ?? 0),
            subtitle:
                "Based on position ${queuePosition ?? '-'} × $averageServiceTime mins per customer",
            color: Colors.green,
          ),
          if (municipalityText.isNotEmpty && travelMinutes != null) ...[
            const SizedBox(height: 10),
            timeItem(
              icon: Icons.directions_car,
              title: "Travel Time",
              value: formatQueueDuration(travelMinutes!),
              subtitle: "From $municipalityText to NPJN",
              color: Colors.purple,
            ),
            const SizedBox(height: 10),
            timeItem(
              icon: Icons.add_alarm,
              title: "Safety Buffer",
              value: formatQueueDuration(bufferMinutes),
              subtitle: "Allowance for parking, traffic, and preparation",
              color: Colors.blueGrey,
            ),
          ],
        ],
      ),
    );
  }

  // ================= LEAVE ADVICE CARD =================

  Widget buildLeaveAdviceCard() {
    final color = getAdviceColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(getAdviceIcon(), color: color, size: 38),
          const SizedBox(height: 10),
          Text(
            "SMART LEAVE ADVICE",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.activeMutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            leaveAdviceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CALCULATION CARD =================

  Widget buildCalculationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.calculate,
            title: "How This Was Calculated",
          ),
          const SizedBox(height: 14),
          calculationLine(
            label: "Queue waiting time",
            value: formatQueueDuration(estimatedQueueTime ?? 0),
            icon: Icons.schedule,
          ),
          calculationLine(
            label: "Minus travel time",
            value: "- ${formatQueueDuration(travelMinutes ?? 0)}",
            icon: Icons.directions_car,
          ),
          calculationLine(
            label: "Minus safety buffer",
            value: "- ${formatQueueDuration(bufferMinutes)}",
            icon: Icons.add_alarm,
          ),
          const Divider(height: 22),
          calculationLine(
            label: "Recommended leave time",
            value: formatQueueDuration(
              (leaveInMinutes ?? 0) <= 0 ? 0 : leaveInMinutes!,
            ),
            icon: Icons.notifications_active,
            bold: true,
          ),
          const SizedBox(height: 8),
          Text(
            calculationText,
            style: TextStyle(
              color: AppColors.activeMutedText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SMALL WIDGETS =================

  Widget sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.activeMutedText),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ],
    );
  }

  Widget infoRow({required String label, required String value}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.activeSoftPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.activeBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.activeMutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget timeItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.activeSoftPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.activeBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.activeMutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget calculationLine({
    required String label,
    required String value,
    required IconData icon,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.activeMutedText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
              color: bold ? getAdviceColor() : AppColors.activePrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoNote(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.activeMutedText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: AppColors.activeMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: AppColors.activeSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.activeBorder),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
      ],
    );
  }
}
