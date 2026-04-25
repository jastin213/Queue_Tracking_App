import 'package:flutter/material.dart';
import 'admin_page.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController _queueController = TextEditingController();

  String positionText = "";
  String timeText = "";

  bool isValidQueue(String input) {
    final regex = RegExp(r'^A\d+$');
    return regex.hasMatch(input);
  }

  void checkQueue() {
    String queueNumber = _queueController.text.trim();

    if (!isValidQueue(queueNumber)) {
      showMessage("Invalid format. Use A10");
      return;
    }

    if (!globalQueue.contains(queueNumber)) {
      showMessage("Queue not found or already served.");
      return;
    }

    int position = globalQueue.indexOf(queueNumber);

    int estimatedTime = (position + 1) * averageServiceTime;

    setState(() {
      positionText = "Position: ${position + 1}";
      timeText = "Estimated Time: $estimatedTime mins";
    });

    // 🔔 NOTIFICATION LOGIC (5 SLOTS AHEAD)
    if (position <= 4) {
      showAlert();
    }
  }

  void showAlert() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Get Ready"),
        content: const Text("You are near your turn. Please prepare."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildCard(String title, String value, Color color) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String nowServing = currentServingNumber == 0
        ? "-"
        : "A$currentServingNumber";

    return Scaffold(
      appBar: AppBar(title: const Text("Queue Tracker")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // NOW SERVING
            buildCard("NOW SERVING", nowServing, Colors.red),

            const SizedBox(height: 20),

            // INPUT
            TextField(
              controller: _queueController,
              decoration: InputDecoration(
                labelText: "Enter Queue Number",
                hintText: "Example: A10",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 15),

            // BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: checkQueue,
                child: const Text("CHECK STATUS"),
              ),
            ),

            const SizedBox(height: 25),

            // RESULT CARDS
            if (positionText.isNotEmpty)
              buildCard("YOUR POSITION", positionText, Colors.blue),

            if (timeText.isNotEmpty)
              buildCard("WAITING TIME", timeText, Colors.green),
          ],
        ),
      ),
    );
  }
}