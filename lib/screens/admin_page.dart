import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'daily_report.dart';
import 'display_page.dart';
import 'admin_dashboard.dart';
import 'home_page.dart';
import 'admin_settings.dart';

// ================= GLOBAL VARIABLES =================

ValueNotifier<Map<String, List<Map<String, dynamic>>>>
    dailyServedReportNotifier = ValueNotifier({});

ValueNotifier<Map<String, List<Map<String, dynamic>>>>
    dailyFailedReportNotifier = ValueNotifier({});

ValueNotifier<Map<String, List<String>>> dailyHistoryNotifier =
    ValueNotifier({});

ValueNotifier<List<Map<String, dynamic>>> waitingQueueNotifier =
    ValueNotifier([]);

ValueNotifier<Map<String, dynamic>?> nowServingNotifier = ValueNotifier(null);

ValueNotifier<String> selectedQueueDateNotifier =
    ValueNotifier(formatDate(DateTime.now()));

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
    );

    if (picked != null) {
      selectedQueueDateNotifier.value = formatDate(picked);
      setState(() {});
    }
  }

  // ================= FILTER QUEUE BY SELECTED DATE =================

  List<Map<String, dynamic>> getQueueForSelectedDate() {
    return waitingQueueNotifier.value.where((customer) {
      return customer["date"] == selectedQueueDateNotifier.value;
    }).toList();
  }

  bool isNowServingForSelectedDate() {
    if (nowServingNotifier.value == null) return false;

    return nowServingNotifier.value!["date"] ==
        selectedQueueDateNotifier.value;
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
      return customer["date"] == selectedDate &&
          customer["queue"] == queueCode;
    });

    bool inNowServing = nowServingNotifier.value != null &&
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
    final updatedIssued =
        Map<String, List<String>>.from(issuedQueueCodesNotifier.value);

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
        title: Text(
          text("Generate $type Queue", "Gumawa ng $type Queue"),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: text("Customer Name", "Pangalan ng Customer"),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text("Cancel", "Kanselahin")),
          ),
          ElevatedButton(
            onPressed: () {
              generateQueue(type, nameController.text.trim());
              Navigator.pop(context);
            },
            child: Text(text("Generate Queue", "Gumawa ng Queue")),
          ),
        ],
      ),
    );
  }

  // ================= GENERATE QUEUE =================

  void generateQueue(String type, String name) {
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
      return;
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
      return;
    }

    String queueNumber = generateNextAvailableQueueCode(type);

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
      return;
    }

    final updatedQueue =
        List<Map<String, dynamic>>.from(waitingQueueNotifier.value);

    updatedQueue.add({
      "queue": queueNumber,
      "name": name,
      "type": type,
      "date": selectedDate,
      "source": "Walk-in",
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
  }

  // ================= CALL CUSTOMER =================

  void callCustomer(Map<String, dynamic> customer) async {
    final updatedQueue =
        List<Map<String, dynamic>>.from(waitingQueueNotifier.value);

    updatedQueue.remove(customer);

    waitingQueueNotifier.value = updatedQueue;

    nowServingNotifier.value = customer;

    await speak(customer['queue']);

    setState(() {});
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

  void skipCustomer() {
    final customer = getDisplayedNowServing();

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text(
              "No customer to skip",
              "Walang customer na i-skip",
            ),
          ),
        ),
      );
      return;
    }

    final skippedCustomer = {
      ...customer,
      "source": "Skipped / No Show",
    };

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
  }

  // ================= PASSED =================

  void markPassed() {
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

    final updatedServed =
        Map<String, List<Map<String, dynamic>>>.from(
      dailyServedReportNotifier.value,
    );

    final servedList =
        List<Map<String, dynamic>>.from(updatedServed[date] ?? []);

    servedList.add({
      ...customer,
      "result": "Passed",
      "time": TimeOfDay.now().format(context),
    });

    updatedServed[date] = servedList;
    dailyServedReportNotifier.value = updatedServed;

    final updatedOldHistory =
        Map<String, List<String>>.from(dailyHistoryNotifier.value);

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
  }

  // ================= FAILED =================

  void markFailed() {
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

    final updatedFailed =
        Map<String, List<Map<String, dynamic>>>.from(
      dailyFailedReportNotifier.value,
    );

    final failedList =
        List<Map<String, dynamic>>.from(updatedFailed[date] ?? []);

    failedList.add({
      ...customer,
      "result": "Failed",
      "time": TimeOfDay.now().format(context),
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
  }

  // ================= CANCEL QUEUE =================

  void cancelQueue(Map<String, dynamic> customer) {
    final updatedQueue =
        List<Map<String, dynamic>>.from(waitingQueueNotifier.value);

    updatedQueue.remove(customer);

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
  }

  // ================= DAILY RESET =================

  void resetDay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(text("Reset System", "I-reset ang System")),
        content: Text(
          text(
            "This will clear all queues and start a new day.",
            "Mabubura ang lahat ng queue at magsisimula ng bagong araw.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text("Cancel", "Kanselahin")),
          ),
          ElevatedButton(
            onPressed: () {
              waitingQueueNotifier.value = [];
              nowServingNotifier.value = null;
              issuedQueueCodesNotifier.value = {};

              gasCounter = 1;
              dieselCounter = 1;

              totalQueue = 0;
              completedQueue = 0;

              selectedQueueDateNotifier.value = formatDate(DateTime.now());

              setState(() {});

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    text(
                      "System reset for new day",
                      "Na-reset ang system para sa bagong araw",
                    ),
                  ),
                ),
              );
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
    List<Map<String, dynamic>> selectedDateQueue = getQueueForSelectedDate();
    Map<String, dynamic>? displayedNowServing = getDisplayedNowServing();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),
      drawer: buildDrawer(),
      appBar: AppBar(
        title: Text(text("Admin Control Panel", "Admin Control Panel")),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = isWideScreen(constraints.maxWidth);
            final bool tablet = isTabletScreen(constraints.maxWidth);

            return Padding(
              padding: EdgeInsets.all(wide ? 20 : 12),
              child: Column(
                children: [
                  buildDateSelector(),
                  const SizedBox(height: 14),
                  buildStatsSection(
                    selectedDateQueue: selectedDateQueue,
                    compact: !wide,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: wide || tablet
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: wide ? 230 : 205,
                                child: buildLeftPanel(),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: buildRightPanel(
                                  selectedDateQueue: selectedDateQueue,
                                  displayedNowServing: displayedNowServing,
                                  fixedListHeight: false,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                buildLeftPanel(),
                                const SizedBox(height: 16),
                                buildRightPanel(
                                  selectedDateQueue: selectedDateQueue,
                                  displayedNowServing: displayedNowServing,
                                  fixedListHeight: true,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= DRAWER =================

  Widget buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 50,
                ),
                const SizedBox(height: 10),
                Text(
                  text("Admin Panel", "Admin Panel"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.queue),
            title: Text(text("Queue Panel", "Queue Panel")),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(text("Booking Dashboard", "Booking Dashboard")),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminDashboard(),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: Text(text("Daily Report", "Daily Report")),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyReport(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(text("Settings", "Settings")),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminSettings(),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(text("Logout", "Logout")),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HomePage(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= DATE SELECTOR =================

  Widget buildDateSelector() {
    return cardContainer(
      child: Row(
        children: [
          const Icon(Icons.calendar_month),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text(
                "Queue Date: ${selectedQueueDateNotifier.value}",
                "Petsa ng Queue: ${selectedQueueDateNotifier.value}",
              ),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
          statCard(
            text("Completed", "Tapos Na"),
            completedForDate,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        statBox(
          text("Total Queue", "Kabuuang Queue"),
          issuedCountForSelectedDate().toString(),
        ),
        statBox(
          text("Waiting Queue", "Naghihintay"),
          selectedDateQueue.length.toString(),
        ),
        statBox(
          text("Completed", "Tapos Na"),
          completedForDate,
        ),
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
              Text(
                text("Generate Queue", "Gumawa ng Queue"),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showGenerateDialog("Gas");
                  },
                  child: const Text("GAS"),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showGenerateDialog("Diesel");
                  },
                  child: const Text("DIESEL"),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.tv),
            label: Text(text("DISPLAY PAGE", "DISPLAY PAGE")),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DisplayPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: Text(text("DAILY RESET", "DAILY RESET")),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: resetDay,
          ),
        ),
      ],
    );
  }

  // ================= RIGHT PANEL =================

  Widget buildRightPanel({
    required List<Map<String, dynamic>> selectedDateQueue,
    required Map<String, dynamic>? displayedNowServing,
    required bool fixedListHeight,
  }) {
    return Column(
      children: [
        buildNowServingCard(displayedNowServing),
        const SizedBox(height: 18),
        fixedListHeight
            ? SizedBox(
                height: 430,
                child: buildWaitingQueueCard(selectedDateQueue),
              )
            : Expanded(
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
          Text(
            text("NOW SERVING", "KASALUKUYANG TINATAWAG"),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayedNowServing == null
                  ? "-"
                  : displayedNowServing['queue'],
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            displayedNowServing == null ? "" : displayedNowServing['name'],
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              miniButton(
                Icons.volume_up,
                Colors.blue,
                callAgain,
              ),
              miniButton(
                Icons.skip_next,
                Colors.orange,
                skipCustomer,
              ),
              miniButton(
                Icons.check,
                Colors.green,
                markPassed,
              ),
              miniButton(
                Icons.close,
                Colors.red,
                markFailed,
              ),
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
          Text(
            text(
              "Waiting Queue - ${selectedQueueDateNotifier.value}",
              "Waiting Queue - ${selectedQueueDateNotifier.value}",
            ),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: selectedDateQueue.isEmpty
                ? Center(
                    child: Text(
                      text(
                        "No queue for this date",
                        "Walang queue sa petsang ito",
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedDateQueue.length,
                    itemBuilder: (context, index) {
                      final customer = selectedDateQueue[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool narrow = constraints.maxWidth < 360;

                            if (narrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildQueueInfo(customer),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      miniButton(
                                        Icons.volume_up,
                                        Colors.blue,
                                        () {
                                          callCustomer(customer);
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      miniButton(
                                        Icons.close,
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
                                Expanded(
                                  child: buildQueueInfo(customer),
                                ),
                                miniButton(
                                  Icons.volume_up,
                                  Colors.blue,
                                  () {
                                    callCustomer(customer);
                                  },
                                ),
                                const SizedBox(width: 8),
                                miniButton(
                                  Icons.close,
                                  Colors.red,
                                  () {
                                    cancelQueue(customer);
                                  },
                                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customer['queue'],
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          customer['name'],
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          customer['source'] ?? "",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ================= CARD =================

  Widget cardContainer({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  // ================= STAT CARD =================

  Widget statCard(
    String title,
    String value,
  ) {
    return Expanded(
      child: cardContainer(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statBox(
    String title,
    String value,
  ) {
    return SizedBox(
      width: 160,
      child: cardContainer(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MINI BUTTON =================

  Widget miniButton(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: 18,
        ),
      ),
    );
  }
}