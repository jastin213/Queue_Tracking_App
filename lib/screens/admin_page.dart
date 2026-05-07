import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'display_page.dart';
import 'admin_dashboard.dart';
import 'history_page.dart';
import 'home_page.dart';

// ================= GLOBAL VARIABLES =================

ValueNotifier<List<Map<String, dynamic>>> waitingQueueNotifier =
    ValueNotifier([]);

ValueNotifier<Map<String, dynamic>?> nowServingNotifier =
    ValueNotifier(null);

int totalQueue = 0;
int completedQueue = 0;

int gasCounter = 1;
int dieselCounter = 1;

const int maxQueueLimit = 80;

// ================= ADMIN PAGE =================

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FlutterTts flutterTts = FlutterTts();

  // ================= SPEAK =================

  Future speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setPitch(1.0);

    await flutterTts.speak(text);
  }

  // ================= GENERATE DIALOG =================

  void showGenerateDialog(String type) {
    final TextEditingController nameController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Generate $type Queue"),

        content: TextField(
          controller: nameController,

          decoration: const InputDecoration(
            labelText: "Customer Name",
            border: OutlineInputBorder(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () {
              generateQueue(
                type,
                nameController.text.trim(),
              );

              Navigator.pop(context);
            },
            child: const Text("Generate Queue"),
          ),
        ],
      ),
    );
  }

  // ================= GENERATE QUEUE =================

  void generateQueue(
    String type,
    String name,
  ) {
    if (name.isEmpty) return;

    // DAILY LIMIT
    if (totalQueue >= maxQueueLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "QUEUE CLOSED — DAILY LIMIT REACHED",
          ),
        ),
      );

      return;
    }

    String queueNumber;

    if (type == "Gas") {
      queueNumber =
          "G${gasCounter.toString().padLeft(3, '0')}";

      gasCounter++;
    } else {
      queueNumber =
          "D${dieselCounter.toString().padLeft(3, '0')}";

      dieselCounter++;
    }

    final updatedQueue =
        List<Map<String, dynamic>>.from(
      waitingQueueNotifier.value,
    );

    updatedQueue.add({
      "queue": queueNumber,
      "name": name,
      "type": type,
    });

    waitingQueueNotifier.value = updatedQueue;

    setState(() {
      totalQueue++;
    });
  }

  // ================= CALL CUSTOMER =================

  void callCustomer(
    Map<String, dynamic> customer,
  ) async {
    final updatedQueue =
        List<Map<String, dynamic>>.from(
      waitingQueueNotifier.value,
    );

    updatedQueue.remove(customer);

    waitingQueueNotifier.value = updatedQueue;

    nowServingNotifier.value = customer;

    await speak(
      "Now serving ${customer['queue']}, please proceed to the testing area",
    );

    setState(() {});
  }

  // ================= CALL AGAIN =================

  void callAgain() async {
    if (nowServingNotifier.value == null) return;

    await speak(
      "Now serving ${nowServingNotifier.value!['queue']}, please proceed to the testing area",
    );
  }

  // ================= PASSED =================

  void markPassed() {
    if (nowServingNotifier.value == null) return;

    nowServingNotifier.value = null;

    setState(() {
      completedQueue++;
    });
  }

  // ================= FAILED =================

  void markFailed() {
    if (nowServingNotifier.value == null) return;

    nowServingNotifier.value = null;

    setState(() {});
  }

  // ================= CANCEL QUEUE =================

  void cancelQueue(
    Map<String, dynamic> customer,
  ) {
    final updatedQueue =
        List<Map<String, dynamic>>.from(
      waitingQueueNotifier.value,
    );

    updatedQueue.remove(customer);

    waitingQueueNotifier.value = updatedQueue;

    setState(() {});
  }

  // ================= DAILY RESET =================

  void resetDay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset System"),

        content: const Text(
          "This will clear all queues and start a new day.",
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () {
              // CLEAR WAITING
              waitingQueueNotifier.value = [];

              // CLEAR NOW SERVING
              nowServingNotifier.value = null;

              // RESET COUNTERS
              gasCounter = 1;
              dieselCounter = 1;

              // RESET STATS
              totalQueue = 0;
              completedQueue = 0;

              setState(() {});

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "System reset for new day",
                  ),
                ),
              );
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 227, 242, 248),

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
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                mainAxisAlignment:
                    MainAxisAlignment.end,

                children: const [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 50,
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Admin Panel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ================= QUEUE PANEL =================

            ListTile(
              leading: const Icon(Icons.queue),

              title: const Text("Queue Panel"),

              onTap: () {
                Navigator.pop(context);
              },
            ),

            // ================= BOOKING DASHBOARD =================

            ListTile(
              leading:
                  const Icon(Icons.dashboard),

              title: const Text(
                "Booking Dashboard",
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AdminDashboard(),
                  ),
                );
              },
            ),

            // ================= HISTORY =================

            ListTile(
              leading: const Icon(Icons.history),

              title: const Text("History"),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HistoryPage(),
                  ),
                );
              },
            ),

            // ================= LOGOUT =================

            ListTile(
              leading: const Icon(Icons.logout),

              title: const Text("Logout"),

              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HomePage(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text("Admin Control Panel"),
        backgroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // ================= TOP STATS =================

            Row(
              children: [
                statCard(
                  "Total Queue",
                  totalQueue.toString(),
                ),

                const SizedBox(width: 10),

                statCard(
                  "Waiting Queue",
                  waitingQueueNotifier.value.length
                      .toString(),
                ),

                const SizedBox(width: 10),

                statCard(
                  "Completed",
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
                              const Text(
                                "Generate Queue",
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 15),

                              SizedBox(
                                width: double.infinity,

                                child: ElevatedButton(
                                  onPressed: () {
                                    showGenerateDialog(
                                      "Gas",
                                    );
                                  },
                                  child:
                                      const Text("GAS"),
                                ),
                              ),

                              const SizedBox(height: 10),

                              SizedBox(
                                width: double.infinity,

                                child: ElevatedButton(
                                  onPressed: () {
                                    showGenerateDialog(
                                      "Diesel",
                                    );
                                  },
                                  child:
                                      const Text(
                                    "DIESEL",
                                  ),
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
                                  builder: (_) =>
                                      const DisplayPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "DISPLAY PAGE",
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton(
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.red,
                            ),

                            onPressed: resetDay,

                            child: const Text(
                              "DAILY RESET",
                            ),
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
                          child:
                              ValueListenableBuilder<
                                  Map<String,
                                      dynamic>?>(

                            valueListenable:
                                nowServingNotifier,

                            builder:
                                (
                                  context,
                                  customer,
                                  _,
                                ) {
                              return Column(
                                children: [
                                  const Text(
                                    "NOW SERVING",
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 15),

                                  Text(
                                    customer == null
                                        ? "-"
                                        : customer[
                                            'queue'],

                                    style:
                                        const TextStyle(
                                      fontSize: 45,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          Colors.red,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 5),

                                  Text(
                                    customer == null
                                        ? ""
                                        : customer[
                                            'name'],

                                    style:
                                        const TextStyle(
                                      fontSize: 18,
                                    ),
                                  ),

                                  const SizedBox(
                                      height: 20),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,

                                    children: [
                                      miniButton(
                                        Icons.volume_up,
                                        Colors.blue,
                                        callAgain,
                                      ),

                                      const SizedBox(
                                          width: 10),

                                      miniButton(
                                        Icons.check,
                                        Colors.green,
                                        markPassed,
                                      ),

                                      const SizedBox(
                                          width: 10),

                                      miniButton(
                                        Icons.close,
                                        Colors.red,
                                        markFailed,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ================= WAITING QUEUE =================

                        Expanded(
                          child: cardContainer(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                const Text(
                                  "Waiting Queue",
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                const SizedBox(
                                    height: 15),

                                Expanded(
                                  child:
                                      ValueListenableBuilder<
                                          List<
                                              Map<String,
                                                  dynamic>>>(

                                    valueListenable:
                                        waitingQueueNotifier,

                                    builder:
                                        (
                                          context,
                                          queueList,
                                          _,
                                        ) {
                                      return ListView
                                          .builder(
                                        itemCount:
                                            queueList
                                                .length,

                                        itemBuilder:
                                            (
                                              context,
                                              index,
                                            ) {
                                          final customer =
                                              queueList[
                                                  index];

                                          return Container(
                                            margin:
                                                const EdgeInsets
                                                    .only(
                                              bottom:
                                                  10,
                                            ),

                                            padding:
                                                const EdgeInsets
                                                    .all(
                                              12,
                                            ),

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

                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,

                                                    children: [
                                                      Text(
                                                        customer[
                                                            'queue'],

                                                        style:
                                                            const TextStyle(
                                                          fontSize:
                                                              18,

                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),

                                                      Text(
                                                        customer[
                                                            'name'],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // CALL BUTTON

                                                miniButton(
                                                  Icons
                                                      .volume_up,

                                                  Colors
                                                      .blue,

                                                  () {
                                                    callCustomer(
                                                      customer,
                                                    );
                                                  },
                                                ),

                                                const SizedBox(
                                                    width:
                                                        8),

                                                // CANCEL BUTTON

                                                miniButton(
                                                  Icons
                                                      .close,

                                                  Colors
                                                      .red,

                                                  () {
                                                    cancelQueue(
                                                      customer,
                                                    );
                                                  },
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

          padding: EdgeInsets.zero,

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
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