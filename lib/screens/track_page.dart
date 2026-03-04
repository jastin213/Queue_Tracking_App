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

  void checkQueue() {
    String queueNumber = _queueController.text.trim();

    if (!globalQueue.contains(queueNumber)) {
      setState(() {
        result = "Queue number not found or already served.";
      });
      return;
    }

    int position = globalQueue.indexOf(queueNumber);
    int estimatedTime = position * averageServiceTime;

    setState(() {
      result =
          "Your Position: ${position + 1}\nEstimated Waiting Time: $estimatedTime minutes";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Track My Queue")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      "NOW SERVING",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      currentServingIndex < 0
                          ? "No one yet"
                          : "A${currentServingIndex + 1}",
                      style: const TextStyle(
                        fontSize: 32,
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
                labelText: "Enter Your Queue Number (ex: A1)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: checkQueue,
              child: const Text("Check Status"),
            ),
            const SizedBox(height: 30),
            Text(
              result,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
