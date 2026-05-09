import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'daily_report.dart';
import 'display_page.dart';
import 'admin_dashboard.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'admin_settings.dart';

// ================= GLOBAL VARIABLES =================

// Daily report storage
ValueNotifier<Map<String, List<String>>> dailyHistoryNotifier = ValueNotifier({});
// Key = date string (MM/DD/YYYY), Value = list of queue numbers served that day

ValueNotifier<List<Map<String, dynamic>>> waitingQueueNotifier =
    ValueNotifier([]);

ValueNotifier<Map<String, dynamic>?> nowServingNotifier = ValueNotifier(null);

// Selected queue date for Admin Queue Panel
ValueNotifier<String> selectedQueueDateNotifier =
    ValueNotifier(formatDate(DateTime.now()));

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

    return nowServingNotifier.value!["date"] == selectedQueueDateNotifier.value;
  }

  Map<String, dynamic>? getDisplayedNowServing() {
    if (isNowServingForSelectedDate()) {
      return nowServingNotifier.value;
    }

    return null;
  }

  // ================= QUEUE CODE HELPERS =================

  bool queueCodeExistsOnSelectedDate(String queueCode) {
    bool inWaiting = waitingQueueNotifier.value.any((customer) {
      return customer["date"] == selectedQueueDateNotifier.value &&
          customer["queue"] == queueCode;
    });

    bool inNowServing = nowServingNotifier.value != null &&
        nowServingNotifier.value!["date"] == selectedQueueDateNotifier.value &&
        nowServingNotifier.value!["queue"] == queueCode;

    return inWaiting || inNowServing;
  }

  String generateNextAvailableQueueCode(String type) {
    String prefix = type == "Gas" ? "G" : "D";
    int number = 1;

    while (true) {
      String queueCode = "$prefix${number.toString().padLeft(3, '0')}";

      if (!queueCodeExistsOnSelectedDate(queueCode)) {
        return queueCode;
      }

      number++;
    }
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

    List<Map<String, dynamic>> selectedDateQueue = getQueueForSelectedDate();

    if (selectedDateQueue.length >= maxQueueLimit) {
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

    final updatedQueue =
        List<Map<String, dynamic>>.from(waitingQueueNotifier.value);

    updatedQueue.add({
      "queue": queueNumber,
      "name": name,
      "type": type,
      "date": selectedQueueDateNotifier.value,
      "source": "Walk-in",
    });

    waitingQueueNotifier.value = updatedQueue;

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

    nowServingNotifier.value = null;

    setState(() {
      // Record to daily history
final customer = nowServingNotifier.value;
if (customer != null) {
  final date = customer["date"] ?? "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
  final updatedHistory = Map<String, List<String>>.from(dailyHistoryNotifier.value);

  if (!updatedHistory.containsKey(date)) {
    updatedHistory[date] = [];
  }
  updatedHistory[date]!.add(customer["queue"]);

  dailyHistoryNotifier.value = updatedHistory;
}
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

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> selectedDateQueue = getQueueForSelectedDate();
    Map<String, dynamic>? displayedNowServing = getDisplayedNowServing();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),

      // ================= DRAWER =================
      

      drawer: Drawer(
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
  leading: const Icon(Icons.history),
  title: const Text("Daily Report"),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyReport()),
    );
  },
),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(text("History", "History")),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistoryPage(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(text("Settings", "Settings")),
              onTap: () {
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
      ),

      appBar: AppBar(
        title: Text(text("Admin Control Panel", "Admin Control Panel")),
        backgroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= DATE SELECTOR =================

            cardContainer(
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
            ),

            const SizedBox(height: 15),

            // ================= TOP STATS =================

            Row(
              children: [
                statCard(
                  text("Total Queue", "Kabuuang Queue"),
                  selectedDateQueue.length.toString(),
                ),
                const SizedBox(width: 10),
                statCard(
                  text("Waiting Queue", "Naghihintay"),
                  selectedDateQueue.length.toString(),
                ),
                const SizedBox(width: 10),
                statCard(
                  text("Completed", "Tapos Na"),
                  completedQueue.toString(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Row(
                children: [
                  // ================= LEFT PANEL =================

                  SizedBox(
                    width: 190,
                    child: Column(
                      children: [
                        cardContainer(
                          child: Column(
                            children: [
                              Text(
                                text("Generate Queue", "Gumawa ng Queue"),
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

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DisplayPage(),
                                ),
                              );
                            },
                            child: Text(text("DISPLAY PAGE", "DISPLAY PAGE")),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: resetDay,
                            child: Text(text("DAILY RESET", "DAILY RESET")),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // ================= RIGHT PANEL =================

                  Expanded(
                    child: Column(
                      children: [
                        // ================= NOW SERVING =================

                        cardContainer(
                          child: Column(
                            children: [
                              Text(
                                text("NOW SERVING", "KASALUKUYANG TINATAWAG"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 15),

                              Text(
                                displayedNowServing == null
                                    ? "-"
                                    : displayedNowServing['queue'],
                                style: const TextStyle(
                                  fontSize: 45,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                displayedNowServing == null
                                    ? ""
                                    : displayedNowServing['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  miniButton(
                                    Icons.volume_up,
                                    Colors.blue,
                                    callAgain,
                                  ),

                                  const SizedBox(width: 10),

                                  miniButton(
                                    Icons.skip_next,
                                    Colors.orange,
                                    skipCustomer,
                                  ),

                                  const SizedBox(width: 10),

                                  miniButton(
                                    Icons.check,
                                    Colors.green,
                                    markPassed,
                                  ),

                                  const SizedBox(width: 10),

                                  miniButton(
                                    Icons.close,
                                    Colors.red,
                                    markFailed,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ================= WAITING QUEUE =================

                        Expanded(
                          child: cardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text(
                                    "Waiting Queue - ${selectedQueueDateNotifier.value}",
                                    "Waiting Queue - ${selectedQueueDateNotifier.value}",
                                  ),
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
                                            final customer =
                                                selectedDateQueue[index];

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          customer['queue'],
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(customer['name']),
                                                        Text(
                                                          customer['source'] ??
                                                              "",
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                                              ),
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
                ],
              ),
            ),
          ],
        ),
      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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