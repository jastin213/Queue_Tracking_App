import 'package:flutter/material.dart';

import 'admin_page.dart';
import 'ors_service.dart';
import 'location_data.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController queueController = TextEditingController();

  String positionText = "";
  String estimatedText = "";
  String statusText = "";

  String travelText = "";
  String leaveAdviceText = "";

  bool isLoadingEta = false;

  final int averageServiceTime = 9;

  @override
  void dispose() {
    queueController.dispose();
    super.dispose();
  }

  Future<void> checkQueue() async {
    String input = queueController.text.trim().toUpperCase();

    bool found = false;

    final regex = RegExp(r'^[GD]\d+$');

    if (!regex.hasMatch(input)) {
      setState(() {
        statusText = "Invalid Queue Format";
        positionText = "Use format like G001 or D001";
        estimatedText = "";
        travelText = "";
        leaveAdviceText = "";
      });

      return;
    }

    for (var customer in waitingQueueNotifier.value) {
      if (customer['queue'] == input) {
        found = true;

        int position = waitingQueueNotifier.value.indexOf(customer) + 1;

        int estimatedTime = position * averageServiceTime;

        setState(() {
          statusText = "Waiting";
          positionText = "Position: $position";
          estimatedText = "Estimated Waiting Time: $estimatedTime mins";
          travelText = "";
          leaveAdviceText = "";
        });

        if (customer["source"] == "Appointment" &&
            customer["municipality"] != null) {
          await calculateSmartEta(
            municipality: customer["municipality"],
            estimatedQueueTime: estimatedTime,
          );
        }

        if (position <= 5) {
          showNearTurnDialog();
        }

        break;
      }
    }

    if (!found) {
      if (nowServingNotifier.value != null &&
          nowServingNotifier.value!['queue'] == input) {
        setState(() {
          statusText = "NOW SERVING";
          positionText = "Please proceed to testing area";
          estimatedText = "";
          travelText = "";
          leaveAdviceText = "";
        });

        found = true;
      }
    }

    if (!found && nowServingNotifier.value != null) {
      String currentQueue = nowServingNotifier.value!['queue'];

      String currentPrefix = currentQueue.substring(0, 1);
      String userPrefix = input.substring(0, 1);

      if (currentPrefix == userPrefix) {
        int currentNumber = int.parse(currentQueue.substring(1));
        int userNumber = int.parse(input.substring(1));

        if (userNumber < currentNumber) {
          setState(() {
            statusText = "Sorry, you missed your queue.";
            positionText = "Please coordinate with staff.";
            estimatedText = "";
            travelText = "";
            leaveAdviceText = "";
          });

          found = true;
        }
      }
    }

    if (!found) {
      setState(() {
        statusText = "Queue not found";
        positionText = "Please check your queue number.";
        estimatedText = "";
        travelText = "";
        leaveAdviceText = "";
      });
    }
  }

  Future<void> calculateSmartEta({
    required String municipality,
    required int estimatedQueueTime,
  }) async {
    setState(() {
      isLoadingEta = true;
    });

    final location = albayThirdDistrictLocations.firstWhere(
      (loc) => loc.name == municipality,
      orElse: () => albayThirdDistrictLocations.first,
    );

    final travelMinutes = await OrsService.getTravelTimeMinutes(
      originLon: location.lon,
      originLat: location.lat,
    );

    const int bufferMinutes = 5;

    if (travelMinutes == null) {
      setState(() {
        isLoadingEta = false;
        travelText =
            "Travel time unavailable. Please leave early to avoid missing your queue.";
        leaveAdviceText = "";
      });

      return;
    }

    int leaveIn = estimatedQueueTime - (travelMinutes + bufferMinutes);

    setState(() {
      isLoadingEta = false;

      travelText = "Travel Time: $travelMinutes mins + $bufferMinutes mins buffer";

      if (leaveIn <= 0) {
        leaveAdviceText =
            "Leave your house now. Your turn is estimated soon.";
      } else {
        leaveAdviceText =
            "Leave your house in $leaveIn mins. Your turn is estimated in $estimatedQueueTime mins.";
      }
    });
  }

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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Queue"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: nowServingNotifier,
              builder: (context, customer, _) {
                return buildCard(
                  "NOW SERVING",
                  customer == null ? "-" : customer['queue'],
                  Colors.red,
                );
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: queueController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: "Enter Queue Number",
                hintText: "Example: G001 or D001",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: checkQueue,
                child: const Text("CHECK STATUS"),
              ),
            ),

            const SizedBox(height: 25),

            if (statusText.isNotEmpty)
              buildCard(
                "STATUS",
                statusText,
                Colors.blue,
              ),

            if (positionText.isNotEmpty)
              buildCard(
                "QUEUE POSITION",
                positionText,
                Colors.orange,
              ),

            if (estimatedText.isNotEmpty)
              buildCard(
                "ESTIMATED WAITING TIME",
                estimatedText,
                Colors.green,
              ),

            if (isLoadingEta)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            if (travelText.isNotEmpty)
              buildCard(
                "TRAVEL ESTIMATION",
                travelText,
                Colors.purple,
              ),

            if (leaveAdviceText.isNotEmpty)
              buildCard(
                "SMART LEAVE ADVICE",
                leaveAdviceText,
                Colors.teal,
              ),
          ],
        ),
      ),
    );
  }
}