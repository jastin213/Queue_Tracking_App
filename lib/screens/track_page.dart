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
          ),
        ],
      ),
    );
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withOpacity(0.12), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
      backgroundColor: const Color(0xFFD6E3E8),
      appBar: AppBar(
        title: const Text("Queue Tracker"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // NOW SERVING (COMPACT CENTERED)
                Center(
                  child: SizedBox(
                    width: 140,
                    child: buildCard(
                      "NOW SERVING",
                      nowServing,
                      const Color(0xFF2C2C2C),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // INPUT
                TextField(
                  controller: _queueController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "Enter Queue Number (A10)",
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    onPressed: checkQueue,
                    child: const Text("CHECK STATUS"),
                  ),
                ),

                const SizedBox(height: 30),

                // RESULTS (COMPACT CENTERED)
                if (positionText.isNotEmpty)
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: buildCard(
                        "YOUR POSITION",
                        positionText,
                        Colors.blue,
                      ),
                    ),
                  ),

                if (timeText.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Center(
                    child: SizedBox(
                      width: 260,
                      child: buildCard("WAITING TIME", timeText, Colors.green),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}