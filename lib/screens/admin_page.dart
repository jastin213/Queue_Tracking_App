import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'daily_report.dart';
import 'display_page.dart';
import 'admin_dashboard.dart';
import 'home_page.dart';
import 'admin_settings.dart';

// ================= COLOR THEME =================

const Color _backgroundColor = Color(0xFFF1FAFC);
const Color _primaryColor = Color(0xFF071F35);
const Color _cardColor = Colors.white;
const Color _borderColor = Color(0xFFD8E8EE);
const Color _mutedTextColor = Color(0xFF6E7E88);
const Color _softPrimaryColor = Color(0xFFEAF4F8);

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

// ================= ADMIN PAGE =================

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FlutterTts flutterTts = FlutterTts();

  bool get isFilipino => appLanguageNotifier.value == "Filipino";

  String text(String english, String filipino) {
    return isFilipino ? filipino : english;
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

        return {
          ...data,
          "queueId": data["queueId"] ?? doc.id,
        };
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getQueueItemsOnline(String date) async {
    final snapshot = await queueItemsRef(date).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        ...data,
        "queueId": data["queueId"] ?? doc.id,
      };
    }).toList();
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

    final issuedList = onlineItems.where((item) {
      final status = item["status"]?.toString() ?? "";
      return item["date"] == selectedDate &&
          status != "Cancelled" &&
          status != "Reset";
    }).map((item) {
      return item["queue"].toString();
    }).toList();

    waitingQueueNotifier.value = waiting;

    nowServingNotifier.value =
        nowServingList.isEmpty ? null : nowServingList.last;

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

    await queueItemsRef(date).doc(queue).set(
      {
        ...customer,
        "queueId": queue,
        "queue": queue,
        "date": date,
        "status": status,
        "updatedAt": FieldValue.serverTimestamp(),
        ...?extraData,
      },
      SetOptions(merge: true),
    );
  }

  // ================= SPEAK =================

  Future<void> speak(String queueNumber) async {
    if (voiceLanguageNotifier.value == "Filipino") {
      await flutterTts.setLanguage("fil-PH");
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(
        "Tinatawag ang numero $queueNumber, pumunta na po sa testing area",
      );
    } else {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.45);
      await flutterTts.setPitch(1.0);

      await flutterTts.speak(
        "Now serving $queueNumber, please proceed to the testing area",
      );
    }
  }

  // ================= PICK QUEUE DATE =================

  Future<void> pickQueueDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      selectedQueueDateNotifier.value = formatDate(picked);
      setState(() {});
    }
  }

  // ================= FILTER QUEUE BY SELECTED DATE =================

  List<Map<String, dynamic>> getQueueForSelectedDate() {
    return waitingQueueNotifier.value.where((customer) {
      final status = customer["status"]?.toString() ?? "Waiting";

      return customer["date"] == selectedQueueDateNotifier.value &&
          (status == "Waiting" || status == "Skipped");
    }).toList();
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

  void showGenerateDialog(String type) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          text("Generate $type Queue", "Gumawa ng $type Queue"),
          style: const TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: text("Customer Name", "Pangalan ng Customer"),
            labelStyle: const TextStyle(color: _mutedTextColor),
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              color: _primaryColor,
            ),
            filled: true,
            fillColor: _backgroundColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 1.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context),
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
            onPressed: () async {
              final success = await generateQueue(
                type,
                nameController.text.trim(),
              );

              if (success && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(text("Generate Queue", "Gumawa ng Queue")),
          ),
        ],
      ),
    );
  }

  // ================= GENERATE QUEUE =================

  Future<bool> generateQueue(String type, String name) async {
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

    final String selectedDate = selectedQueueDateNotifier.value;

    if (issuedCountForSelectedDate() >= maxQueueLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "QUEUE CLOSED — DAILY LIMIT REACHED",
              "SARADO NA ANG QUEUE — NAABOT NA ANG DAILY LIMIT",
            ),
          ),
        ),
      );
      return false;
    }

    String queueNumber = await generateNextAvailableQueueCodeOnline(type);

    if (queueNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "No available queue number for this type",
              "Wala nang available na queue number para sa type na ito",
            ),
          ),
        ),
      );
      return false;
    }

    final Map<String, dynamic> queueData = {
      "queueId": queueNumber,
      "queue": queueNumber,
      "name": name,
      "type": type,
      "date": selectedDate,
      "source": "Walk-in",
      "status": "Waiting",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      await queueItemsRef(selectedDate).doc(queueNumber).set(queueData);

      final updatedQueue = List<Map<String, dynamic>>.from(
        waitingQueueNotifier.value,
      );

      updatedQueue.add({
        "queueId": queueNumber,
        "queue": queueNumber,
        "name": name,
        "type": type,
        "date": selectedDate,
        "source": "Walk-in",
        "status": "Waiting",
      });

      waitingQueueNotifier.value = updatedQueue;

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save queue online: $e")),
      );

      return false;
    }
  }

  // ================= CALL CUSTOMER =================

  Future<void> callCustomer(Map<String, dynamic> customer) async {
    try {
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

      nowServingNotifier.value = {
        ...customer,
        "status": "Now Serving",
      };

      await speak(customer['queue']);

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to call customer: $e")),
      );
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

    final skippedCustomer = {
      ...customer,
      "source": "Skipped / No Show",
      "status": "Skipped",
    };

    try {
      await updateQueueItemStatus(
        customer: skippedCustomer,
        status: "Skipped",
        extraData: {
          "source": "Skipped / No Show",
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to skip customer: $e")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as passed: $e")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark as failed: $e")),
      );
    }
  }

  // ================= CANCEL QUEUE =================

  Future<void> cancelQueue(Map<String, dynamic> customer) async {
    try {
      await updateQueueItemStatus(
        customer: customer,
        status: "Cancelled",
        extraData: {
          "cancelledAt": FieldValue.serverTimestamp(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel queue: $e")),
      );
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
          style: const TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          text(
            "This will clear the active queues for the selected date.",
            "Mabubura ang active queues para sa napiling petsa.",
          ),
          style: const TextStyle(color: _mutedTextColor, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              side: const BorderSide(color: _primaryColor),
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

                final batch = FirebaseFirestore.instance.batch();

                for (final item in onlineItems) {
                  final status = item["status"]?.toString() ?? "";

                  if (status == "Waiting" ||
                      status == "Now Serving" ||
                      status == "Skipped") {
                    final queue = item["queue"]?.toString() ?? "";

                    if (queue.isNotEmpty) {
                      batch.update(queueItemsRef(selectedDate).doc(queue), {
                        "status": "Reset",
                        "resetAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp(),
                      });
                    }
                  }
                }

                await batch.commit();

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Reset failed: $e")),
                  );
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
              syncLocalQueueFromFirestore(snapshot.data!);
            }

            List<Map<String, dynamic>> selectedDateQueue =
                getQueueForSelectedDate();
            Map<String, dynamic>? displayedNowServing =
                getDisplayedNowServing();

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
              child: Scaffold(
                backgroundColor: _backgroundColor,
                drawer: buildDrawer(),
                appBar: AppBar(
                  title:
                      Text(text("Admin Control Panel", "Admin Control Panel")),
                ),
                body: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool wide = isWideScreen(constraints.maxWidth);
                      final bool tablet =
                          isTabletScreen(constraints.maxWidth);
                      final double pagePadding = wide ? 20 : 12;

                      final double waitingListHeight = wide || tablet
                          ? (constraints.maxHeight - 420).clamp(360.0, 720.0)
                          : 430.0;

                      return SingleChildScrollView(
                        padding: EdgeInsets.all(pagePadding),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                constraints.maxHeight - (pagePadding * 2),
                          ),
                          child: Column(
                            children: [
                              buildDateSelector(),
                              const SizedBox(height: 14),
                              buildStatsSection(
                                selectedDateQueue: selectedDateQueue,
                                compact: !wide,
                              ),
                              const SizedBox(height: 18),
                              if (wide || tablet)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: wide ? 245 : 215,
                                      child: buildLeftPanel(),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: buildRightPanel(
                                        selectedDateQueue: selectedDateQueue,
                                        displayedNowServing:
                                            displayedNowServing,
                                        waitingListHeight: waitingListHeight,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    buildLeftPanel(),
                                    const SizedBox(height: 16),
                                    buildRightPanel(
                                      selectedDateQueue: selectedDateQueue,
                                      displayedNowServing:
                                          displayedNowServing,
                                      waitingListHeight: waitingListHeight,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
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
            decoration: const BoxDecoration(color: _primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
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
          drawerTile(
            icon: Icons.queue_rounded,
            title: text("Queue Panel", "Queue Panel"),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          drawerTile(
            icon: Icons.dashboard_rounded,
            title: text("Appointment Dashboard", "Appointment Dashboard"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
              ).then((_) {
                setState(() {});
              });
            },
          ),
          drawerTile(
            icon: Icons.assessment_rounded,
            title: text("Daily Report", "Daily Report"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailyReport()),
              );
            },
          ),
          drawerTile(
            icon: Icons.settings_rounded,
            title: text("Settings", "Settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSettings()),
              ).then((_) {
                setState(() {});
              });
            },
          ),
          const Divider(color: _borderColor, height: 24),
          drawerTile(
            icon: Icons.logout_rounded,
            title: text("Logout", "Logout"),
            isLogout: true,
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: _cardColor,
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

  // ================= DATE SELECTOR =================

  Widget buildDateSelector() {
    return cardContainer(
      child: Row(
        children: [
          iconBox(Icons.calendar_month_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text(
                "Queue Date: ${selectedQueueDateNotifier.value}",
                "Petsa ng Queue: ${selectedQueueDateNotifier.value}",
              ),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _primaryColor,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: pickQueueDate,
            child: Text(text("Change Date", "Palitan")),
          ),
        ],
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

  Widget buildLeftPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardContainer(
          child: Column(
            children: [
              sectionHeader(
                icon: Icons.confirmation_number_rounded,
                title: text("Generate Queue", "Gumawa ng Queue"),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showGenerateDialog("Gas");
                  },
                  icon: const Icon(Icons.directions_car_rounded),
                  label: const Text("GAS"),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showGenerateDialog("Diesel");
                  },
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DisplayPage()),
                    );
                  },
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

  // ================= RIGHT PANEL =================

  Widget buildRightPanel({
    required List<Map<String, dynamic>> selectedDateQueue,
    required Map<String, dynamic>? displayedNowServing,
    required double waitingListHeight,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildNowServingCard(displayedNowServing),
        const SizedBox(height: 18),
        SizedBox(
          height: waitingListHeight,
          child: buildWaitingQueueCard(selectedDateQueue),
        ),
      ],
    );
  }

  // ================= NOW SERVING CARD =================

  Widget buildNowServingCard(Map<String, dynamic>? displayedNowServing) {
    return cardContainer(
      child: Column(
        children: [
          sectionHeader(
            icon: Icons.campaign_rounded,
            title: text("NOW SERVING", "KASALUKUYANG TINATAWAG"),
            centered: true,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
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
                      ? text("No customer currently called", "Walang tinatawag")
                      : displayedNowServing['name'],
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              miniButton(Icons.volume_up_rounded, Colors.blue, callAgain),
              miniButton(Icons.skip_next_rounded, Colors.orange, skipCustomer),
              miniButton(Icons.check_rounded, Colors.green, markPassed),
              miniButton(Icons.close_rounded, Colors.red, markFailed),
            ],
          ),
        ],
      ),
    );
  }

  // ================= WAITING QUEUE CARD =================

  Widget buildWaitingQueueCard(List<Map<String, dynamic>> selectedDateQueue) {
    return cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            icon: Icons.groups_rounded,
            title: text(
              "Waiting Queue - ${selectedQueueDateNotifier.value}",
              "Waiting Queue - ${selectedQueueDateNotifier.value}",
            ),
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
                          const Icon(
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
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w800,
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
                                        Colors.blue,
                                        () {
                                          callCustomer(customer);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      miniButton(
                                        Icons.close_rounded,
                                        Colors.red,
                                        () {
                                          cancelQueue(customer);
                                        },
                                      ),
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
                                  Colors.blue,
                                  () {
                                    callCustomer(customer);
                                  },
                                ),
                                const SizedBox(width: 8),
                                miniButton(Icons.close_rounded, Colors.red, () {
                                  cancelQueue(customer);
                                }),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                customer['name'] ?? "-",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mutedTextColor,
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
                  style: const TextStyle(
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

  Widget cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: _primaryColor.withOpacity(0.06), blurRadius: 14),
        ],
      ),
      child: child,
    );
  }

  Widget iconBox(IconData icon) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: _softPrimaryColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Icon(icon, color: _primaryColor, size: 23),
    );
  }

  Widget sectionHeader({
    required IconData icon,
    required String title,
    bool centered = false,
  }) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(icon, color: _primaryColor, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
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
    return Expanded(child: statContent(title, value));
  }

  Widget statBox(String title, String value) {
    return SizedBox(width: 160, child: statContent(title, value));
  }

  Widget statContent(String title, String value) {
    IconData icon = Icons.confirmation_number_rounded;
    Color accentColor = _primaryColor;

    if (title.contains("Waiting") || title.contains("Naghihintay")) {
      icon = Icons.groups_rounded;
      accentColor = Colors.orange;
    } else if (title.contains("Completed") || title.contains("Tapos")) {
      icon = Icons.check_circle_outline_rounded;
      accentColor = Colors.green;
    }

    return cardContainer(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
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

  Widget miniButton(IconData icon, Color color, VoidCallback onPressed) {
    return Tooltip(
      message: icon == Icons.volume_up_rounded
          ? text("Call", "Tawagin")
          : icon == Icons.skip_next_rounded
              ? text("Skip", "I-skip")
              : icon == Icons.check_rounded
                  ? text("Passed", "Passed")
                  : text("Cancel / Failed", "Cancel / Failed"),
      child: SizedBox(
        width: 42,
        height: 42,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
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