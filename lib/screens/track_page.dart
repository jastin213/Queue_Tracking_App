import 'package:flutter/material.dart';
import 'admin_page.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController _queueController = TextEditingController();
  String result = "";

  bool isValidQueue(String input) {
    final regex = RegExp(r'^A\d+$'); // must start with A and digits only
    return regex.hasMatch(input);
  }

  void checkQueue() {
    String queueNumber = _queueController.text.trim();

    // VALIDATION
    if (!isValidQueue(queueNumber)) {
      setState(() {
        result = "Invalid format. Use uppercase like A10";
      });
      return;
    }

    if (!globalQueue.contains(queueNumber)) {
      setState(() {
        result = "Queue not found or already served.";
      });
      return;
    }

    int position = globalQueue.indexOf(queueNumber);

    // FIXED ESTIMATION
    int estimatedTime = (position + 1) * averageServiceTime;

    setState(() {
      result =
          "Position in line: ${position + 1}\nEstimated waiting time: $estimatedTime minutes";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track My Queue")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // NOW SERVING
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

            const SizedBox(height: 30),

            TextField(
              controller: _queueController,
              decoration: const InputDecoration(
                labelText: "Enter Queue Number (A10)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: checkQueue,
              child: const Text("Check Status"),
            ),

            const SizedBox(height: 30),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  result,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}