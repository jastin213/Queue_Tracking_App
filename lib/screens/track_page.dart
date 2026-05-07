import 'package:flutter/material.dart';
import 'admin_page.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController queueController =
      TextEditingController();

  String positionText = "";
  String estimatedText = "";
  String statusText = "";

  // ✅ AVERAGE SERVICE TIME
  final int averageServiceTime = 9;

  // ================= CHECK QUEUE =================

  void checkQueue() {
    String input =
        queueController.text.trim().toUpperCase();

    bool found = false;

    // ================= WAITING QUEUE =================

    for (var customer in waitingQueueNotifier.value) {
      if (customer['queue'] == input) {
        found = true;

        int position =
            waitingQueueNotifier.value.indexOf(customer) +
                1;

        int estimatedTime =
            position * averageServiceTime;

        setState(() {
          statusText = "Waiting";
          positionText = "Position: $position";
          estimatedText =
              "Estimated Waiting Time: $estimatedTime mins";
        });

        // ✅ NEAR TURN ALERT
        if (position <= 5) {
          showNearTurnDialog();
        }

        break;
      }
    }

    // ================= NOW SERVING =================

    if (!found) {
      if (nowServingNotifier.value != null &&
          nowServingNotifier.value!['queue'] ==
              input) {
        setState(() {
          statusText = "NOW SERVING";
          positionText = "Please proceed to testing area";
          estimatedText = "";
        });

        found = true;
      }
    }

    // ================= NOT FOUND =================

    if (!found) {
      setState(() {
        statusText = "Queue not found";
        positionText = "";
        estimatedText = "";
      });
    }
  }

  // ================= ALERT =================

  void showNearTurnDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Queue Alert"),
        content: const Text(
          "Please prepare. Your turn is near.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ================= CARD =================

  Widget buildCard(
    String title,
    String value,
    Color color,
  ) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Queue"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= NOW SERVING =================

            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: nowServingNotifier,
              builder: (context, customer, _) {
                return buildCard(
                  "NOW SERVING",
                  customer == null
                      ? "-"
                      : customer['queue'],
                  Colors.red,
                );
              },
            ),

            const SizedBox(height: 20),

            // ================= INPUT =================

            TextField(
              controller: queueController,
              textCapitalization:
                  TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: "Enter Queue Number",
                hintText: "Example: G001 or D001",
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // ================= BUTTON =================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: checkQueue,
                child: const Text("CHECK STATUS"),
              ),
            ),

            const SizedBox(height: 25),

            // ================= STATUS =================

            if (statusText.isNotEmpty)
              buildCard(
                "STATUS",
                statusText,
                Colors.blue,
              ),

            // ================= POSITION =================

            if (positionText.isNotEmpty)
              buildCard(
                "QUEUE POSITION",
                positionText,
                Colors.orange,
              ),

            // ================= ESTIMATION =================

            if (estimatedText.isNotEmpty)
              buildCard(
                "ESTIMATED WAITING TIME",
                estimatedText,
                Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}