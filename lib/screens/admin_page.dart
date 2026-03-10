import 'package:flutter/material.dart';

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
          content: Text("QUEUE CLOSED — Daily limit reached (80)"),
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
        title: const Text("Reset Queue for New Day?"),
        content: const Text(
            "This will clear all queue data and restart numbering from A1."),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New service day started.")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm Reset"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Control Panel")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // NOW SERVING CARD
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("NOW SERVING",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      currentServingNumber == 0
                          ? "—"
                          : "A$currentServingNumber",
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

            // BUTTON ROW
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: addQueue,
                    child: const Text("Add Customer"),
                  ),
                ),
                const SizedBox(width: 12),
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

            // RESET BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: resetDay,
                icon: const Icon(Icons.restart_alt),
                label: const Text("Reset for New Day"),
              ),
            ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Waiting List",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: globalQueue.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
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