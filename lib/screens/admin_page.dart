import 'package:flutter/material.dart';
import 'display_page.dart';

List<String> globalQueue = [];
int currentServingNumber = 0;
int averageServiceTime = 6;

int nextQueueNumber = 1;
const int maxQueueLimit = 80;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  void addQueue() {
    if (nextQueueNumber > maxQueueLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("QUEUE CLOSED — Max 80 reached")),
      );
      return;
    }

    setState(() {
      globalQueue.add("A$nextQueueNumber");
      nextQueueNumber++;
    });
  }

  void serveNext() {
    if (globalQueue.isEmpty) return;

    setState(() {
      String served = globalQueue.removeAt(0);
      currentServingNumber = int.parse(served.substring(1));
    });
  }

  void resetDay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Queue?"),
        content: const Text("Start a new day? This will clear all data."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                globalQueue.clear();
                currentServingNumber = 0;
                nextQueueNumber = 1;
              });
              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String nowServing = currentServingNumber == 0
        ? "-"
        : "A$currentServingNumber";

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 227, 242, 248),

      body: SafeArea(
        child: Column(
          children: [
            // 🔝 HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Admin Control Panel",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // 🟦 MAIN CONTENT
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 25,
                    ),
                  ],
                ),

                child: Column(
                  children: [
                    // 🔴 NOW SERVING
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "NOW SERVING",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            nowServing,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      "Issued Today: ${nextQueueNumber - 1} / 80",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 20),

                    // 🔘 BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: addQueue,
                            child: const Text("Add Customer"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                25,
                                233,
                                88,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: serveNext,
                            child: const Text("Serve Next"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 📺 DISPLAY
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tv),
                        label: const Text("Open Display Screen"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DisplayPage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔁 RESET
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text("Reset for New Day"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: resetDay,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 📋 WAITING LIST
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Waiting List",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: ListView.builder(
                        itemCount: globalQueue.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.black,
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(globalQueue[index]),
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
    );
  }
}
