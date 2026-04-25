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
        const SnackBar(
          content: Text("QUEUE CLOSED — Max 80 reached"),
        ),
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
    String nowServing =
        currentServingNumber == 0 ? "-" : "A$currentServingNumber";

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Control Panel")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 🔴 NOW SERVING
            Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("NOW SERVING",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      nowServing,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "Issued Today: ${nextQueueNumber - 1} / 80",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // 🔘 MAIN BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: addQueue,
                    child: const Text("Add Customer"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: serveNext,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text("Serve Next"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 📺 DISPLAY BUTTON (THIS IS WHAT YOU ASKED)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.tv),
                label: const Text("Open Display Screen"),
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

            // 🔁 RESET BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text("Reset for New Day"),
                onPressed: resetDay,
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Waiting List",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // 📋 QUEUE LIST
            Expanded(
              child: ListView.builder(
                itemCount: globalQueue.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text("${index + 1}"),
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
    );
  }
}